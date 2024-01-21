extends RigidBody3D

signal grabbed(object: Node3D)
signal dropped_held_object(object: Node3D)
signal hand_reset(hand: Node3D)
signal trigger_haptic(type: String)
signal controller_hand_reset_animation(reset: bool)

@export_group("Nodes")
@export var controller: XRController3D
@export var physics_skeleton: Skeleton3D # Physics hand skeleton node
@export var controller_skeleton: Skeleton3D # Controller hand skeleton node
@export var controller_hand_mesh: MeshInstance3D # Controller hand Mesh Instance node
@export var finger_collider: PackedScene # Finger collider node and raycasts for collision detection
@export var wrist_raycast: RayCast3D # Wrist raycasts detect objects to grab
@export var grab_joint: JoltGeneric6DOFJoint3D # Joint is holding objects
@export var grab_area: ShapeCast3D

# PID controller default values are tuned for subjective feeling of realistic hand physics
# These values have biggest influence on how hand feels and behaves
@export_group("PID Controller Linear")
@export var Kp_linear: float = 800
@export var Ki_linear: float = 0
@export var Kd_linear: float = 80
@export var proportional_limit_linear: float = INF
@export var integral_limit_linear: float = INF
@export var derivative_limit_linear: float = INF

@export_group("PID Controller Angular")
@export var Kp_angular: float = 5
@export var Ki_angular: float = 0
@export var Kd_angular: float = 1
@export var proportional_limit_angular: float = INF
@export var integral_limit_angular: float = INF
@export var derivative_limit_angular: float = INF

var pid_controller_linear: PIDController
var pid_controller_angular: PIDController
var controller_hand_mesh_material: Material
var held_object: Node3D = null
var trigger_pressed: bool
var physics_pivot_point: Node3D
var thruster_forward: bool
var thruster_backward: bool
var reset_transform := Transform3D.IDENTITY
var resetting_hand := false
var is_controller_tracking: bool
var previous_controller_skeleton_position: Vector3
var controller_skeleton_velocity: Vector3
var colliding_object: Node3D
var collision_normal: Vector3

var fingers := ["Thumb", "Index", "Middle", "Ring", "Little"]
# Bone_suffix = L or R
var bone_suffix: String
var raycast: RayCast3D
var touch_transforms: Dictionary


func _ready() -> void:
	controller_hand_mesh_material = controller_hand_mesh.get_active_material(0)
	# Save rest poses and add colliders and collision detection raycasts to every bone in hand
	for bone_id in controller_skeleton.get_bone_count():
		# These bones are always at the end of each finger
		# They are helpers and do not need to be processed for physics hand
		if bone_id in [4, 9, 14, 19, 24]:
			pass

		# Get global transform of bone
		var controller_bone_global_transform = controller_skeleton.global_transform * controller_skeleton.get_bone_global_pose(bone_id)
		# Place physics wrist at controller wrist bone position
		if bone_id == 0:
			global_transform = controller_bone_global_transform

		var collider := finger_collider.instantiate()
		# Collider name is bone_id
		collider.set_name(String.num_int64(bone_id))
		# Wrist is the driving force for physics hand and only physics object (Rigid Body)
		# That's why we add all finger colliders to it
		add_child(collider)

	pid_controller_linear = PIDController.new({
		Kp = Kp_linear,
		Ki = Ki_linear,
		Kd = Kd_linear,
		proportional_limit = proportional_limit_linear,
		integral_limit = integral_limit_linear,
		derivative_limit = derivative_limit_linear
	})
	pid_controller_angular = PIDController.new({
		Kp = Kp_angular,
		Ki = Ki_angular,
		Kd = Kd_angular,
		proportional_limit = proportional_limit_angular,
		integral_limit = integral_limit_angular,
		derivative_limit = derivative_limit_angular
	})
	# Minimal inertia is required for controllable hand rotation
	set_inertia(Vector3(0.01, 0.01, 0.01))

	bone_suffix = physics_skeleton.get_bone_name(0).get_slice("_", 1)
	raycast = physics_skeleton.get_node("RayCast3D")
	var controller_skeleton_animation_player = controller_skeleton.get_node("AnimationTree/AnimationPlayer")

	# Initialize touch transforms dictionary (array for every finger)
	for finger in fingers:
		touch_transforms[finger] = []

	# Manually play full (1.7s) hand grab animation in 100ms increments (0.0, 0.1, 0.2, ..., 1.7)
	controller_skeleton_animation_player.play("hand_grab", -1, 0.0)
	for i in range(18):
		var playback_time = i / 10.0 # Convert to floats (0.0, 0.1, ...)
		controller_skeleton_animation_player.seek(playback_time, true)

		# Save Touch nodes (attached to Distal bones at the bottom of fingerprint, where you hold things) transforms for each finger and time increment
		# These positions will be used to shoot raycast from and detect collisions with held object to find IK targets for each finger
		for finger in fingers:
			var touch_node: Node3D = controller_skeleton.get_node(str(finger) + "Distal/Touch")
			# Make sure wrist is in rest pose
			controller_skeleton.set_bone_pose_position(0, Vector3.ZERO)
			controller_skeleton.set_bone_pose_rotation(0, Quaternion.IDENTITY)
			# Save Touch node global_poses (relative to Skeleton3D) to Dictionary
			var touch_wrist_pose: Transform3D = touch_node.transform * controller_skeleton.get_bone_global_pose(touch_node.get_parent().bone_idx)
			touch_transforms[finger].append(touch_wrist_pose)

	# Resume hand animations driven by AnimationTree
	controller_skeleton_animation_player.stop()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Save latest collision object and collision normal
	if state.get_contact_count() > 0:
		colliding_object = state.get_contact_collider_object(0)
		collision_normal = state.get_contact_local_normal(0)
	else:
		colliding_object = null
		collision_normal = Vector3.ZERO


