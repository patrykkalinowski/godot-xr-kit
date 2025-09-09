extends Node3D

var interface: XRInterface
@export_group("Nodes")
@export var origin: XROrigin3D
@export var camera: XRCamera3D

func _ready():
	set_initial_player_position()


func set_initial_player_position():
	# Set player head on Player node position
	origin.global_transform = origin.global_transform.translated(global_transform.origin - camera.global_transform.origin + Vector3(0, 1.7, 0))

	var t1 = Transform3D()
	var t2 = Transform3D()
	var rot = Transform3D()

	t1.origin = camera.global_transform.origin
	t2.origin = -camera.global_transform.origin
	rot.basis = global_transform.basis * camera.global_transform.basis.inverse()

	origin.global_transform *= t1 * rot * t2


func enable_passthrough() -> bool:
	var xr_interface: XRInterface = XRServer.primary_interface
	if xr_interface and xr_interface.is_passthrough_supported():
		if !xr_interface.start_passthrough():
			return false
	else:
		var modes = xr_interface.get_supported_environment_blend_modes()
		if xr_interface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes:
			xr_interface.set_environment_blend_mode(xr_interface.XR_ENV_BLEND_MODE_ALPHA_BLEND)
		else:
			return false

	get_viewport().transparent_bg = true
	return true
