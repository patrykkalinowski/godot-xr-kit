extends Node3D

@export var camera: XRCamera3D
@export var left_wrist: RigidBody3D
@export var right_wrist: RigidBody3D

func _process(delta):
	# chest is always 30cm below camera
	global_transform.origin = camera.global_transform.origin
	global_transform.origin += Vector3.DOWN * 0.3
	
	# we rotate chest based on camera and wrists positions
	# camera influence is halved compared to hands influence
	var camera_forward = -camera.global_transform.basis.z.normalized() / 2
	var left_wrist_vector = left_wrist.global_transform.origin
	var right_wrist_vector = right_wrist.global_transform.origin
	
	# influences are merged to create final vector
	var target_vector = (global_transform.origin + camera_forward + left_wrist_vector + right_wrist_vector) / 3
	
	# keep rotation along chest Y axis, so it doesn't look up or down
	var look_at_vector = target_vector.slide(Vector3(0,1,0)) + Vector3(0, global_transform.origin.y, 0)
	
	# rotate chest
	global_transform = global_transform.looking_at(look_at_vector, Vector3.UP)
