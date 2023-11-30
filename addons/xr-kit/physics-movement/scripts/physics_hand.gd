extends RigidBody3D

signal grabbed(object: Node3D)
signal dropped_held_object(object: Node3D)
signal hand_reset(hand: Node3D)

@export_group("Nodes")
@export var origin: XROrigin3D # XROrigin3D node
@export var camera: XRCamera3D # ARVRCamera node
@export var controller: XRController3D
@export var physics_skeleton: Skeleton3D # physics hand skeleton node
@export var controller_skeleton: Skeleton3D # controller hand skeleton node
@export var body: CharacterBody3D # RigidBody body node
@export var controller_hand_mesh: MeshInstance3D # controller hand Mesh Instance node
@export var finger_collider: PackedScene # finger collider node and raycasts for collision detection
@export var wrist_raycast: RayCast3D # wrist raycasts detect objects to grab
@export var wrist_joint: Generic6DOFJoint3D # joint is holding objects
@export var grab_area: ShapeCast3D

@export_group("PID Controller Linear")
@export var Kp: float = 1800
@export var Ki: float = 1
@export var Kd: float = 10
@export var integral_limit: float = 100
@export var derivative_limit: float = 100

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


func _ready() -> void:
	controller_hand_mesh_material = controller_hand_mesh.get_active_material(0)
	# Save rest poses and add colliders and collision detection raycasts to every bone in hand
	for bone_id in controller_skeleton.get_bone_count():
		# these bones are always at the end of each finger
		# they are helpers and do not need to be processed for physics hand
		if bone_id in [4, 9, 14, 19, 24]:
			pass

		# get global transform of bone
		var controller_bone_global_transform = controller_skeleton.global_transform * controller_skeleton.get_bone_global_pose(bone_id)
		# place physics wrist at controller wrist bone position
		if bone_id == 0:
			global_transform = controller_bone_global_transform

		var collider := finger_collider.instantiate()
		# collider name is bone_id
		collider.set_name(String.num_int64(bone_id))
		# wrist is the driving force for physics hand and only physics object (Rigid Body)
		# that's why we add all finger colliders to it
		add_child(collider)

	pid_controller_linear = PIDController.new({
		Kp = Kp,
		Ki = Ki,
		Kd = Kd,
		integral_limit = integral_limit,
		derivative_limit = derivative_limit
	})
	pid_controller_angular = PIDController.new({
		Kp = 10, # must not exceed 10, higher values glitch physics
		Ki = 0,
		Kd = 0,
		integral_limit = 1,
		derivative_limit = 1
	})


func _physics_process(delta: float) -> void:
	# if reset hand was called, we teleport physics hand to reset transform
	if resetting_hand:
		set_global_transform(reset_transform)
		# reset values to default
		reset_transform = Transform3D.IDENTITY
		resetting_hand = false

	# process every bone in hand
	for bone_id in controller_skeleton.get_bone_count():
		process_bones(bone_id, delta)

	# physics hand can be bugged or stuck and we need it to be able to reset itself automatically
	# if physics hand is too far away from controller hand (>0.3m), we reset it back to controller position
	var distance_to_wrist: Vector3 = (controller_skeleton.global_transform * controller_skeleton.get_bone_global_pose(0)).origin - global_transform.origin
	if distance_to_wrist.length_squared() > 0.09:
		reset_hand()

	var linear_velocity = move(delta)

	finger_micromovement(linear_velocity)

	if held_object:
		finger_procedural_grab_ik()

func process_bones(bone_id: int, delta: float) -> void:
	# every physics bone collider needs to follow its bone relative to RigidBody wrist position
	# translation to Z=0.01 is needed because collider needs to begin with bone, not in the middle
	# if we do translation, it messes up with physics mesh so we revert it for physics hand mesh
	var physics_bone_target_transform: Transform3D = (controller_skeleton.get_bone_global_pose(0).inverse() * controller_skeleton.get_bone_global_pose(bone_id)).translated(Vector3(0, 0, 0.01)).rotated_local(Vector3.LEFT, deg_to_rad(-90))
	var physics_bone_collider := get_node(String(get_path()) + "/" + String.num_int64(bone_id))
	physics_bone_collider.transform = physics_bone_target_transform

	# physics skeleton follows Physics Hand and copies controller bones
	if bone_id == 0:
		# Physics Hand RigidBody is bone 0, so we set physics_skeleton bone 0 right on top of it
		physics_skeleton.set_bone_pose_position(bone_id, Vector3.ZERO)
		physics_skeleton.set_bone_pose_rotation(bone_id, Quaternion.IDENTITY)
	else:
		# every bone is attached to previous one, so we only need to update rotation here
		physics_skeleton.set_bone_pose_rotation(bone_id, controller_skeleton.get_bone_pose_rotation(bone_id))

	if bone_id == 0:
		# show controller ghost hand when it's far from physics hand
		var distance_wrist = (controller_skeleton.global_transform * controller_skeleton.get_bone_global_pose(0)).origin - global_transform.origin
		var distance_alpha = clamp((distance_wrist.length() - 0.1), 0, 0.5)
		var color = controller_hand_mesh_material.get_albedo()
		color.a = distance_alpha
		controller_hand_mesh_material.set_albedo(color)


