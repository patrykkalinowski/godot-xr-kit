extends Node3D

@export var skeleton_L: Skeleton3D
@export var skeleton_R: Skeleton3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var animation_player = get_node("Root Scene/AnimationPlayer")
	var animation = animation_player.get_animation("Take 001")
	var animation_new = Animation.new()

	# which track applies to which bone_id
	# one bone has position and rotation track, tips only have rotation
	var tracks_to_bones = {
			0: 0,
			1: 1,
			2: 1,
			3: 2,
			4: 2,
			5: 3,
			6: 3,
			7: 4,
			8: 5,
			9: 5,
			10: 6,
			11: 6,
			12: 7,
			13: 7,
			14: 8,
			15: 8,
			16: 9,
			17: 10,
			18: 10,
			19: 11,
			20: 11,
			21: 12,
			22: 12,
			23: 13,
			24: 13,
			25: 14,
			26: 15,
			27: 15,
			28: 16,
			29: 16,
			30: 17,
			31: 17,
			32: 18,
			33: 18,
			34: 19,
			35: 20,
			36: 20,
			37: 21,
			38: 21,
			39: 22,
			40: 22,
			41: 23,
			42: 23,
			43: 24
		}

	for skeleton in [skeleton_L, skeleton_R]:
		for track_index in range(0, 43):
			var track_index_new = animation_new.add_track(animation.track_get_type(track_index))


			if track_index <= tracks_to_bones.size() - 1:
				var bone_name = skeleton.get_bone_name(tracks_to_bones[track_index])
				animation_new.track_set_path(track_index_new, ":" + bone_name)

				# disable metacarpal bones, for some reason convertion messes them up
				# TODO: fix this
				if bone_name.contains("Metacarpal"):
					animation_new.track_set_enabled(track_index_new, false)

			for key_index in animation.track_get_key_count(track_index):
				var value_new
				var time = animation.track_get_key_time(track_index, key_index)
				var value = animation.track_get_key_value(track_index, key_index)
				if animation.track_get_type(track_index) == 2: # ROTATION_3D
					# take original rotation Quaternion, convert to euler, swap x and z, convert back to Quaternion
					var euler = value.get_euler()
					var euler_new = Vector3(-euler.z, euler.y, euler.x)
					value_new = Quaternion.from_euler(euler_new)
					animation_new.rotation_track_insert_key(track_index_new, time, value_new)



	var result = ResourceSaver.save(animation_new, "res://addons/xr-kit/physics-movement/utilities/converted_animation.tres")
	if result == OK:
			print("Converted animation saved successfully")
	else:
			print("Failed to save converted animation")
