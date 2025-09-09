extends Skeleton3D

var poses: Dictionary

func _on_skeleton_updated() -> void:
	# When all SkeletonModifier3Ds finish processing, update dictionary with final bone poses
	# This is used by physics hand to update collider positions
	for bone_id in get_bone_count():
		poses[bone_id] = get_bone_global_pose(bone_id)
		# Store by bone names, too
		poses[get_bone_name(bone_id)] = get_bone_global_pose(bone_id)
