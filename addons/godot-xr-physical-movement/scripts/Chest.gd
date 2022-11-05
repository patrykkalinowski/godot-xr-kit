extends Spatial

export (NodePath) var camera
export (NodePath) var left_wrist
export (NodePath) var right_wrist

func _ready():
	camera = get_node(camera)
	left_wrist = get_node(left_wrist)
	right_wrist = get_node(right_wrist)

func _physics_process(_delta):
	# chest is always 30cm below camera
	global_transform.origin = camera.global_transform.origin
	global_transform.origin.y -= 0.3
	
	# we rotate chest based on camera and wrists positions
	var camera_forward = -camera.global_transform.basis.z.normalized()
	var left_wrist_vector = left_wrist.global_transform.origin
	var right_wrist_vector = right_wrist.global_transform.origin
	var target_vector = (global_transform.origin + camera_forward + left_wrist_vector + right_wrist_vector) / 3
	
	# keep rotation along chest Y axis, so it doesn't look up or down
	var look_at_vector = target_vector.slide(Vector3(0,1,0)) + Vector3(0, global_transform.origin.y, 0)
	
	# rotate chest
	global_transform = global_transform.looking_at(look_at_vector, Vector3.UP)
	
