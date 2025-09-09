extends RigidBody3D

signal grabbed(object: Node3D, collision_normal: Vector3)
signal dropped_held_object(object: Node3D)
signal hand_reset(hand: Node3D)
signal trigger_haptic(type: String)
signal controller_hand_reset_animation(reset: bool)

@export_group("Variables")
@export_enum("Left", "Right") var hand: String = "Left"

@export_group("Nodes")
@export var tracker: XRNode3D
@export var controller: XRNode3D
@export var hand_tracker: XRNode3D
# @export var animation_tree: AnimationTree
@export var skeleton: Skeleton3D # Physics hand skeleton node
@export var hand_modifier: XRHandModifier3D # Manages hand poses from OpenXR
@export var grab_joint: Generic6DOFJoint3D # Joint is holding objects
@export var grab_area: ShapeCast3D # Collision detection for grab

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
var held_object: PhysicsBody3D = null
var trigger_pressed: bool
var physics_pivot_point: Node3D
var thruster_forward: bool
var thruster_backward: bool
var reset_transform := Transform3D.IDENTITY
var resetting_hand := false
var is_controller_tracking: bool
var colliding_object: PhysicsBody3D
var collision_normal: Vector3
var touch_transforms: Dictionary
var collider_transforms: Dictionary
var ik_colliders: Dictionary


func _ready() -> void:
	# Colliders are stored in Skeleton's BoneAttachment3D nodes, but they need to be moved to RigidBody as direct children to work
	# We save collider transforms relative to bone in Dictionary collider_transforms, rename them and move to RigidBody
	# This data will be used to position colliders on every physics frame in process_bone() function
	for bone_attachment: BoneAttachment3D in skeleton.get_children().filter(func(node): return node is BoneAttachment3D):
		var bone_id: int = skeleton.find_bone(bone_attachment.get_name())

		# If skeleton bone does not belong to hand, ignore it
		if bone_id not in hand_modifier.bone_ids:
			continue

		collider_transforms[bone_id] = {}
		for collision_shape: CollisionShape3D in bone_attachment.get_children().filter(func(node): return node is CollisionShape3D):
			var new_name: String = str(bone_id) + "_" + collision_shape.get_name()
			collision_shape.set_name(new_name)
			collider_transforms[bone_id][new_name] = collision_shape.transform
			collision_shape.reparent(self, false)

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
	for bone_id in skeleton.get_bone_count():
		process_bone(bone_id)

	# Physics hand can be bugged or stuck and we need it to be able to reset itself automatically
	# If physics hand is too far away from target (>0.3m), we reset it back to target position
	var distance_to_target: Vector3 = tracker.global_transform.origin - global_transform.origin
	if distance_to_target.length_squared() > 0.09:
		reset_hand()

	# If holding and controller hand is rotated over 160 degrees from physics hand, drop held object
	if held_object:
		var angle = tracker.global_transform.basis.get_rotation_quaternion().normalized().angle_to(global_transform.basis.get_rotation_quaternion().normalized())
		
		if abs(angle) > deg_to_rad(160):
			drop_held_object(true)

	# Move function calculates forces to apply to physics hand and returns its calculated linear velocity for further use
	var linear_velocity = move(delta)


func process_bone(bone_id: int) -> void:
	# Update colliders
	var collider_names = collider_transforms.get(bone_id)
	if collider_names:
		for collider_name in collider_names.keys():
			var collider = get_node(collider_name)

			# SIMPLE OPTION FOR MANUAL COLLIDERS ADDED TO BONEATTACHMENT NODES
			# Move collider to bone position
			collider.transform = skeleton.poses.get(bone_id, Transform3D.IDENTITY) * collider_transforms[bone_id][collider_name]

			# COMPLEX OPTION FOR AUTOGENERATED COLLIDERS FROM MESHES
			# This places colliders on correct rest pose (collider is at rest bone), but they dont move with bones
			# collider.transform = skeleton.get_bone_global_pose(0).translated(-skeleton.get_bone_pose(20).origin)


