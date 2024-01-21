extends CharacterBody3D

@export var turn_angle_degrees: int = 30 # Angle to rotate player body using controller joystick
@export var body_mass: int = 80

var physics_pivot_point := Transform3D.IDENTITY
var controller_pivot_point := Transform3D.IDENTITY
var held_objects_count: int = 0
var thruster := Vector2(0,0)
var thruster_brake := false
var rotated_transform_x := Transform3D.IDENTITY
var player_rotating_x_angle := 0.0
var free_rotation_initial_difference := Transform3D.IDENTITY
var pushback_velocity := Vector3.ZERO
var real_velocity := Vector3.ZERO
var target_velocity: Vector3


func _physics_process(delta) -> void:
	var mass_modifiers := []
	var blended_mass_modifier = 1.0

	# Body collider shapes follow their nodes
	$HeadCollider.global_transform = %Camera.global_transform

	# Rotate player body with controller joystick
	if player_rotating_x_angle and !(%PhysicsHandLeft.controller.free_rotation or %PhysicsHandRight.controller.free_rotation):
		var rotation_difference := Transform3D.IDENTITY.rotated(Vector3.UP, player_rotating_x_angle)
		if controller_pivot_point == Transform3D.IDENTITY:
			# Player is not holding anything, rotate Origin around camera
			var t1 := Transform3D()
			var t2 := Transform3D()
			t1.origin = %Camera.transform.origin
			t2.origin = -%Camera.transform.origin
			%Origin.transform = %Origin.transform * t1 * rotation_difference * t2
		else:
			# Player is holding an object, rotate Origin around controller_pivot_point
			# Find target transform by moving Origin to controller_pivot_point, rotating it, then moving it back
			var t1 := Transform3D()
			var t2 := Transform3D()

			t1.origin = controller_pivot_point.origin + %Camera.transform.origin
			t2.origin = -(controller_pivot_point.origin + %Camera.transform.origin)
			var target_transform: Transform3D = %Origin.global_transform * t1 * rotation_difference * t2

			rotate_origin_around_controller(target_transform, true)



		for hand in [%PhysicsHandLeft, %PhysicsHandRight]:
			if !hand.held_object:
				hand.reset_hand()

		player_rotating_x_angle = 0.0

	set_physics_pivot_point()
	set_controller_pivot_point()

	# Apply thruster input
	var thruster_velocity := Vector3.ZERO
	thruster_velocity += -%Camera.global_transform.basis.z.normalized() * delta * thruster.y / 10
	thruster_velocity += %Camera.global_transform.basis.x.normalized() * delta * thruster.x / 10

	var pushback_velocity: Vector3
	for hand in [%PhysicsHandLeft, %PhysicsHandRight]:
		# Body movement dependent on held object mass
		if hand.held_object:
			# If held object is lighter than player body,
				# reduce force applied to body movement according to held object's mass
				# for example, if held object is 40kg (half of body mass), body receives only half of usual movement force
				# that way, moving light objects around won't push player body away in zero gravity
			var mass_modifier := 0.2 # Default if held object is not RigidBody3D
			if hand.held_object.get_class() == "RigidBody3D":
				# Clamp is used to make sure holding heavier object
					# won't increase movement force to crazy levels
				var mass_ratio = hand.held_object.get_mass() / body_mass
				mass_modifier = clamp(mass_ratio, 0.0, 1.0) / 50.0

			mass_modifiers.append(mass_modifier)
		else:
			# If hand is not holding anything, enable pushing away using hands (aka Gorilla Tag movement)
			if hand.get_colliding_bodies().size() > 0 and hand.get_colliding_bodies()[0].name not in ["PhysicsHandLeft", "PhysicsHandRight", "Body"]:
				# Pushback vector based on palm positions
				var pushback_vector: Vector3 = (hand.physics_skeleton.global_transform * hand.physics_skeleton.get_bone_global_pose(25)).origin - (hand.controller_skeleton.global_transform * hand.controller_skeleton.get_bone_global_pose(25)).origin
				# Apply pushback vector to player body only if it's pushing player away, not pulling towards object
				if pushback_vector.dot(hand.collision_normal) >= 0:
					var mass_modifier := 0.8 # Default if held object is not RigidBody3D
					if hand.colliding_object.get_class() == "RigidBody3D":
						# Clamp is used to make sure holding heavier object
							# won't increase movement force to crazy levels
						var mass_ratio = hand.colliding_object.get_mass() / body_mass
						mass_modifier = clamp(mass_ratio, 0.0, 1.0) / 10.0

					pushback_velocity += pushback_vector * hand.controller_skeleton_velocity.length() * mass_modifier * delta * 30


	var grab_velocity: Vector3 = Vector3.ZERO
	if held_objects_count > 0:
		# When holding an object, we stop the body and it is now moved only by hands
		# TODO: Preserve momentum so player body doesn't stop abruptly
		# set_velocity(Vector3.ZERO)

		# Body XYZ rotation activated by trigger
		if %ControllerLeft.free_rotation or %ControllerRight.free_rotation:
			# If only one hand is holding static object, force rotation around that hand
			if acts_as_static(%PhysicsHandLeft.held_object) and %PhysicsHandRight.held_object and !acts_as_static(%PhysicsHandRight.held_object):
				set_controller_pivot_point(%PhysicsHandLeft)
				set_physics_pivot_point(%PhysicsHandLeft)
				%ControllerRight.free_rotation = false

			if acts_as_static(%PhysicsHandRight.held_object) and %PhysicsHandLeft.held_object and !acts_as_static(%PhysicsHandLeft.held_object):
				set_controller_pivot_point(%PhysicsHandRight)
				set_controller_pivot_point(%PhysicsHandRight)
				%ControllerLeft.free_rotation = false

			# When free rotation is activated, we modify rotation_difference so player body stays in place instead of rotating within one frame for physics_pivot_point to reach controller_pivot_point. In a way, we set controller_pivot_point at the same place as physics_pivot_point
			if free_rotation_initial_difference == Transform3D.IDENTITY:
				free_rotation_initial_difference = physics_pivot_point * controller_pivot_point.inverse()

			var pivot_difference: Transform3D = free_rotation_initial_difference.inverse() * physics_pivot_point * controller_pivot_point.inverse()
			var target_transform: Transform3D = pivot_difference * %Origin.global_transform # Rotation_difference before original transform - order matters!
			rotate_origin_around_controller(target_transform)
			return
		else:
			# If free rotation is deactivated for both hands, reset rotation_difference
			free_rotation_initial_difference = Transform3D.IDENTITY

		# If player is holding two different objects with different mass, body movement is based on heavier object
		# TODO: Mass modifier should be separate for every hand
		# TODO: If trigger is pressed, this hand should not cause body movement
		if mass_modifiers.max():
			blended_mass_modifier = mass_modifiers.max()

		# If one hand is holding StaticBody, override pivot_points so body movement
			# is not influenced by RigidBody held by the other hand
		if acts_as_static(%PhysicsHandLeft.held_object):
			set_physics_pivot_point(%PhysicsHandLeft)
			set_controller_pivot_point(%PhysicsHandLeft)

		if acts_as_static(%PhysicsHandRight.held_object):
			set_physics_pivot_point(%PhysicsHandRight)
			set_controller_pivot_point(%PhysicsHandRight)

		var move_vector = (physics_pivot_point.origin - controller_pivot_point.origin) / delta
		grab_velocity = move_vector * blended_mass_modifier


	var momentum := velocity
	if held_objects_count == 0:
		# If player is floating in space, keep reducing maximum velocity until it reaches 1 (reduce more the faster current velocity), then reduce it further by 5% every second
		momentum = velocity.limit_length(maxf(1.0, velocity.length() - ((velocity.length() - sqrt(velocity.length())) * delta)))
		momentum *= 1 - (0.05 * delta)

		free_rotation_initial_difference = Transform3D.IDENTITY

	if thruster_brake:
		momentum *= 1 - (2 * delta)

	velocity = momentum + thruster_velocity + pushback_velocity
	if grab_velocity.length() > 0:
		velocity += grab_velocity - momentum

	move_and_slide() # Move body by calculated velocity

	# Handle player bumping into objects
	# Pushback will be applied on next physics frame
	var collision: KinematicCollision3D = get_last_slide_collision()

	if collision:
		var collider = collision.get_collider(0)

		if collider.is_class("RigidBody3D"):
			# Pushback depends on collider mass
			var mass_ratio = collider.get_mass() / body_mass
			var mass_modifier = clamp(mass_ratio, 0.0, 1.0)
			# Apply impulse to collided RigidBody
			collision.get_collider(0).apply_impulse(-collision.get_normal(0).normalized() * velocity.length() * mass_modifier * 0.5 / delta, collision.get_position(0) - collision.get_collider(0).global_transform.origin)

			velocity = get_real_velocity().limit_length(velocity.length() + 1.0) * mass_modifier
		else:
			# For static bodies; +1.0 is needed for when body is not moving but player headbutts the object, that way we can have pushback bigger than 0
			velocity = get_real_velocity().limit_length(velocity.length() + 1.0)

