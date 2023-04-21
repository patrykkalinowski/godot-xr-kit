extends CharacterBody3D

@export var origin: XROrigin3D # ARVROrigin node
@export var camera: XRCamera3D # ARVRCamera node
@export var turn_angle_degrees: int = 30 # angle to rotate player body with controller

@export var physical_hand_left: Node3D
@export var physical_hand_right: Node3D

@export var body_mass: int = 80

var physical_pivot_point: Transform3D = Transform3D.IDENTITY
var controller_pivot_point: Transform3D = Transform3D.IDENTITY
var physical_transforms: Array = []
var controller_transforms: Array = []
var mass_modifiers: Array = []
var blended_mass_modifier: float = 1

func _ready():
	pass

func _process(delta):
	physical_pivot_point = Transform3D.IDENTITY
	controller_pivot_point = Transform3D.IDENTITY
	physical_transforms = []
	controller_transforms = []
	mass_modifiers = []
	blended_mass_modifier = 1

	for hand in [physical_hand_left, physical_hand_right]:
		if !hand.state.holding:
			pass
		elif hand.state.holding:
			# physical_pivot_point is a point in space where physical hand is connected to held object
			physical_pivot_point = hand.held_object_anchor.global_transform
			physical_transforms.append(physical_pivot_point)
			
			var controller_anchor_point_from_wrist = hand.held_object_anchor.global_transform.origin - hand.wrist.global_transform.origin

			# controller_pivot_point is a point in space following controller
			controller_pivot_point = (hand.controller_skeleton.global_transform * hand.controller_skeleton.get_bone_global_pose(0)).translated(controller_anchor_point_from_wrist)
			controller_transforms.append(controller_pivot_point)
			
			# if held object is lighter than player body, 
			# reduce force applied to body movement according to held object's mass
			# for example, if held object is 40kg (half of body mass), body receives only half of usual movement force
			# that way, moving light objects around won't push player body away in zero gravity
			var mass_modifier = 1
			if hand.held_object.get_class() == "RigidBody3D":
	#			# clamp is used to make sure holding heavier object 
				# won't increase movement force to crazy levels
				var mass_ratio = hand.held_object.get_mass() / body_mass
				mass_modifier = clamp(mass_ratio, 0, 1.0) / 50.0
#
			mass_modifiers.append(mass_modifier)
	
	if physical_transforms.size() > 0:
		# when holding an object, we stop the body and it is now moved only by hands
		# TODO: preserve momentum so player body doesn't stop abruptly 
		set_velocity(Vector3.ZERO)
		
		# calculate pivot points
		# take every transform from array, extract origin, and sum origins
		physical_pivot_point.origin = physical_transforms.map(func(transform): return transform.origin).reduce(func(vector_sum, vector): return vector_sum + vector)
		
		# if two hands, divide resulting sum of origins by 2, so pivot point is between them
		physical_pivot_point.origin /= physical_transforms.size()
		
		if physical_transforms.size() == 2:
			physical_pivot_point = physical_pivot_point.looking_at(physical_transforms[1].origin, Vector3.UP)
		else:
			physical_pivot_point.basis = physical_transforms[0].basis
		
		controller_pivot_point.origin = controller_transforms.map(func(transform): return transform.origin).reduce(func(vector_sum, vector): return vector_sum + vector)
		
		controller_pivot_point.origin /= controller_transforms.size()
		
		if controller_transforms.size() == 2:
			controller_pivot_point = controller_pivot_point.looking_at(controller_transforms[1].origin, Vector3.UP)
		else:
			controller_pivot_point.basis = controller_transforms[0].basis
		
		# rotate body when holding static body with 2 hands
		# TODO: rotating when holding rigidbody is incorrect and nauseating, how to do it nicely?
		if controller_transforms.size() == 2 && acts_as_static(physical_hand_left.held_object) && acts_as_static(physical_hand_right.held_object):
			var rotation_difference: Transform3D = physical_pivot_point * controller_pivot_point.inverse()
			
			origin.global_transform = (rotation_difference * origin.global_transform).orthonormalized() # rotation_difference before original transform - order matters!
			
			return

		# if player is holding two different objects with different mass, body movement is based on heavier object	
		# TODO: mass modifier should be separate for every hand
		# TODO: if trigger is pressed, this hand should not cause body movement
		blended_mass_modifier = mass_modifiers.max()
		
		var move_vector = (physical_pivot_point.origin - controller_pivot_point.origin) / delta

		velocity += move_vector * blended_mass_modifier

	if physical_transforms.size() == 0:
		# if player is floating in space, limit maximum velocity to 1 and reduce it by 5% every second
		velocity = velocity.limit_length(1)
		velocity *= 1 - (0.05 * delta)
		
	move_and_slide() # move body by calculated velocity

func _on_turn(direction, controller):
	# turn signal received from controller
	var t1 = Transform3D()
	var t2 = Transform3D()
	var rot = Transform3D()
	
	# if both hands are holding static object, disable snap turn
	if physical_hand_left.state.holding && acts_as_static(physical_hand_left.held_object) && physical_hand_right.state.holding && acts_as_static(physical_hand_right.held_object):
		return
	else:
		# if only one hand is holding
		for hand in [physical_hand_left, physical_hand_right]:
			# if signal is received from controller of this physical hand
			# we pivot around this hand anchor
			if hand.controller == controller:
				if hand.state.holding && acts_as_static(hand.held_object):
					# if holding, we rotate around this hand controller_pivot_point holding the object
					# object must be Static or behaving like Static
					t1.origin = controller_pivot_point.origin
					t2.origin = -controller_pivot_point.origin
				else:
					# otherwise, we do rotation around camera
					# TODO: if other hand is holding, player should be rotated around the other hand's pivot point even when turn signal is coming from hand which is not holding
					t1.origin = camera.transform.origin
					t2.origin = -camera.transform.origin
					
	var angle = deg_to_rad(turn_angle_degrees) * direction
	rot = rot.rotated(Vector3.UP, angle)

	# rotate origin (player world)
	origin.global_transform *= t1 * rot * t2
	
	for hand in [physical_hand_left, physical_hand_right]:
		if !hand.state.holding:
			hand.reset_hand_position()

func acts_as_static(object):
	return (object.is_class("StaticBody3D") || (object.is_class("RigidBody3D") && object.is_freeze_enabled() && object.get_freeze_mode() == 0))