func move(delta: float) -> Vector3:
	# reset movement from previous frame, for some reason this prevents ghosting
	set_linear_velocity(Vector3.ZERO)
	set_angular_velocity(Vector3.ZERO)
	# target is controller wrist bone
	var target = controller_skeleton.global_transform * controller_skeleton.get_bone_global_pose(0)
	var linear_acceleration: Vector3 = pid_controller_linear.calculate(target.origin, global_transform.origin, delta)
	var angular_acceleration: Vector3 = pid_controller_angular.calculate((target.basis * global_transform.basis.inverse()).get_euler(), Vector3.ZERO, delta)

	# apply calculated forces
	apply_central_force(linear_acceleration)
	apply_torque(angular_acceleration)

	return linear_acceleration


func grab() -> Node3D:
	if held_object:
		return held_object

	# TODO: compare objects in grab_area for controller and physics hand and only if they match, grab this object
	# TODO: highlight object which will be grabbed when hand is close to it
	# TODO: select object closest to grab_area center (or palm)
	grab_area.force_shapecast_update()
	if grab_area.is_colliding():
		# get object we just grabbed
		held_object = grab_area.get_collider(0)
		physics_pivot_point = Node3D.new()
		held_object.add_child(physics_pivot_point)
		physics_pivot_point.global_transform = global_transform.translated(grab_area.get_collision_point(0) - global_transform.origin)
		# set joint between hand and grabbed object
		wrist_joint.set_node_a(get_path())
		wrist_joint.set_node_b(held_object.get_path())

		if held_object.is_class("RigidBody3D"):
			held_object.set_angular_damp(1) # reduce rotational forces to make holding more natural
			var center_of_mass = physics_pivot_point.global_transform.origin - held_object.global_transform.origin
			held_object.set_center_of_mass_mode(1) # enable custom center of mass
			held_object.set_center_of_mass(center_of_mass)

			# update PID controller inputs for better feeling
			pid_controller_linear.update({
				Kp = Kp,
				Ki = Ki,
				Kd = held_object.get_mass() * 2,
				integral_limit = integral_limit,
				derivative_limit = derivative_limit
			})
			pid_controller_angular.update({
				Kp = 10,
				Ki = 5,
				Kd = 5,
				integral_limit = 1,
				derivative_limit = 1
			})

		held_object.set_collision_layer_value(12, true) # held objects are in layer 12 to filter out collisions with player head

		grabbed.emit(held_object)

		return held_object
	else:
		return null


func drop_held_object() -> void:
	if held_object:
		wrist_joint.set_node_a("")
		wrist_joint.set_node_b("")
		held_object.set_collision_layer_value(12, false)

		if held_object.is_class("RigidBody3D"):
			held_object.set_angular_damp(0)
			held_object.set_center_of_mass_mode(0)

			pid_controller_linear.update({
				Kp = Kp,
				Ki = Ki,
				Kd = 10,
				integral_limit = integral_limit,
				derivative_limit = derivative_limit
			})
			pid_controller_angular.update({
				Kp = 10,
				Ki = 0,
				Kd = 0,
				integral_limit = 1,
				derivative_limit = 1
			})

		dropped_held_object.emit(held_object)

		held_object = null
		physics_pivot_point.free()
		physics_skeleton.set_show_rest_only(false)


func finger_micromovement(linear_velocity) -> void:
	# add inverse kinematics micro movement to fingers when hand is being moved
	# makes the hand feel a little less stiff and more natural
	# TODO: move nodes setup to _ready() and only update target transform here
	# TODO: rotational force should also be taken into account
	# TODO: fingers should react when hand is pushing on an object
	var ik_nodes: Array[Node] = physics_skeleton.get_children().filter(func(node): return node is SkeletonIK3D)
	# set target transform for every IK node (finger) in physics hand
	for ik_node in ik_nodes:
		# IK target vector is taken from physics hand velocity, flipped and greatly reduced
		var target_vector: Vector3 = -linear_velocity.limit_length(100) / 100000
		var tip_bone_index: int = physics_skeleton.find_bone(ik_node.get_tip_bone())
		var tip_bone_pose: Transform3D = physics_skeleton.get_bone_global_pose_no_override(tip_bone_index)

		ik_node.set_target_transform(physics_skeleton.global_transform * tip_bone_pose.translated(target_vector))
		ik_node.start()


func finger_procedural_grab_ik() -> void:
	var fingers := ["Thumb", "Index", "Middle", "Ring", "Little"]

	# lock hand bones to rest pose, so IK is not fighting with animation
	physics_skeleton.set_show_rest_only(true)

	for finger in fingers:
		var raycast = get_node("Skeleton3D/Wrist/" + finger + "DistalRaycast")
		var ik = get_node("Skeleton3D/" + finger + "FingerIK")

		raycast.force_raycast_update()
		if raycast.get_collider() == held_object:
			ik.target = Transform3D.IDENTITY.translated(raycast.get_collision_point())
			ik.start()


func reset_hand() -> void:
	drop_held_object()
	physics_skeleton.set_show_rest_only(false)
	# teleport physics hand back to controller position
	# value of reset_transform will be read on the next physics frame
	reset_transform = (controller_skeleton.global_transform * controller_skeleton.get_bone_global_pose(0))
	resetting_hand = true
	hand_reset.emit(self)

func _on_grab(grab: bool) -> void:
	if grab:
		grab()
	else:
		drop_held_object()


func _on_hand_pose_recognition_new_pose(previous_pose: StringName, pose: StringName) -> void:
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
		integral += error * delta
		integral.limit_length(integral_limit)
		derivative = (error - previous_error) / delta
		derivative.limit_length(derivative_limit)
		previous_error = error
		output = Kp * proportional + Ki * integral + Kd * derivative

		return output
