extends XRController3D

signal button(id: int, name: StringName)
signal trigger(value: float)
signal joystick_button(direction: int)
signal turned(direction: int)

var rotating: bool = false


func _process(_delta) -> void:
	var axis_joystick_x := get_vector2("primary").x
	var axis_joystick_y := get_vector2("primary").y
	var axis_trigger := get_float("trigger")
	var axis_grab := get_float("grip")

	if (axis_joystick_x < 0.1 and axis_joystick_x > -0.1):
		# if joystick X goes back to neutral position
		rotating = false
		return

	if (axis_joystick_x > 0.9 or axis_joystick_x < -0.9):
		# if joystick X is being pushed left or right
		turn(axis_joystick_x)


func axis_trigger() -> float:
	return get_float("trigger")


func axis_grab() -> float:
	return get_float("grip")


func turn(axis_joystick_x: float):
	# if player keeps pushing joystick X, we dont rotate more than once
	if rotating:
		return

	var direction: int
	if axis_joystick_x > 0.9:
		direction = -1 # right
	elif axis_joystick_x < 0.1:
		direction = 1 # left

	# we set this so rotation is always applied once per joystick X push, not continuous every frame
	rotating = true

	turned.emit(direction, self)
