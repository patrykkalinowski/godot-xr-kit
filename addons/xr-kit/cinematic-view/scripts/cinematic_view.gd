extends Node

@export var enabled: bool = true
@export var screen_id: int = 0
@export var xr_camera: XRCamera3D
@export_group("Position Filter Parameters")
@export var allowed_jitter: float = 1 # fcmin (cutoff), decrease to reduce jitter
@export var lag_reduction: float = 5 # beta, increase to reduce lag
@export_group("Rotation Filter Parameters")
@export_range(0.0, 1.0) var rotation_smoothing: float = 0.95
var x_filter
var y_filter
var z_filter

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if enabled:
		$Window.visible = true
		$Window.set_current_screen(screen_id)
		$Window.size = DisplayServer.screen_get_size(screen_id)

		var OneEuroFilter = load("res://addons/xr-kit/smooth-input-filter/scripts/one_euro_filter.gd")
		var args := {
			"cutoff": allowed_jitter,
			"beta": lag_reduction,
		}
		x_filter = OneEuroFilter.new(args)
		y_filter = OneEuroFilter.new(args)
		z_filter = OneEuroFilter.new(args)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if enabled:
		# translation
		var origin: Vector3 = xr_camera.global_transform.origin
		var x: float = x_filter.filter(origin.x, delta)
		var y: float = y_filter.filter(origin.y, delta)
		var z: float = z_filter.filter(origin.z, delta)
		# rotation
		var q1 = Quaternion(xr_camera.global_transform.basis)
		var q2 = Quaternion($Window/Camera3D.global_transform.basis)
		var dot_product = q1.dot(q2)
		var rotated_basis = $Window/Camera3D.global_transform.basis.slerp(xr_camera.global_transform.basis, 1 / dot_product - rotation_smoothing)

		$Window/Camera3D.set_global_transform(Transform3D(rotated_basis, Vector3(x, y, z)))

func _on_close_requested() -> void:
	self.queue_free()