func _physics_process(delta: float) -> void:
	# If reset hand was called, we teleport physics hand to reset transform
	if resetting_hand:
		set_global_transform(reset_transform)
		# Reset values to default
		reset_transform = Transform3D.IDENTITY
		resetting_hand = false

	# Process every bone in hand
	for bone_id in controller_skeleton.get_bone_count():
		process_bone(bone_id)

	# Physics hand can be bugged or stuck and we need it to be able to reset itself automatically
	# If physics hand is too far away from controller hand (>0.3m), we reset it back to controller position
	var distance_to_wrist: Vector3 = (controller_skeleton.global_transform * controller_skeleton.get_bone_global_pose(0)).origin - global_transform.origin
	if distance_to_wrist.length_squared() > 0.09:
		reset_hand()

	# If holding and controller hand is rotated over 160 degrees from physics hand, drop held object
	if held_object:
		var controller_wrist_bone = controller_skeleton.global_transform * controller_skeleton.get_bone_global_pose(0)
		var physics_wrist_bone = global_transform * physics_skeleton.get_bone_global_pose(0)
		var angle = controller_wrist_bone.basis.get_rotation_quaternion().normalized().angle_to(physics_wrist_bone.basis.get_rotation_quaternion().normalized())
		if abs(angle) > deg_to_rad(160):
			drop_held_object(true)

	var linear_velocity = move(delta)

	finger_micromovement(linear_velocity)

	if held_object:
		finger_procedural_grab_ik()

	# Calculate controller hand velocity
	controller_skeleton_velocity = (controller_skeleton.global_transform.origin - %Origin.global_transform.origin - previous_controller_skeleton_position) / delta
	previous_controller_skeleton_position = controller_skeleton.global_transform.origin - %Origin.global_transform.origin

func process_bone(bone_id: int) -> void:
	# Every physics bone collider needs to follow its bone relative to RigidBody wrist position
	# Translation to Z=0.01 is needed because collider needs to begin with bone, not in the middle
	# If we do translation, it messes up with physics mesh so we revert it for physics hand mesh
	var physics_bone_target_transform: Transform3D = (controller_skeleton.get_bone_global_pose(0).inverse() * controller_skeleton.get_bone_global_pose(bone_id)).translated(Vector3(0, 0, 0.01)).rotated_local(Vector3.LEFT, deg_to_rad(-90))
	var physics_bone_collider := get_node(String(get_path()) + "/" + String.num_int64(bone_id))
	physics_bone_collider.transform = physics_bone_target_transform.orthonormalized()

	# Physics skeleton follows Physics Hand and copies controller bones
	if bone_id == 0:
		# Physics Hand RigidBody is bone 0, so we set physics_skeleton bone 0 right on top of it
		physics_skeleton.set_bone_pose_position(bone_id, Vector3.ZERO)
		physics_skeleton.set_bone_pose_rotation(bone_id, Quaternion.IDENTITY)
	else:
		# Every bone is attached to previous one, so we only need to update rotation here
		physics_skeleton.set_bone_pose_rotation(bone_id, controller_skeleton.get_bone_pose_rotation(bone_id))

	if bone_id == 0:
		# Show controller ghost hand when it's far from physics hand
		var distance_wrist = (controller_skeleton.global_transform * controller_skeleton.get_bone_global_pose(0)).origin - global_transform.origin
		var distance_alpha = clamp((distance_wrist.length() - 0.1), 0, 0.5)
		var color = controller_hand_mesh_material.get_albedo()
		color.a = distance_alpha
		controller_hand_mesh_material.set_albedo(color)


