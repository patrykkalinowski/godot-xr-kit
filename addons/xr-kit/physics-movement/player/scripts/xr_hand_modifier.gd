extends XRHandModifier3D

@export_enum("Left", "Right") var hand: String = "Left"

var poses: Dictionary
var skeleton: Skeleton3D
var bone_ids: Array[int]
var bones: Array[String]


func _ready() -> void:
	skeleton = get_skeleton()
	poses = {}
	bones = [
		"Hand",
		"Palm",
		"ThumbMetacarpal",
		"ThumbProximal",
		"ThumbDistal",
		"IndexMetacarpal",
		"IndexProximal",
		"IndexIntermediate",
		"IndexDistal",
		"MiddleMetacarpal",
		"MiddleProximal",
		"MiddleIntermediate",
		"MiddleDistal",
		"RingMetacarpal",
		"RingProximal",
		"RingIntermediate",
		"RingDistal",
		"LittleMetacarpal",
		"LittleProximal",
		"LittleIntermediate",
		"LittleDistal"
	]
	# Get bone ids for every bone in hand
	for bone in bones:
		bone_ids.append(skeleton.find_bone(hand + bone))

	## Blender import with meshes parented to bones creates additional bones in Skeleton3D named after meshes (https://github.com/godotengine/godot/issues/75917). These extra bones are parented to original bones, so we need to find them and add to list of bones to process
	#for bone_id in bone_ids:
		#bone_ids.append_array(skeleton.get_bone_children(bone_id))

	
func _on_modification_processed() -> void:
	# Every time XRHandModifier updates skeleton, we update poses dictionary
	for bone_id in bone_ids:
		poses[bone_id] = skeleton.get_bone_global_pose(bone_id)
		# Store by bone names, too
		poses[skeleton.get_bone_name(bone_id)] = skeleton.get_bone_global_pose(bone_id)
