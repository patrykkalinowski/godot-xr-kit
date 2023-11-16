extends XRController3D

signal button(id: int, name: StringName)
signal trigger(value: float)
signal joystick_button(direction: int)
signal turned_x(direction: int)
signal turned_y(direction: int)
signal thruster(value: Vector2)
signal thruster_brake(value: bool)
signal grab(value: bool)

var rotating_x: bool = false
var rotating_y: bool = false
var free_rotation: bool = false


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

# process input from controller joysticks
func _on_input_vector_2_changed(name, value):
	if name == "thruster":
		thruster.emit(value)

	if name == "rotate":
		turn_x(value.x)
		turn_y(value.y)


func _on_button_pressed(name: String) -> void:
	if name == "grip_click":
		grab.emit(true)

	if name == "thruster_brake":
		thruster_brake.emit(true)

	if name == "free_rotation":
		free_rotation = true


func _on_button_released(name: String) -> void:
	if name == "grip_click":
		grab.emit(false)

	if name == "thruster_brake":
		thruster_brake.emit(false)

	if name == "free_rotation":
		free_rotation = false
