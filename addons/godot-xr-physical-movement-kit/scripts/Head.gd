extends RigidBody3D

@export var body: CharacterBody3D
@export var camera: XRCamera3D

func _integrate_forces(state):
	global_transform.origin = camera.global_transform.origin
	# if head has collided with something
	if state.get_contact_count() > 0:
		# player hands are on collision layer 10 and 11, while held object is on layer 12
		# if head is colliding with player hands or held object, we're not pushing player body away
		if state.get_contact_collider_object(0).get_collision_layer_value(10) || state.get_contact_collider_object(0).get_collision_layer_value(11) || state.get_contact_collider_object(0).get_collision_layer_value(12):
			pass
		else:
			# push body away from collision point
			body.velocity += state.get_contact_local_normal(0) / 100
			pass