func move(delta: float) -> Vector3:
	# Target is controller wrist bone
	var target = controller_skeleton.global_transform * controller_skeleton.get_bone_global_pose(0)
	var linear_acceleration: Vector3 = pid_controller_linear.calculate(target.origin, global_transform.origin, delta)
	var angular_acceleration: Vector3 = pid_controller_angular.calculate((target.basis * global_transform.basis.inverse()).get_euler(), Vector3.ZERO, delta)

	if controller.free_rotation and held_object:
		return Vector3.ZERO

	# We can set velocities directly or apply forces to RigidBody. Both methods can be used with PID controller, but velocities are much easier to work with as they do not overshoot or oscillate and only Kp needs to be adjusted (Ki and Kd are left at 0). On the other hand (hehe), applying forces results in natural movement where hand is pushing with proper force (ex. push has smaller effect on heavier bodies), pushback is reliably applied when hand is pushing against something and hand rotation is affected by collisions
	# To sum up: use velocities for arcade/simple hand behavior and forces if you want realistic physics
	# set_linear_velocity(linear_acceleration)
	# set_angular_velocity(angular_acceleration)
	apply_central_force(linear_acceleration)
	apply_torque(angular_acceleration)

	return linear_acceleration


func grab() -> Node3D:
	if held_object:
		return held_object

	# TODO: Compare objects in grab_area for controller and physics hand and only if they match, grab this object
	# TODO: Highlight object which will be grabbed when hand is close to it
	# TODO: highlight color based on object mass
	# TODO: Select object closest to grab_area center (or palm)
	grab_area.force_shapecast_update()
	if grab_area.is_colliding():
		# Get object we just grabbed
		held_object = grab_area.get_collider(0)
		# Physics pivot point attaches to Palm and rotates with it
		# TODO: If other hand is holding an object with free rotation, do not update pivot point
		physics_pivot_point = Node3D.new()
		physics_skeleton.get_node("Palm").add_child(physics_pivot_point)

		# Set joint between hand and grabbed object
		grab_joint.set_node_a(get_path())
		grab_joint.set_node_b(held_object.get_path())

		# If holding a static object, we let physical hand rotate freely on the surface of the object
		if held_object.is_class("StaticBody3D"):
			grab_joint.set_flag_y(1, false) # FLAG_ENABLE_ANGULAR_LIMIT = 1

		if held_object.is_class("RigidBody3D"):
			grab_joint.set_flag_y(1, true) # FLAG_ENABLE_ANGULAR_LIMIT = 1
			held_object.set_angular_damp(1) # Reduce rotational forces to make holding more natural
			var center_of_mass = physics_pivot_point.global_transform.origin - held_object.global_transform.origin
			held_object.set_center_of_mass_mode(1) # Enable custom center of mass
			held_object.set_center_of_mass(center_of_mass)

		# TODO: Check how it works after collider has been moved under Body node
		held_object.set_collision_layer_value(12, true) # Held objects are in layer 12 to filter out collisions with player head

		grabbed.emit(held_object)

		return held_object
	else:
		return null


func drop_held_object(haptic: bool = false) -> void:
	if held_object:
		grab_joint.set_node_a("")
		grab_joint.set_node_b("")
		held_object.set_collision_layer_value(12, false)

		if held_object.is_class("RigidBody3D"):
			held_object.set_angular_damp(0)
			held_object.set_center_of_mass_mode(0)

		dropped_held_object.emit(held_object)

		held_object = null
		physics_pivot_point.free()
		physics_skeleton.set_show_rest_only(false)
		var ik_nodes: Array[Node] = physics_skeleton.get_children().filter(func(node): return node is SkeletonIK3D)
		for ik_node in ik_nodes:
			ik_node.stop()

		if haptic:
			trigger_haptic.emit("drop_held_object")


func finger_micromovement(linear_velocity) -> void:
	# Add inverse kinematics micro movement to fingers when hand is being moved
	# Makes the hand feel a little less stiff and more natural
	# TODO: Move nodes setup to _ready() and only update target transform here
	# TODO: Rotational force should also be taken into account
	# TODO: Fingers should react when hand is pushing on an object
	var ik_nodes: Array[Node] = physics_skeleton.get_children().filter(func(node): return node is SkeletonIK3D)
	# Set target transform for every IK node (finger) in physics hand
	for ik_node in ik_nodes:
		# IK target vector is taken from physics hand velocity, flipped and greatly reduced
		var target_vector: Vector3 = -linear_velocity.limit_length(100) / 100000
		var tip_bone_index: int = physics_skeleton.find_bone(ik_node.get_tip_bone())
		var tip_bone_pose: Transform3D = physics_skeleton.get_bone_global_pose_no_override(tip_bone_index)

		ik_node.set_target_transform(physics_skeleton.global_transform * tip_bone_pose.translated(target_vector))
		ik_node.start()