func set_controller_pivot_point(forced_hand: Node3D = null) -> void:
	var controller_transforms := []

	for hand in [%PhysicsHandLeft, %PhysicsHandRight]:
		# Pivot_point can be forced for selected hand
		# Other hand is then ignored in pivot point calculation
		if forced_hand and forced_hand != hand:
			continue

		if hand.held_object:
			controller_pivot_point = hand.controller_skeleton.global_transform * hand.controller_skeleton.get_bone_global_pose(25)
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

	for hand in [%PhysicsHandLeft, %PhysicsHandRight]:
		# Pivot_point can be forced for selected hand
		# Other hand is then ignored in pivot point calculation
		if forced_hand and forced_hand != hand:
			continue

		if hand.held_object:
			physics_transforms.append(hand.physics_pivot_point.global_transform)

	if physics_transforms.size() > 0:
		# Take every transform from array, extract origin, and sum origins
		physics_pivot_point.origin = physics_transforms.map(func(transform): return transform.origin).reduce(func(vector_sum, vector): return vector_sum + vector)
		# If two hands, divide resulting sum of origins by 2, so pivot point is between them
		physics_pivot_point.origin /= physics_transforms.size()

	if physics_transforms.size() == 2:
		physics_pivot_point = physics_pivot_point.looking_at(physics_transforms[1].origin, Vector3.UP)
	elif physics_transforms.size() == 1:
		physics_pivot_point.basis = physics_transforms[0].basis
	else:
		physics_pivot_point = Transform3D.IDENTITY

	held_objects_count = physics_transforms.size()


