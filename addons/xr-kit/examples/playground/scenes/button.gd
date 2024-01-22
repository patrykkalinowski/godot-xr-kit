extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_area_3d_body_entered(body):
	if body == $RigidBody3D:
		$RigidBody3D/Button.get_surface_override_material(0).set_feature(0, true)


func _on_area_3d_body_exited(body):
	if body == $RigidBody3D:
		$RigidBody3D/Button.get_surface_override_material(0).set_feature(0, false)

