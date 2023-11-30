extends AnimationTree

var runtime: String


func _ready() -> void:
	# disable all animations when in SteamVR as we are using inferred hand tracking
	runtime = XRServer.primary_interface.get_system_info()['XRRuntimeName']
	if runtime == "SteamVR/OpenXR":
		active = false


func _on_grip(value: float) -> void:
	set("parameters/grip_value/seek_request", value)

func _on_trigger(value: float) -> void:
	set("parameters/index_value/seek_request", value)


# animate only when using controller
func _on_controller_tracking_changed(tracking: bool) -> void:
	if tracking:
		if runtime == "SteamVR/OpenXR":
			return

		active = true
	else:
		active = false


