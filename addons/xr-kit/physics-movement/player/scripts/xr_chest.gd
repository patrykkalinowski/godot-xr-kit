extends Node3D

func _process(delta: float) -> void:
	# chest is always 30cm below camera
	global_transform.origin = %XRCamera.global_transform.origin - %XROrigin.global_transform.basis.y * 0.3
	# we rotate chest based on camera and wrists positions
	var camera_forward: Vector3 = -%XRCamera.global_transform.basis.z.normalized() / 2 # camera influence is halved compared to hands influence
	# influences are merged to create final vector
	var target_vector: Vector3 = (global_transform.origin + camera_forward + %PhysicsHandLeft.global_transform.origin + %PhysicsHandRight.global_transform.origin) / 3
	# keep rotation along chest Y axis, so it doesn't look up or down
	var look_at_vector = target_vector.slide(Vector3(0,1,0)) + Vector3(0, global_transform.origin.y, 0)
	# rotate chest
	global_transform = global_transform.looking_at(look_at_vector, %XROrigin.global_transform.basis.y)
