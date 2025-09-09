@tool

class_name XRHandIK
extends SkeletonModifier3D

@export_enum("Left", "Right") var hand: String = "Left"
@export var physics_hand: RigidBody3D
@export_enum(" ") var palm_bone: String
@export var preview_in_editor: bool = true

var skeleton: Skeleton3D
var palm_pose_node: Node3D
var palm_bone_id: int
var grabbing: bool = false
var hold_rotation: Basis


func _validate_property(property: Dictionary) -> void:
	# Get list of bone names from skeleton
	if property.name == "hand_bone" or property.name == "palm_bone":
		skeleton = get_skeleton()
		if skeleton:
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = skeleton.get_concatenated_bone_names()


func _ready() -> void:
	skeleton = get_skeleton()
	palm_pose_node = skeleton.get_node(hand + "Hand/PalmPose")
	palm_bone_id = skeleton.find_bone(palm_bone)


func _process_modification() -> void:
	if Engine.is_editor_hint() and !preview_in_editor:
		return
	if !skeleton or !physics_hand or !palm_bone:
		return

	# Do not change the logic here - skeleton should always follow physics hand and this is implied when physics hand places finger colliders	
	skeleton.global_transform = physics_hand.global_transform

	if physics_hand.is_controller_tracking:
		if palm_pose_node:
			# Move skeleton so controller's palm_pose matches skeleton's palm_pose
			
			skeleton.set_bone_pose(0, palm_pose_node.transform.inverse())
	else:
		# For hand tracking - palm bone matches physics hand
		skeleton.set_bone_pose(0, skeleton.get_bone_global_pose(palm_bone_id).inverse())
