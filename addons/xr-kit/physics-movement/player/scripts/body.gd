extends CharacterBody3D

@export var turn_angle_degrees: int = 30 # Angle to rotate player body using controller joystick
@export var body_mass: int = 80

var xr_enabled: bool
var physics_pivot_point := Transform3D.IDENTITY
var controller_pivot_point := Transform3D.IDENTITY
var held_objects_count: int = 0
var thruster := Vector2(0,0)
var thruster_brake := false
var rotated_transform_x := Transform3D.IDENTITY
var player_rotating_x_angle := 0.0
var free_rotation_initial_difference := Transform3D.IDENTITY
var thruster_velocity := Vector3.ZERO

func _ready() -> void:
	if XRServer.primary_interface:
		xr_enabled = true
	else:
		xr_enabled = false


func _physics_process(delta) -> void:

	if xr_enabled:
		# Body collider shapes follow their nodes
		%HeadCollider.global_transform = %XRCamera.global_transform

		# Rotate player body with controller joystick
		if player_rotating_x_angle and !(%PhysicsHandLeft.controller.free_rotation or %PhysicsHandRight.controller.free_rotation):
			var rotation_difference := Transform3D.IDENTITY.rotated(Vector3.UP, player_rotating_x_angle)
			if controller_pivot_point == Transform3D.IDENTITY:
				# Player is not holding anything, rotate Origin around camera
				var t1 := Transform3D()
				var t2 := Transform3D()
				t1.origin = %XRCamera.transform.origin
				t2.origin = -%XRCamera.transform.origin
				%XROrigin.transform = %XROrigin.transform * t1 * rotation_difference * t2
			else:
				# Player is holding an object, rotate Origin around controller_pivot_point
				# Find target transform by moving Origin to controller_pivot_point, rotating it, then moving it back
				var t1 := Transform3D()
				var t2 := Transform3D()

				t1.origin = controller_pivot_point.origin + %XRCamera.transform.origin
				t2.origin = -(controller_pivot_point.origin + %XRCamera.transform.origin)
				var target_transform: Transform3D = %XROrigin.global_transform * t1 * rotation_difference * t2

				rotate_origin_around_controller(target_transform, true)



			for hand in [%PhysicsHandLeft, %PhysicsHandRight]:
				if !hand.held_object:
					hand.reset_hand()

			player_rotating_x_angle = 0.0

	set_physics_pivot_point()
	set_controller_pivot_point()

	# MOMENTUM
	var momentum := velocity
	if held_objects_count == 0:
		# If player is floating in space, keep reducing maximum velocity until it reaches 1 (reduce more the faster current velocity), then reduce it further by 5% every second
		momentum = velocity.limit_length(maxf(1.0, velocity.length() - ((velocity.length() - sqrt(velocity.length())) * delta)))
		momentum *= 1 - (0.05 * delta)

		free_rotation_initial_difference = Transform3D.IDENTITY

	if thruster_brake:
		momentum *= 1 - (2 * delta)

	# Apply thruster input and keyboard rotation
	thruster_velocity = Vector3.ZERO
	if xr_enabled:
		thruster_velocity += -%XRCamera.global_transform.basis.z.normalized() * delta * thruster.y / 10
		thruster_velocity += %XRCamera.global_transform.basis.x.normalized() * delta * thruster.x / 10
	else:
		thruster_velocity = apply_thruster_input(delta)

		# Rotate player body with keyboard
		# TODO: rotate with lerp and little lag after button is released
		if Input.is_action_pressed("rotate_left"):
			rotate(%Camera.global_transform.basis.z, delta / 3)

		if Input.is_action_pressed("rotate_right"):
			rotate(%Camera.global_transform.basis.z, -delta / 3)
	
	# PUSHBACK VELOCITY
	# Enable pushing away using hands (aka Gorilla Tag movement)
	var pushback_velocity: Vector3 = Vector3.ZERO
	for hand in [%PhysicsHandLeft, %PhysicsHandRight]:
		if xr_enabled:
			var pushback_vector: Vector3 = hand.global_transform.origin - hand.tracker.global_transform.origin
			
			if acts_as_static(hand.held_object):
				# If hand is holding StaticBody, override pivot_points so body movement
					# is not influenced by RigidBody held by the other hand
				set_physics_pivot_point(hand)
				set_controller_pivot_point(hand)
				# Different vector for static objects
				pushback_vector = physics_pivot_point.origin - controller_pivot_point.origin

			# If hand is not holding anything, apply pushback vector to player body only if it's pushing player away, not pulling towards object and make sure player is not pushing away using their own body as objects
			# TODO: Disable pushing away from object held by other hand
			if (!hand.held_object and pushback_vector.dot(hand.collision_normal) >= 0 and hand.get_colliding_bodies().size() > 0 and hand.get_colliding_bodies()[0] not in [self, %PhysicsHandLeft, %PhysicsHandRight]) or hand.held_object:
				# Get real-life hand velocity from OpenXR tracker
				var controller_velocity: Vector3 = hand.tracker.get_pose().get_linear_velocity() if hand.tracker.get_pose() is XRPose else Vector3.ZERO

				# Pushback is based on how fast controller is moving, distance between controller and physics hand, and the inverse of physics hand velocity
					# If physics hand is moving fast, pushback is reduced (light object which does not reduce its speed, so body should not be affected)
					# Lower velocity of physics hand means either object is heavy or not moving at at all, so pushback is increased
				if acts_as_static(hand.held_object):
					# If holding StaticBody, we cancel out momentum and apply simplified, stronger velocity
					momentum = Vector3.ZERO
					pushback_velocity +=  (pushback_vector * (0.01 / hand.get_linear_velocity().limit_length(0.001).length())).limit_length(1)
				else:
					pushback_velocity += (pushback_vector.limit_length(0.3) * controller_velocity.length() * delta * (0.01 / hand.get_linear_velocity().limit_length(0.001).length())).limit_length(0.1)

	if held_objects_count > 0:
		if xr_enabled:
			# Body XYZ rotation activated by trigger
			if %XRControllerLeft.free_rotation or %XRControllerRight.free_rotation:
				# If only one hand is holding static object, force rotation around that hand
				if acts_as_static(%PhysicsHandLeft.held_object) and %PhysicsHandRight.held_object and !acts_as_static(%PhysicsHandRight.held_object):
					set_controller_pivot_point(%PhysicsHandLeft)
					set_physics_pivot_point(%PhysicsHandLeft)
					%XRControllerRight.free_rotation = false

				if acts_as_static(%PhysicsHandRight.held_object) and %PhysicsHandLeft.held_object and !acts_as_static(%PhysicsHandLeft.held_object):
					set_controller_pivot_point(%PhysicsHandRight)
					set_physics_pivot_point(%PhysicsHandRight)
					%XRControllerLeft.free_rotation = false

				# When free rotation is activated, we modify rotation_difference so player body stays in place instead of rotating within one frame for physics_pivot_point to reach controller_pivot_point. In a way, we set controller_pivot_point at the same place as physics_pivot_point
				if free_rotation_initial_difference == Transform3D.IDENTITY:
					free_rotation_initial_difference = physics_pivot_point * controller_pivot_point.inverse()

				var pivot_difference: Transform3D = free_rotation_initial_difference.inverse() * physics_pivot_point * controller_pivot_point.inverse()
				var target_transform: Transform3D = pivot_difference * %XROrigin.global_transform # Rotation_difference before original transform - order matters!
				rotate_origin_around_controller(target_transform)
				return
			else:
				# If free rotation is deactivated for both hands, reset rotation_difference
				free_rotation_initial_difference = Transform3D.IDENTITY


	velocity = momentum + thruster_velocity + pushback_velocity

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
			# Due to controller being in PalmPose, it's moved and rotated relative to target node, that's why we need to inverse transform here
			controller_pivot_point = hand.tracker.global_transform
			controller_transforms.append(controller_pivot_point)

	if controller_transforms.size() > 0:
		controller_pivot_point.origin = controller_transforms.map(func(controller_transform): return controller_transform.origin).reduce(func(vector_sum, vector): return vector_sum + vector)
		controller_pivot_point.origin /= controller_transforms.size()

	if controller_transforms.size() == 2:
		controller_pivot_point = controller_pivot_point.looking_at(controller_transforms[1].origin, Vector3.UP)
	elif controller_transforms.size() == 1:
		controller_pivot_point.basis = controller_transforms[0].basis
	else:
		controller_pivot_point = Transform3D.IDENTITY

	# Experimental body movement when holding an object (held object mass works in opposite way - lighter object means less movement, heavier object means more movement - TODO: how to fix?)
	controller_pivot_point = controller_pivot_point.translated(-thruster_velocity * 100)

	%ControllerPivotPoint.global_transform = controller_pivot_point


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
		physics_pivot_point.origin = physics_transforms.map(func(physics_transform): return physics_transform.origin).reduce(func(vector_sum, vector): return vector_sum + vector)
		# If two hands, divide resulting sum of origins by 2, so pivot point is between them
		physics_pivot_point.origin /= physics_transforms.size()

	if physics_transforms.size() == 2:
		physics_pivot_point = physics_pivot_point.looking_at(physics_transforms[1].origin, Vector3.UP)
	elif physics_transforms.size() == 1:
		physics_pivot_point.basis = physics_transforms[0].basis
	else:
		physics_pivot_point = Transform3D.IDENTITY

	held_objects_count = physics_transforms.size()

	%PhysicsPivotPoint.global_transform = physics_pivot_point


