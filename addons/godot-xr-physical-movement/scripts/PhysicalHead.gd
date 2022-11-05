extends RigidBody

export (NodePath) var body

# Called when the node enters the scene tree for the first time.
func _ready():
	body = get_node(body)

func _integrate_forces(state):
	# if head has collided with something
	if state.get_contact_count() > 0:
		# player hands are on collision layer 10 and 11, while held object is on layer 12
		# if head is colliding with player hands or held object, we're not pushing player body away
		if state.get_contact_collider_object(0).get_collision_layer_bit(10) || state.get_contact_collider_object(0).get_collision_layer_bit(11) || state.get_contact_collider_object(0).get_collision_layer_bit(12):
			pass
		else:
			# push body away from collision point
			body.apply_central_impulse(state.get_contact_local_normal(0))
		
