extends ARVRController

# BUTTON IDs:
# JOY_VR_GRIP = 2  –  Grip (side) buttons on a VR controller.
# JOY_VR_PAD = 14  –  Push down on the touchpad or main joystick on a VR controller.
# JOY_VR_TRIGGER = 15  –  Trigger on a VR controller.
# JOY_OCULUS_AX = 7  –  A button on the right Oculus Touch controller, X button on the left controller (also when used in OpenVR).
# JOY_OCULUS_BY = 1  –  B button on the right Oculus Touch controller, Y button on the left controller (also when used in OpenVR).
# JOY_OCULUS_MENU = 3  –  Menu button on either Oculus Touch controller.
# JOY_OPENVR_MENU = 1  –  Menu button in OpenVR (Except when Oculus Touch controllers are used).
# JOY_VR_ANALOG_TRIGGER = 2  –  VR Controller analog trigger.
# JOY_VR_ANALOG_GRIP = 4  –  VR Controller analog grip (side buttons).
# JOY_OPENVR_TOUCHPADX = 0  –  OpenVR touchpad X axis (Joystick axis on Oculus Touch and Windows MR controllers).
# JOY_OPENVR_TOUCHPADY = 1  –  OpenVR touchpad Y axis (Joystick axis on Oculus Touch and Windows MR controllers).

var rotating = false

signal button(id, name)
signal trigger(value)
signal joystick_button(direction)
signal turn(direction)

func _physics_process(_delta):
	var axis_joystick_x = get_joystick_axis(0)
	var axis_joystick_y = get_joystick_axis(1)
	var axis_trigger = get_joystick_axis(2)
	var axis_grab = get_joystick_axis(4)
	
	if (axis_joystick_x < 0.1 && axis_joystick_x > -0.1):
		# if joystick X goes back to neutral position
		rotating = false
		
	if (axis_joystick_x > 0.9 || axis_joystick_x < -0.9):
		# if joystick X is being pushed left or right
		turn(axis_joystick_x)
	
func axis_trigger():
	return get_joystick_axis(2)

func axis_grab():
	return 

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
		
	emit_signal("turn", direction)
