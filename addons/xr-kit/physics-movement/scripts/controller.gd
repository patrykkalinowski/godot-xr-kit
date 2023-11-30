extends XRController3D

@export var controller_skeleton: Skeleton3D
@export var openxr_hand: OpenXRHand

signal button(id: int, name: StringName)
signal trigger(value: float)
signal joystick_button(direction: int)
signal turned_x(direction: int)
signal turned_y(direction: int)
signal thruster(value: Vector2)
signal thruster_brake(value: bool)
signal grab(value: bool)
signal grip(value: float)
signal free_rotation_signal(value: bool)

var rotating_x: bool = false
var rotating_y: bool = false
var free_rotation: bool = false


func _ready() -> void:
	# setup controllers for Oculus
	var runtime = XRServer.primary_interface.get_system_info()['XRRuntimeName']
	if runtime == "Oculus":
		set_pose_name("grip")

		# rotate controller hand skeleton to match controller grip pose
		var difference: Transform3D = global_transform * controller_skeleton.get_node("Wrist/Grip Pose").global_transform.inverse()
		# difference before original transform - order matters!
		controller_skeleton.set_bone_rest(0, (difference * controller_skeleton.get_bone_pose(0)).orthonormalized())
		# return to rest pose
		controller_skeleton.reset_bone_poses()


func turn_x(joystick: float):
	if (joystick < 0.1 and joystick > -0.1):
		# if joystick X goes back to neutral position
		rotating_x = false
		return

	# if player keeps pushing joystick X, we dont rotate more than once
	# TODO: implement smooth rotation and smooth/snap setting
	if rotating_x:
		return

	var direction: int
	if joystick > 0.9:
		direction = -1 # right
	elif joystick < -0.9:
		direction = 1 # left
	else:
		return

	# we set this so rotation is always applied once per joystick X push, not continuous every frame
	rotating_x = true

	turned_x.emit(direction, self)

func turn_y(joystick: float):
	if (joystick < 0.1 and joystick > -0.1):
		# if joystick X goes back to neutral position
		rotating_y = false
		return

	# if player keeps pushing joystick X, we dont rotate more than once
	# TODO: implement smooth rotation and smooth/snap setting
	if rotating_y:
		return

	var direction: int
	if joystick > 0.9:
		direction = -1 # up
	elif joystick < -0.9:
		direction = 1 # down
	else:
		return

	# we set this so rotation is always applied once per joystick X push, not continuous every frame
	rotating_y = true

	turned_y.emit(direction, self)


func _on_input_float_changed(name: String, value: float) -> void:
	if name == "grip":
		grip.emit(value)

	if name == "trigger":
		trigger.emit(value)


# process input from controller joysticks
func _on_input_vector_2_changed(name, value):
	if name == "thruster":
		thruster.emit(value)

	if name == "rotate":
		turn_x(value.x)
		turn_y(value.y)


func _on_button_pressed(name: String) -> void:
	if name == "grab":
		grab.emit(true)

	if name == "thruster_brake":
		thruster_brake.emit(true)

	if name == "free_rotation":
		free_rotation_signal.emit(true)
		free_rotation = true


func _on_button_released(name: String) -> void:
	if name == "grab":
		grab.emit(false)

	if name == "thruster_brake":
		thruster_brake.emit(false)

	if name == "free_rotation":
		free_rotation_signal.emit(false)
		free_rotation = false


func _on_tracking_changed(tracking: bool) -> void:
	# switch between controller and hand tracking
	# we ignore tracking changes when on SteamVR as we utilise inferred hand tracking feature
	# we also make sure controller_skeleton is valid, sometimes it's freed too early on exit and crashes Godot
	var runtime = XRServer.primary_interface.get_system_info()['XRRuntimeName']
	if !is_instance_valid(controller_skeleton) or runtime == "SteamVR/OpenXR":
		return

	if tracking:
		controller_skeleton.reparent(self, false)
		controller_skeleton.reset_bone_poses()

	elif XRServer.primary_interface.is_hand_tracking_supported():
		# TODO: Do not switch if OpenXRHand is not receiving tracking data, runtimes can report it as supported even when it's not working (ex. SteamVR supports it, but will not provide data)
		# Currently, OpenXRHand does not have any direct way to check if it's receiving tracking data, the only option is to check if skeleton is being updated
		controller_skeleton.reparent(openxr_hand, false)
		controller_skeleton.reset_bone_poses()

