extends CharacterBody3D

@export var origin: XROrigin3D
@export var camera: XRCamera3D
@export var turn_angle_degrees: int = 30 # angle to rotate player body using controller joystick
@export var physics_hand_left: Node3D
@export var physics_hand_right: Node3D
@export var body_mass: int = 80

var physics_pivot_point := Transform3D.IDENTITY
var controller_pivot_point := Transform3D.IDENTITY
var held_objects_count: int = 0


func _process(delta) -> void:
	var mass_modifiers := []
	var blended_mass_modifier = 1.0

	set_physics_pivot_point()
	set_controller_pivot_point()

	for hand in [physics_hand_left, physics_hand_right]:
		if hand.thruster_forward:
			# TODO: increase force when players tries to stop while moving fast in opposite direction
			velocity += -hand.controller.global_transform.basis.z.normalized() * delta / 10

		if hand.thruster_backward:
			velocity += hand.controller.global_transform.basis.z.normalized() * delta / 10

		# body movement dependent on held object mass
		if hand.held_object:
			# if held object is lighter than player body,
			# reduce force applied to body movement according to held object's mass
			# for example, if held object is 40kg (half of body mass), body receives only half of usual movement force
			# that way, moving light objects around won't push player body away in zero gravity
			var mass_modifier := 1.0
			if hand.held_object.get_class() == "RigidBody3D":
				# clamp is used to make sure holding heavier object
				# won't increase movement force to crazy levels
				var mass_ratio = hand.held_object.get_mass() / body_mass
				mass_modifier = clamp(mass_ratio, 0.0, 1.0) / 50.0

			mass_modifiers.append(mass_modifier)

	if held_objects_count > 0:
		# when holding an object, we stop the body and it is now moved only by hands
		# TODO: preserve momentum so player body doesn't stop abruptly
		set_velocity(Vector3.ZERO)

		# body XYZ rotation when holding static objects, activated by trigger
		if acts_as_static(physics_hand_left.held_object) and physics_hand_left.trigger_pressed or acts_as_static(physics_hand_right.held_object) and physics_hand_right.trigger_pressed:
			var rotation_difference: Transform3D = physics_pivot_point * controller_pivot_point.inverse()
			origin.global_transform = (rotation_difference * origin.global_transform).orthonormalized() # rotation_difference before original transform - order matters!
			return

		# if player is holding two different objects with different mass, body movement is based on heavier object
		# TODO: mass modifier should be separate for every hand
		# TODO: if trigger is pressed, this hand should not cause body movement
		if mass_modifiers.max():
			blended_mass_modifier = mass_modifiers.max()

		# if one hand is holding StaticBody, override pivot_points so body movement
		# is not influenced by RigidBody held by the other hand
		if acts_as_static(physics_hand_left.held_object):
			set_physics_pivot_point(physics_hand_left)
			set_controller_pivot_point(physics_hand_left)

		if acts_as_static(physics_hand_right.held_object):
			set_physics_pivot_point(physics_hand_right)
			set_controller_pivot_point(physics_hand_right)

		var move_vector = (physics_pivot_point.origin - controller_pivot_point.origin) / delta
		velocity += move_vector * blended_mass_modifier

	if held_objects_count == 0:
		# if player is floating in space, limit maximum velocity to 1 and reduce it by 5% every second
		velocity = velocity.limit_length(1)
		velocity *= 1 - (0.05 * delta)

	move_and_slide() # move body by calculated velocity


func set_controller_pivot_point(forced_hand: Node3D = null) -> void:
	var controller_transforms := []

	for hand in [physics_hand_left, physics_hand_right]:
		# pivot_point can be forced for selected hand
		if forced_hand and forced_hand != hand:
			continue

		if hand.held_object:
			var controller_anchor_point_from_wrist: Vector3 = hand.physics_pivot_point.global_transform.origin - hand.global_transform.origin

			controller_pivot_point = (hand.controller_skeleton.global_transform * hand.controller_skeleton.get_bone_global_pose(0)).translated(controller_anchor_point_from_wrist)
			controller_transforms.append(controller_pivot_point)

	if controller_transforms.size() > 0:
		controller_pivot_point.origin = controller_transforms.map(func(transform): return transform.origin).reduce(func(vector_sum, vector): return vector_sum + vector)
		controller_pivot_point.origin /= controller_transforms.size()

	if controller_transforms.size() == 2:
		controller_pivot_point = controller_pivot_point.looking_at(controller_transforms[1].origin, Vector3.UP)
	elif controller_transforms.size() == 1:
		controller_pivot_point.basis = controller_transforms[0].basis
	else:
		controller_pivot_point = Transform3D.IDENTITY


func set_physics_pivot_point(forced_hand: Node3D = null) -> void:
	var physics_transforms := []

	for hand in [physics_hand_left, physics_hand_right]:
		# pivot_point can be forced for selected hand
		if forced_hand and forced_hand != hand:
			continue

		if hand.held_object:
			physics_transforms.append(hand.physics_pivot_point.global_transform)

	if physics_transforms.size() > 0:
		# take every transform from array, extract origin, and sum origins
		physics_pivot_point.origin = physics_transforms.map(func(transform): return transform.origin).reduce(func(vector_sum, vector): return vector_sum + vector)
		# if two hands, divide resulting sum of origins by 2, so pivot point is between them
		physics_pivot_point.origin /= physics_transforms.size()

	if physics_transforms.size() == 2:
		physics_pivot_point = physics_pivot_point.looking_at(physics_transforms[1].origin, Vector3.UP)
	elif physics_transforms.size() == 1:
		physics_pivot_point.basis = physics_transforms[0].basis
	else:
		physics_pivot_point = Transform3D.IDENTITY

	held_objects_count = physics_transforms.size()


func acts_as_static(object: Node3D) -> bool:
	if object:
		return (object.is_class("StaticBody3D") || (object.is_class("RigidBody3D") && object.is_freeze_enabled() && object.get_freeze_mode() == 0))
	else:
		return false


# turn signal received from controller
func _on_turned(direction: int, controller: Node3D) -> void:
	var angle: float = deg_to_rad(turn_angle_degrees) * direction
	var rotation_difference := Transform3D.IDENTITY.rotated(origin.transform.basis.y, angle)
	origin.transform = rotation_difference * origin.transform
	set_physics_pivot_point()
	set_controller_pivot_point()
	# when rotating around a point, origin needs to be moved to proper position after rotation
	origin.global_translate(physics_pivot_point.origin - controller_pivot_point.origin)

	for hand in [physics_hand_left, physics_hand_right]:
		if !hand.held_object:
			hand.reset_hand()


func _on_physics_hand_grabbed(held_object: Node3D) -> void:
	set_physics_pivot_point()
	# if both hands are holding the same object, override its center of mass to blended physics_pivot_point which is between hands physics_pivot_points
	if physics_hand_left.held_object == physics_hand_right.held_object and held_object.is_class("RigidBody3D") :
		var center_of_mass: Vector3 = physics_pivot_point.origin - held_object.global_transform.origin
		held_object.set_center_of_mass_mode(1) # enable custom center of mass
		held_object.set_center_of_mass(center_of_mass)


func _on_hand_reset(hand: Node3D) -> void:
	set_physics_pivot_point()


func _on_hand_dropped_held_object(held_object: Node3D) -> void:
	set_physics_pivot_point()