func rotate_origin_around_controller(target_transform: Transform3D, horizontal_axis_only: bool = false) -> void:
	# Move origin to target position, but it will stop at collision
	# TODO: Put move_and_collide() vector through 1Euro filter to smooth out controller jitter
	var collision: KinematicCollision3D = move_and_collide(target_transform.origin - %XROrigin.global_transform.origin)
	# TODO: apply impulses to RigidBodies player body collided with (in separate function to be used also for normal grab state)
	# Origin is now moved, but not rotated and pivot points have diverged. Calculate how much origin should rotate so pivot points will be aligned again
	if horizontal_axis_only:
		# TODO: Calculated horizontal rotation is incorrect, needs to be fixed
		var t1 := Transform3D()
		var t2 := Transform3D()
		t1.origin = %XRCamera.transform.origin
		t2.origin = -%XRCamera.transform.origin

		# Recalculate pivot points after moving Origin
		set_controller_pivot_point()
		set_physics_pivot_point()

		# Calculate rotation only on Origin's horizontal axis
		var flat_controller_pivot_point = controller_pivot_point
		flat_controller_pivot_point.origin.y = %XRCamera.global_transform.origin.y
		var flat_physics_pivot_point = physics_pivot_point
		flat_physics_pivot_point.origin.y = %XRCamera.global_transform.origin.y
		var looking_at_controller_pivot_point: Transform3D = %XRCamera.global_transform.looking_at(flat_controller_pivot_point.origin, Vector3.UP)
		var looking_at_physics_pivot_point: Transform3D = %XRCamera.global_transform.looking_at(flat_physics_pivot_point.origin, Vector3.UP)
		var transform_to_rotate := Transform3D()
		transform_to_rotate.basis = looking_at_physics_pivot_point.basis * looking_at_controller_pivot_point.basis.inverse()

		%XROrigin.transform = %XROrigin.transform * t1 * transform_to_rotate * t2
		# After rotation, Origin is still offset from final position, we recalculate pivot points and move Origin so pivot points are aligned
		set_controller_pivot_point()
		set_physics_pivot_point()
		%XROrigin.transform = %XROrigin.transform.translated(physics_pivot_point.origin - controller_pivot_point.origin)
	else:
		var looking_at_controller_pivot_point: Transform3D = %XROrigin.global_transform.looking_at(controller_pivot_point.origin, controller_pivot_point.basis.y)
		var looking_at_physics_pivot_point: Transform3D = %XROrigin.global_transform.looking_at(physics_pivot_point.origin, physics_pivot_point.basis.y)
		var transform_to_rotate: Transform3D = looking_at_physics_pivot_point * looking_at_controller_pivot_point.inverse()

		%XROrigin.global_transform = transform_to_rotate * %XROrigin.global_transform