func finger_procedural_grab_ik() -> void:
	for finger in fingers:
		var distal_bone_index = physics_skeleton.find_bone(finger + "_Distal_" + bone_suffix)
		var ik = physics_skeleton.get_node(finger + "IK")
		var touch_node = physics_skeleton.get_node(finger + "Distal/Touch")
		var physics_controller_wrist = physics_skeleton.get_node("Wrist")

		# Iterate through saved Touch nodes transforms and shoot raycast downwards from each of them
		for i in touch_transforms[finger].size() -1:
			raycast.global_transform = physics_skeleton.global_transform * touch_transforms[finger][i]
			raycast.target_position = Vector3.DOWN * 0.05

			raycast.force_raycast_update()
			if raycast.get_collider() == held_object:
				var target_transform: Transform3D = Transform3D.IDENTITY.translated(raycast.get_collision_point())
				# Distal bone rotation is the same as previous (Intermediate) bone rotation
				# TODO: Find out how to rotate distal bone to match raycast collision normal and look natural
				target_transform.basis = (physics_skeleton.global_transform * physics_skeleton.get_bone_global_pose(distal_bone_index -1)).basis
				# Further rotate Distal bone 20 degrees downwards to make it look more natural
				# TODO: Godot's SkeletonIK3D implementation of FABRIK does not support contraints, so bones can rotate in unnatural ways (impossible angles), ex. intermediate bone points upwards from proximal. Because of this, 20 degrees distal rotation and rotations of previous bones sometimes bend finger in "zig-zag", which cannot be fixed any other way than implementing IK with constraints (add constraints to FABRIK or use different IK system, such as CCDIK).
				target_transform.basis = target_transform.basis.rotated(target_transform.basis.x, deg_to_rad(-20))
				# Set IK target for distal bone so Touch node will reach raycast hit position. That way finger is pulled back a little and IK feels more natural
				# Also, with Touch node, finger will properly rest on held object surface and not go through it
				target_transform = target_transform.translated_local(-touch_node.transform.origin)

				ik.set_target_transform(target_transform)
				ik.start()

				break

	# Lock hand bones to rest pose which disables animation, so IK is not fighting with it
	physics_skeleton.set_show_rest_only(true)


func reset_hand() -> void:
	drop_held_object()
	physics_skeleton.set_show_rest_only(false)
	# Teleport physics hand back to controller position
	# Value of reset_transform will be read on the next physics frame
	reset_transform = (controller_skeleton.global_transform * controller_skeleton.get_bone_global_pose(0))
	resetting_hand = true
	hand_reset.emit(self)


func _on_grab(grab: bool) -> void:
	if grab:
		grab()
	else:
		drop_held_object()


func _on_hand_pose_recognition_new_pose(previous_pose: StringName, pose: StringName) -> void:
	# Do not grab/drop based on hand poses when we receive data from controller
	if is_controller_tracking:
		return

	if pose in ["half_grip", "full_grip", "thumb_up", "point"] and previous_pose in ["open", "rest"]:
		grab()

	if pose in ["open", "rest"]:
		drop_held_object()


class PIDController:
	var Kp: float
	var Ki: float
	var Kd: float
	var error: Vector3
	var proportional: Vector3
	var proportional_limit: float
	var previous_error: Vector3
	var integral: Vector3
	var integral_limit: float
	var derivative: Vector3
	var derivative_limit: float
	var output: Vector3

	func _init(args) -> void:
		Kp = args.Kp
		Ki = args.Ki
		Kd = args.Kd
		proportional_limit = args.proportional_limit
		integral_limit = args.integral_limit
		derivative_limit = args.derivative_limit
		previous_error = Vector3(0, 0, 0)
		integral = Vector3(0, 0, 0)


	func update(args) -> void:
		Kp = args.Kp
		Ki = args.Ki
		Kd = args.Kd
		integral_limit = args.integral_limit
		derivative_limit = args.derivative_limit


	func calculate(target: Vector3, current: Vector3, delta: float) -> Vector3:
		error = target - current
		proportional = error
		proportional.limit_length(proportional_limit)
		integral += error * delta
		integral.limit_length(integral_limit)
		derivative = (error - previous_error) / delta
		derivative.limit_length(derivative_limit)
		previous_error = error
		output = Kp * proportional + Ki * integral + Kd * derivative

		return output


func _on_controller_tracking_changed(tracking: bool) -> void:
	is_controller_tracking = tracking
