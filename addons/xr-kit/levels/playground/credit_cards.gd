extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	var cards = get_children()
	for card: RigidBody3D in cards:
		card.apply_central_impulse(Vector3.UP * randf() / 10)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