func move(delta: float) -> Vector3:
	var linear_acceleration: Vector3 = pid_controller_linear.calculate(tracker.global_transform.origin, global_transform.origin, delta)
	var angular_acceleration: Vector3 = pid_controller_angular.calculate((tracker.global_transform.basis * global_transform.basis.inverse()).get_euler(), Vector3.ZERO, delta)

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

	# TODO: Highlight object which will be grabbed when hand is close to it
	# TODO: highlight color based on object mass
	# TODO: Select object closest to grab_area center (or palm)
	grab_area.force_shapecast_update()
	if grab_area.is_colliding():
		# Get object we just grabbed
		held_object = grab_area.get_collider(0)
		# Snap hand to object when grabbed
		var grip_pose = skeleton.get_node(hand + "Hand/GripPose")
		global_transform = global_transform.translated(grab_area.get_collision_point(0) - grip_pose.global_transform.origin)
		
		# Rotate hand so wrist matches collision normal
		global_transform.basis = Basis.looking_at(grab_area.get_collision_normal(0), (skeleton.global_transform * skeleton.get_bone_global_pose(0)).basis.y) * skeleton.get_bone_global_pose(0).basis.inverse()
		
		# Physics pivot point attaches to Physics Hand and rotates with it
		# TODO: If other hand is holding an object with free rotation, do not update pivot point
		physics_pivot_point = Node3D.new()
		add_child(physics_pivot_point)

		# Move grab joint to physics hand position (pivot point) and rotate into collision normal, so disabling angular limit below will always result in correct rotation angle
		grab_joint.global_transform = Transform3D(Basis.looking_at(grab_area.get_collision_normal(0), (skeleton.global_transform * skeleton.get_bone_global_pose(0)).basis.y), global_transform.origin)
		
		# Set joint between hand and grabbed object
		grab_joint.set_node_a(get_path())
		grab_joint.set_node_b(held_object.get_path())

		# If holding a static object, we let physical hand rotate freely on the surface of the object
		if held_object.is_class("StaticBody3D"):
			grab_joint.set_flag_z(grab_joint.FLAG_ENABLE_ANGULAR_LIMIT, false)

		if held_object.is_class("RigidBody3D"):
			grab_joint.set_flag_z(grab_joint.FLAG_ENABLE_ANGULAR_LIMIT, true)
			held_object.set_angular_damp(1) # Reduce rotational forces to make holding more natural
			var center_of_mass = physics_pivot_point.global_transform.origin - held_object.global_transform.origin
			held_object.set_center_of_mass_mode(1) # Enable custom center of mass
			held_object.set_center_of_mass(center_of_mass)

		# TODO: Check how it works after collider has been moved under Body node
		held_object.set_collision_layer_value(12, true) # Held objects are in layer 12 to filter out collisions with player head

		grabbed.emit(held_object, grab_area.get_collision_normal(0))

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
		skeleton.set_show_rest_only(false)
		var ik_nodes: Array[Node] = skeleton.get_children().filter(func(node): return node is SkeletonIK3D)
		for ik_node in ik_nodes:
			ik_node.stop()

		if haptic:
			trigger_haptic.emit("drop_held_object")


func reset_hand() -> void:
	drop_held_object()
	skeleton.set_show_rest_only(false)
	# Teleport physics hand back to controller position
	# Value of reset_transform will be read on the next physics frame
	reset_transform = tracker.global_transform
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


func _on_click(released: bool):
	if held_object and released:
		drop_held_object()
	
	# TODO: if not holding an object, apply boost

	
func _on_long_click(released: bool):
	grab()
	# TODO: if holding an object and not released, enable free hand rotation


func _on_controller_tracking_changed(is_tracking: bool):
	if is_tracking:
		tracker = controller
	else:
		tracker = hand_tracker

	is_controller_tracking = is_tracking


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
		proportional = proportional.limit_length(proportional_limit)
		integral += error * delta
		integral = integral.limit_length(integral_limit)
		derivative = (error - previous_error) / delta
		derivative = derivative.limit_length(derivative_limit)
		previous_error = error
		output = Kp * proportional + Ki * integral + Kd * derivative

		return output
