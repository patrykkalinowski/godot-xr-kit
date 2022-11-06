extends RigidBody

export (NodePath) var origin # ARVROrigin node
export (NodePath) var camera # ARVRCamera node
export (int) var turn_angle_degrees = 30 # angle to rotate player body with controller

var moves = []
var holding_hand
var holding_hand_wrist
var holding_hand_held_object
var holding_hand_controller_skeleton
var holding_hand_hold_position
var trigger

func _ready():
	camera = get_node(camera)

func _physics_process(delta):
	if holding_hand:
		# when holding, body follows physical hand
		var distance_wrist = (holding_hand_controller_skeleton.global_transform * holding_hand_controller_skeleton.get_bone_global_pose(0)).origin - holding_hand_wrist.global_transform.origin
		
		# higher linear damp eliminates wobbling
		set_linear_damp(10)
		
		# if held object is lighter than player body, reduce force applied to body movement according to held object's mass
		# for example, if held object is 40kg (half of body mass), body receives only half of usual movement force
		# that way, moving light objects around won't push player body away in zero gravity
		var body_move_mass
		if holding_hand_held_object.get_class() == "RigidBody":
#			# clamp is used to make sure holding heavier object won't increase movement force to crazy levels
			body_move_mass = clamp(holding_hand_held_object.get_mass() / get_mass(), 0, get_mass())
		else:
			# only RigidBody has its own mass; if we hold to StaticBody, we assume it has maximum mass available for movement
			body_move_mass = get_mass()
		
		# if physical hand is not moving (object is blocked by something), increase force so body can be pulled closer to hand, even if object is light
		# 'get_linear_velocity' doesn't work here because we reset it every frame in PhysicalHand script, so it stays at 0
		# if distance_wrist is high, it means hand is probably stuck and we need to move body to it with greater force (modifier)
		# KNOWN ISSUE: modifier doesn't work well with very heavy floating objects, it causes rubberbanding
		var modifier = clamp(20 * distance_wrist.length_squared(), 1, 2)
		
		# trigger while holding forces player body to stand still, so we don't apply forces on body
		# but if held object is static, we always move player body
		if !trigger || acts_as_static(holding_hand_held_object):
			# move player body in opposite way of hand pushing force
			var hold_target_bone_global_transform_origin = (holding_hand_controller_skeleton.global_transform * holding_hand_controller_skeleton.get_bone_global_pose(0)).origin - holding_hand_hold_position.origin
			move((body_move_mass * -hold_target_bone_global_transform_origin * modifier) / delta)
	
	var sum = Vector3.ZERO
	for vector in moves:
		sum += vector
	
	add_central_force(sum)
	
	moves.clear()

# we don't move directly, but rather gather requests from other nodes and apply them in this script
func move(vector):
	moves.append(vector)

# when player grabs something, receive details about it
func _on_PhysicalHand_hold(physical_hand, wrist, controller_skeleton, held_object, hand_hold_position):
	holding_hand = physical_hand
	holding_hand_wrist = wrist
	holding_hand_held_object = held_object
	holding_hand_controller_skeleton = controller_skeleton
	holding_hand_hold_position = hand_hold_position

func _on_PhysicalHand_reset_hand(physical_hand):
	if holding_hand == physical_hand:
		holding_hand = null
		holding_hand_wrist = null

func _on_ARVRController_turn(direction):
	print("received turn signal")
	var t1 = Transform()
	var t2 = Transform()
	var rot = Transform()
		
	if holding_hand && acts_as_static(holding_hand.held_object):
		# if holding, we rotate around wrist holding the object
		# object must be Static or behaving like Static
		t1.origin = holding_hand.held_object_anchor.global_transform.origin
		t2.origin = -holding_hand.held_object_anchor.global_transform.origin
	else:
		# otherwise, we do rotation around camera
		t1.origin = camera.transform.origin
		t2.origin = -camera.transform.origin
	
	# rotation angle is 30 degrees
	var angle = deg2rad(turn_angle_degrees) * direction
	rot = rot.rotated(Vector3.UP, angle)

	# rotate origin (player world)
	origin.global_transform *= t1 * rot * t2

func acts_as_static(object):
	return (object.is_class("StaticBody") || (object.is_class("RigidBody") && object.get_mode() in [1, 2, 3]))
