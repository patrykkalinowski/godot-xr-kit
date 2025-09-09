# Add inverse kinematics micro movement to fingers when hand is being moved
# Makes the hand feel a little less stiff and more natural
# TODO: Move nodes setup to _ready() and only update target transform here
# TODO: Rotational force should also be taken into account
# TODO: Fingers should react when hand is pushing on an object
	
@tool

class_name XRFingersMicromovementIK
extends SkeletonModifier3D

@export_enum("Left", "Right") var hand: String = "Left"
@export var physics_hand: RigidBody3D
@export var strength: float = 1.0
@export var preview_in_editor: bool = true

var skeleton: Skeleton3D

func _ready() -> void:
	skeleton = get_skeleton()

func _process_modification() -> void:
	if Engine.is_editor_hint() and !preview_in_editor:
		return

	if !skeleton:
		return

	var velocity: Vector3 = physics_hand.linear_velocity

	for finger in ["Thumb", "Index", "Middle", "Ring", "Little"]:
		# Rotate only proximal bones
		var bone_id: int = skeleton.find_bone(hand + finger + "Proximal")

		# TODO: Rotate bone away from the direction of hand movement
		#skeleton.set_bone_pose(bone_id, skeleton.get_bone_pose(bone_id) + velocity * strength)


# Original function:
func finger_micromovement(linear_velocity) -> void:
	
	var ik_nodes: Array[Node] = skeleton.get_children().filter(func(node): return node is SkeletonIK3D)
	# Set target transform for every IK node (finger) in physics hand
	for ik_node in ik_nodes:
		# IK target vector is taken from physics hand velocity, flipped and greatly reduced
		var target_vector: Vector3 = -linear_velocity.limit_length(100) / 100000
		var tip_bone_index: int = skeleton.find_bone(ik_node.get_tip_bone())
		var tip_bone_pose: Transform3D = skeleton.get_bone_global_pose_no_override(tip_bone_index)

		ik_node.set_target_transform(skeleton.global_transform * tip_bone_pose.translated(target_vector))
		ik_node.start()