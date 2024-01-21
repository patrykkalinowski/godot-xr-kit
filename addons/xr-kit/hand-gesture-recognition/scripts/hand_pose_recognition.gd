extends Node

signal new_pose(previous_pose: StringName, pose: StringName)

@export var camera: XRCamera3D
@export var skeleton: Skeleton3D
@export var debug_label: Label3D

var templates: Dictionary
var pose: StringName

func _ready() -> void:
	templates = load_templates()


func recognize_pose() -> StringName:
	var best_match_key: StringName
	var best_match_angle: float = INF

	for key in templates.keys():
		var total_angle := 0.0

		for bone_id in skeleton.get_bone_count():
			if bone_id == 0:
				var angle: float = skeleton.global_transform.basis.get_rotation_quaternion().angle_to(camera.global_transform.basis.get_rotation_quaternion())

				continue

			var angle: float = skeleton.get_bone_global_pose(bone_id).basis.get_rotation_quaternion().angle_to(skeleton.get_bone_global_pose(0).basis.get_rotation_quaternion())
			var template_angle: float = templates[key][String.num_int64(bone_id)]
			total_angle += abs(angle - template_angle)

			# if current template is already worse than best match, we can move to the next one right away
			if total_angle > best_match_angle:
				break

		if total_angle < best_match_angle and total_angle <= 3.0:
			best_match_key = key
			best_match_angle = total_angle

	if debug_label:
		debug_label.text = best_match_key

	return best_match_key

func load_templates():
		var file := FileAccess.open("res://addons/xr-kit/hand-gesture-recognition/hand_pose_templates.json", FileAccess.READ)
		if file:
			# TODO: catch error when json is incorrect
			return JSON.parse_string(file.get_as_text())
		else:
			return {}


func _on_timer_timeout():
	var recognized_pose: StringName = recognize_pose()
	if recognized_pose != pose:
		new_pose.emit(pose, recognized_pose)
		pose = recognized_pose