func rotate_origin_around_controller(target_transform: Transform3D, horizontal_axis_only: bool = false) -> void:
	# Move origin to target position, but it will stop at collision
	# TODO: Put move_and_collide() vector through 1Euro filter to smooth out controller jitter
	var collision: KinematicCollision3D = move_and_collide(target_transform.origin - %Origin.global_transform.origin)
	# TODO: apply impulses to RigidBodies player body collided with (in separate function to be used also for normal grab state)
	# Origin is now moved, but not rotated and pivot points have diverged. Calculate how much origin should rotate so pivot points will be aligned again
	if horizontal_axis_only:
		# TODO: Calculated horizontal rotation is incorrect, needs to be fixed
		var t1 := Transform3D()
		var t2 := Transform3D()
		t1.origin = %Camera.transform.origin
		t2.origin = -%Camera.transform.origin

		# Recalculate pivot points after moving Origin
		set_controller_pivot_point()
		set_physics_pivot_point()

		# Calculate rotation only on Origin's horizontal axis
		var flat_controller_pivot_point = controller_pivot_point
		flat_controller_pivot_point.origin.y = %Camera.global_transform.origin.y
		var flat_physics_pivot_point = physics_pivot_point
		flat_physics_pivot_point.origin.y = %Camera.global_transform.origin.y
		var looking_at_controller_pivot_point: Transform3D = %Camera.global_transform.looking_at(flat_controller_pivot_point.origin, Vector3.UP)
		var looking_at_physics_pivot_point: Transform3D = %Camera.global_transform.looking_at(flat_physics_pivot_point.origin, Vector3.UP)
		var transform_to_rotate := Transform3D()
		transform_to_rotate.basis = looking_at_physics_pivot_point.basis * looking_at_controller_pivot_point.basis.inverse()

		%Origin.transform = %Origin.transform * t1 * transform_to_rotate * t2
		# After rotation, Origin is still offset from final position, we recalculate pivot points and move Origin so pivot points are aligned
		set_controller_pivot_point()
		set_physics_pivot_point()
		%Origin.transform = %Origin.transform.translated(physics_pivot_point.origin - controller_pivot_point.origin)
	else:
		var looking_at_controller_pivot_point: Transform3D = %Origin.global_transform.looking_at(controller_pivot_point.origin, controller_pivot_point.basis.y)
		var looking_at_physics_pivot_point: Transform3D = %Origin.global_transform.looking_at(physics_pivot_point.origin, physics_pivot_point.basis.y)
		var transform_to_rotate: Transform3D = looking_at_physics_pivot_point * looking_at_controller_pivot_point.inverse()

		%Origin.global_transform = transform_to_rotate * %Origin.global_transform


