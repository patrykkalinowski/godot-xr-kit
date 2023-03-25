extends XRController3D

var rotating = false

signal button(id, name)
signal trigger(value)
signal joystick_button(direction)
signal turned(direction)

func _physics_process(_delta):
	pass
	var axis_joystick_x = get_vector2("primary").x
	var axis_joystick_y = get_vector2("primary").y
	var axis_trigger = get_float("trigger")
	var axis_grab = get_float("grip")

	if (axis_joystick_x < 0.1 && axis_joystick_x > -0.1):
		# if joystick X goes back to neutral position
		rotating = false

	if (axis_joystick_x > 0.9 || axis_joystick_x < -0.9):
		# if joystick X is being pushed left or right
		turn(axis_joystick_x)
	
func axis_trigger():
	return get_float("trigger")

func axis_grab():
	return get_float("grip")

func turn(axis_joystick_x):
	# if player keeps pushing joystick X, we dont rotate more than once
	if rotating:
		return
		
	var direction
	if axis_joystick_x > 0.9:
		direction = -1 # right
	elif axis_joystick_x < 0.1:	
		direction = 1 # left
	
	# we set this so rotation is always applied once per joystick X push, not continuous every frame
	rotating = true
		
	emit_signal("turned", direction, self)
