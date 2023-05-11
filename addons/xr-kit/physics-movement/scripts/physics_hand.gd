extends RigidBody3D

signal grabbed(object: Node3D)
signal dropped_held_object(object: Node3D)
signal hand_reset(hand: Node3D)

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
# Variables for freezing fingers on grab collisions
var freezed_poses := {}
# OpenXR specification requires 25 bones per hand
# https://registry.khronos.org/OpenXR/specs/1.0/html/xrspec.html#_conventions_of_hand_joints
var finger_bones := {
	"Wrist": [0],
	"Thumb": [1,2,3,4,5],
	"Index": [0,5,6,7,8,9],
	"Middle": [0,10,11,12,13,14],
	"Ring": [0,15,16,17,18,19],
	"Little": [0,20,21,22,23,24],
	"Palm": [25]
}
# reversed finger_bones, keys are bone_ids and values are bone names
# populated on script initialization
var finger_from_bone := {} # 0: "Wrist", 1: "Thumb", 2: "Thumb", (...)
# default rest poses will be saved here on launch
var bone_rest_poses := {}


func _ready() -> void:
	controller_hand_mesh_material = controller_hand_mesh.get_active_material(0)
	# Save rest poses and add colliders and collision detection raycasts to every bone in hand
	for bone_id in controller_skeleton.get_bone_count():
		# these bones are always at the end of each finger
		# they are helpers and do not need to be processed for physics hand
		if bone_id in [4, 9, 14, 19, 24]:
			pass

		# save current bone skeleton pose as rest pose
		bone_rest_poses[bone_id] = controller_skeleton.get_bone_global_pose(bone_id)
		# save information to which finger current bone belongs
		finger_from_bone[bone_id] = controller_skeleton.get_bone_name(bone_id).split("_")[0]
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
	# process every bone in hand
	for bone_id in controller_skeleton.get_bone_count():
		process_bones(bone_id, delta)

	# physics hand can be bugged or stuck and we need it to be able to reset itself automatically
	# if physics hand is too far away from controller hand (>0.3m), we reset it back to controller position
	var distance_to_wrist: Vector3 = (controller_skeleton.global_transform * controller_skeleton.get_bone_global_pose(0)).origin - global_transform.origin
	if distance_to_wrist.length_squared() > 0.09:
		reset_hand()

	_move(delta)


func process_bones(bone_id: int, delta: float) -> void:
	# every physics bone collider needs to follow its bone relative to RigidBody wrist position
	# translation to Z=0.01 is needed because collider needs to begin with bone, not in the middle
	# if we do translation, it messes up with physics mesh so we revert it for physics hand mesh
	var physics_bone_target_transform: Transform3D = (controller_skeleton.get_bone_global_pose(0).inverse() * controller_skeleton.get_bone_global_pose(bone_id)).translated(Vector3(0, 0, 0.01)).rotated_local(Vector3.LEFT, deg_to_rad(-90))
	# we add short lag to physics collider following controller bones, so raycasts can detect collisions
	# TODO: Controller fingers do not follow natural path like real ones, but instead OpenXR runtime only sends current fingers location frame by frame
		# if player presses grab button quickly, fingers teleport from rest pose to full grab pose in 1 frame, resulting in raycasts not detecting any collisions during grab
		# it causes fingers going through held object instead of stopping on its surface
		# potential solution described in this GDC talk at 12:50 mark: https://www.gdcvault.com/play/1024240/It-s-All-in-the
	var physics_bone_collider := get_node(String(get_path()) + "/" + String.num_int64(bone_id))
	physics_bone_collider.transform = physics_bone_target_transform

	# physics skeleton follows Physics Hand and copies controller bones
	if bone_id == 0:
		# Physics Hand RigidBody is bone 0, so we set physics_skeleton bone 0 right on top of it
		physics_skeleton.set_bone_pose_position(bone_id, Vector3.ZERO)
		physics_skeleton.set_bone_pose_rotation(bone_id, Quaternion.IDENTITY)
	else:
		physics_skeleton.set_bone_pose_position(bone_id, controller_skeleton.get_bone_pose_position(bone_id))
		physics_skeleton.set_bone_pose_rotation(bone_id, controller_skeleton.get_bone_pose_rotation(bone_id))

	if bone_id == 0:
		# show controller ghost hand when it's far from physics hand
		var distance_wrist = (controller_skeleton.global_transform * controller_skeleton.get_bone_global_pose(0)).origin - global_transform.origin
		var distance_alpha = clamp((distance_wrist.length() - 0.1), 0, 0.5)
		var color = controller_hand_mesh_material.get_albedo()
		color.a = distance_alpha
		controller_hand_mesh_material.set_albedo(color)

	# freezing fingers around grabbed objects
	var bone_raycasts: Array[Node] = physics_bone_collider.get_node("RayCasts").get_children()
	# for every raycast in physics bone
	for raycast in bone_raycasts:
		# check if any of them is detecting collision
		raycast.force_raycast_update()
		if raycast.get_collider():
			# if yes, we will freeze this bone and backward bones
			# first, we check which finger this bone belongs to
			var finger: String = finger_from_bone[bone_id]

			# we iterate through every bone in this finger
			for finger_bone in finger_bones[finger]:
				# only process bones which are backwards from colliding bone (or the colliding bone itself)
				if finger_bone <= bone_id:
					# check if we already have frozen pose for this bone
					if !freezed_poses.has(finger_bone):
						# if not, save current bone pose to freezed poses
						freezed_poses[finger_bone] = controller_skeleton.get_bone_global_pose(finger_bone)

					# if player is grabbing, only then we freeze fingers on previously detected collision points
					if held_object:
						# apply freezed pose to current bone
						controller_skeleton.set_bone_global_pose_override(finger_bone, freezed_poses[finger_bone], 1.0, true)

			# if one raycast is detecting collision already, we don't need to check others
			break

func _move(delta: float) -> void:
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


func unfreeze_bones() -> void:
	controller_skeleton.clear_bones_global_pose_override()
	freezed_poses.clear()


func grab() -> Node3D:
	if held_object:
		return held_object

	if wrist_raycast.get_collider():
		# get object we just grabbed
		held_object = get_node(wrist_raycast.get_collider().get_path())
		physics_pivot_point = Node3D.new()
		held_object.add_child(physics_pivot_point)
		physics_pivot_point.global_transform = global_transform.translated(wrist_raycast.get_collision_point() - global_transform.origin)
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

		unfreeze_bones()


func reset_hand() -> void:
	drop_held_object()
	# move physics hand back to controller position
	global_transform.origin = (controller_skeleton.global_transform * controller_skeleton.get_bone_global_pose(0)).origin

	hand_reset.emit(self)


func _on_xr_controller_3d_button_pressed(name: StringName) -> void:
	if name == "grip_click":
		grab()

	if name == "by_button":
		thruster_forward = true

	if name == "ax_button":
		thruster_backward = true

	if name == "trigger_click":
		trigger_pressed = true


func _on_xr_controller_3d_button_released(name: StringName) -> void:
	if name == "grip_click":
		drop_held_object()

	if name == "by_button":
		thruster_forward = false

	if name == "ax_button":
		thruster_backward = false

	if name == "trigger_click":
		trigger_pressed = false


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
