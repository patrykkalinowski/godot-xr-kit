extends XRController3D

signal trigger(value: float)
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


#func _physics_process(delta: float) -> void:
	# Show controller ghost hand when it's far from physics hand
	#var distance_wrist = (controller_skeleton.global_transform * controller_skeleton.get_bone_global_pose(0)).origin - global_transform.origin
	#var distance_alpha = clamp((distance_wrist.length() - 0.1), 0, 0.5)
	#var color = controller_hand_mesh_material.get_albedo()
	#color.a = distance_alpha
	#controller_hand_mesh_material.set_albedo(color)
	
	
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


func _on_input_float_changed(action_name: String, value: float) -> void:
	if action_name == "grip":
		grip.emit(value)

	if action_name == "trigger":
		trigger.emit(value)


# process input from controller joysticks
func _on_input_vector_2_changed(action_name, value):
	if action_name == "thruster":
		thruster.emit(value)

	if action_name == "rotate":
		turn_x(value.x)
		turn_y(value.y)


func _on_button_pressed(action_name: String) -> void:
	if action_name == "grab":
		grab.emit(true)

	if action_name == "thruster_brake":
		thruster_brake.emit(true)

	if action_name == "free_rotation":
		free_rotation_signal.emit(true)
		free_rotation = true
		
	if action_name == "trigger_touch":
		trigger.emit(0.03)


func _on_button_released(action_name: String) -> void:
	if action_name == "grab":
		grab.emit(false)

	if action_name == "thruster_brake":
		thruster_brake.emit(false)
		
	if action_name == "trigger_touch":
		trigger.emit(0)

	if action_name == "free_rotation":
		free_rotation_signal.emit(false)
		free_rotation = false


func _on_trigger_haptic(type: String):
	if type == "drop_held_object":
		trigger_haptic_pulse("haptic", 50, 1.0, 0.5, 0.0)