func acts_as_static(object: Node3D) -> bool:
	if object:
		return (object.is_class("StaticBody3D") || (object.is_class("RigidBody3D") && object.is_freeze_enabled() && object.get_freeze_mode() == 0))
	else:
		return false


# Turn signal received from controller
func _on_turned_x(direction: int, controller: Node3D) -> void:
	var angle: float = deg_to_rad(turn_angle_degrees) * direction
	player_rotating_x_angle = angle


# TODO: Up/down rotation doesn't work correctly, needs to be fixed
func _on_turned_y(direction: int, controller: Node3D) -> void:
	var angle: float = deg_to_rad(turn_angle_degrees) * direction
	var rotation_difference := Transform3D.IDENTITY.rotated(%Camera.transform.basis.x, angle)
	%Origin.transform = rotation_difference * %Origin.transform
	set_physics_pivot_point()
	set_controller_pivot_point()
	# When rotating around a point, origin needs to be moved to proper position after rotation
	%Origin.global_translate(physics_pivot_point.origin - controller_pivot_point.origin)

	for hand in [%PhysicsHandLeft, %PhysicsHandRight]:
		if !hand.held_object:
			hand.reset_hand()


func _on_physics_hand_grabbed(held_object: Node3D) -> void:
	set_physics_pivot_point()
	# If both hands are holding the same object, override its center of mass to blended physics_pivot_point which is between hands physics_pivot_points
	if %PhysicsHandLeft.held_object == %PhysicsHandRight.held_object and held_object.is_class("RigidBody3D") :
		var center_of_mass: Vector3 = physics_pivot_point.origin - held_object.global_transform.origin
		held_object.set_center_of_mass_mode(1) # Enable custom center of mass
		held_object.set_center_of_mass(center_of_mass)


func _on_hand_reset(hand: Node3D) -> void:
	set_physics_pivot_point()


func _on_hand_dropped_held_object(held_object: Node3D) -> void:
	set_physics_pivot_point()


func _on_thruster(value):
	thruster = value

func _on_thruster_brake(value):
	thruster_brake = value

