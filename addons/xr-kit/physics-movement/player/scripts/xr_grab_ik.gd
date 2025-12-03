@tool

class_name XRGrabIK
extends SkeletonModifier3D

@export_enum("Left", "Right") var hand: String = "Left"
@export var preview_in_editor: bool = true

var skeleton: Skeleton3D
var grabbing: bool = false


func _ready() -> void:
	skeleton = get_skeleton()


func _validate_property(property: Dictionary) -> void:
	# Get list of bone names from skeleton
	if property.name == "hand_bone" or property.name == "palm_bone":
		if skeleton:
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = skeleton.get_concatenated_bone_names()


func _process_modification() -> void:
	if Engine.is_editor_hint() and !preview_in_editor:
		return

	if !skeleton or !grabbing:
		return

	for finger in ["Thumb", "Index", "Middle", "Ring", "Little"]:
		var touch_bone_index: int = skeleton.find_bone(hand + finger + "Touch")
		var raycast: RayCast3D = skeleton.get_node_or_null(hand  + "Hand/" + finger + "IKRayCast")
		var skeleton_ik: SkeletonIK3D = skeleton.get_node_or_null(finger + "IK")
		var ik_target_node: Node3D = skeleton.get_node_or_null(finger + "IKTarget")

		if !raycast or !skeleton_ik or !ik_target_node or touch_bone_index == -1:
			continue
		
		raycast.force_raycast_update()
		if !raycast.is_colliding():
			continue

		# Reset bones to rest pose, so IK can work from default state
		# TODO: Implement FABRIK or CCDIK with constraints in _process_modification() instead of using SkeletonIK3D with rest poses
		skeleton.reset_bone_pose(skeleton.find_bone(hand + finger + "Proximal"))
		skeleton.reset_bone_pose(skeleton.find_bone(hand + finger + "Intermediate"))
		skeleton.reset_bone_pose(skeleton.find_bone(hand + finger + "Distal"))
		
		ik_target_node.global_transform.origin = raycast.get_collision_point()
		# Distal bone rotation is the same as previous (Intermediate) bone rotation
		# TODO: Find out how to rotate distal bone to match raycast collision normal and look natural
		ik_target_node.global_transform.basis = (skeleton.global_transform * skeleton.get_bone_global_pose(touch_bone_index -2)).basis
		# Further rotate Distal bone 20 degrees downwards to make it look more natural
		# TODO: Godot's SkeletonIK3D implementation of FABRIK does not support contraints, so bones can rotate in unnatural ways (impossible angles), ex. intermediate bone points upwards from proximal. Because of this, 20 degrees distal rotation and rotations of previous bones sometimes bend finger in "zig-zag", which cannot be fixed any other way than implementing IK with constraints (add constraints to FABRIK or use different IK system, such as CCDIK).
		ik_target_node.global_transform.basis = ik_target_node.global_transform.basis.rotated(ik_target_node.global_transform.basis.x, deg_to_rad(-20))

		skeleton_ik.start()
		


func _on_physics_hand_grabbed(_object: Node3D, _collision_normal: Vector3) -> void:
	grabbing = true
	# Enable SkeletonIK nodes
	for finger in ["Thumb", "Index", "Middle", "Ring", "Little"]:
		var skeleton_ik: SkeletonIK3D = skeleton.get_node_or_null(finger + "IK")
		if skeleton_ik:
			skeleton_ik.active = true
		
		
func _on_physics_hand_dropped_held_object(_object: Node3D) -> void:
	grabbing = false
	# Disable SkeletonIK nodes
	for finger in ["Thumb", "Index", "Middle", "Ring", "Little"]:
		var skeleton_ik: SkeletonIK3D = skeleton.get_node_or_null(finger + "IK")
		if skeleton_ik:
			skeleton_ik.active = false