func apply_thruster_input(delta: float) -> Vector3:
	thruster_velocity = Vector3.ZERO

	if Input.is_action_pressed("move_forward"):
		thruster_velocity -= %Camera.global_transform.basis.z.normalized() * delta / 10
		
	if Input.is_action_pressed("move_backward"):
		thruster_velocity += %Camera.global_transform.basis.z.normalized() * delta / 10
		
	if Input.is_action_pressed("move_left"):
		thruster_velocity -= %Camera.global_transform.basis.x.normalized() * delta / 10
	
	if Input.is_action_pressed("move_right"):
		thruster_velocity += %Camera.global_transform.basis.x.normalized() * delta / 10
		
	if Input.is_action_pressed("move_up"):
		thruster_velocity += %Camera.global_transform.basis.y.normalized() * delta / 10
		
	if Input.is_action_pressed("move_down"):
		thruster_velocity -= %Camera.global_transform.basis.y.normalized() * delta / 10

	return thruster_velocity

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
	var rotation_difference := Transform3D.IDENTITY.rotated(%XRCamera.transform.basis.x, angle)
	%XROrigin.transform = rotation_difference * %XROrigin.transform
	set_physics_pivot_point()
	set_controller_pivot_point()
	# When rotating around a point, origin needs to be moved to proper position after rotation
	%XROrigin.global_translate(physics_pivot_point.origin - controller_pivot_point.origin)

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


func _on_physics_hand_reset(hand: Node3D) -> void:
	set_physics_pivot_point()


func _on_physics_hand_dropped_held_object(held_object: Node3D) -> void:
	set_physics_pivot_point()


func _on_thruster(value):
	thruster = value

func _on_thruster_brake(value):
	thruster_brake = value
