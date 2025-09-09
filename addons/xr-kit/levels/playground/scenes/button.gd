extends Node3D


func _on_area_3d_body_entered(body):
	if body == $RigidBody3D:
		$RigidBody3D/Button.get_surface_override_material(0).set_feature(0, true)


func _on_area_3d_body_exited(body):
	if body == $RigidBody3D:
		$RigidBody3D/Button.get_surface_override_material(0).set_feature(0, false)
