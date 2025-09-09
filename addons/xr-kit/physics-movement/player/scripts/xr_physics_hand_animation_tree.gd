extends AnimationTree

var runtime: String
var grip_value: float
var trigger_value: float


func _ready() -> void:
	# Disable all animations when in SteamVR as we are using inferred hand tracking
	if !XRServer.primary_interface:
		return

	runtime = XRServer.primary_interface.get_system_info()['XRRuntimeName']
	if runtime == "SteamVR/OpenXR":
		active = false


func _physics_process(delta: float) -> void:
	if !active:
		return

	# Controller animation should follow button presses from controller, but with a slight delay to allow raycasts on fingers to detect objects to grip with IK (as controller can go from 0 to 1 in a single frame, we have to slow it down so fingers curl in a more natural way)
	
	# Update grip
	var from: float = get("parameters/CloseGrip/blend_amount")
	var to: float = grip_value

	var weight: float = delta * 50.0
	# Ensure weight does not exceed 1
	weight = min(weight, 1.0)

	set("parameters/GripTimeSeek/seek_request", 1) # Make sure source animation is fully applied
	set("parameters/CloseGrip/blend_amount", lerpf(from, to, weight))

	# Update trigger
	from = get("parameters/CloseIndex/blend_amount")
	to = trigger_value

	set("parameters/IndexTimeSeek/seek_request", 1) # Make sure source animation is fully applied
	set("parameters/CloseIndex/blend_amount", lerpf(from, to, weight))

	

func _on_grip(value: float) -> void:
	grip_value = value


func _on_trigger(value: float) -> void:
	trigger_value = value


#func _on_reset(reset: bool) -> void:
	#set("parameters/RESET/blend_amount", 1 if reset else 0)


# Animate only when using controller
func _on_controller_tracking_changed(tracking: bool) -> void:
	if tracking:
		if runtime == "SteamVR/OpenXR":
			return

		active = true
	else:
		active = false
