extends Camera3D

var sensitivity: float = 0.2
var min_angle: float = -90
var max_angle: float = 90
var look_rot: Vector3 = Vector3()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	pass
	
func _input(event):
	if event is InputEventMouseMotion:
		look_rot.y -= event.relative.x * sensitivity
		look_rot.x -= event.relative.y * sensitivity
		look_rot.x = clamp(look_rot.x, min_angle, max_angle)
		
		rotation_degrees.x = look_rot.x
		rotation_degrees.y = look_rot.y
