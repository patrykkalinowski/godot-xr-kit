extends Node

@export var skeleton: Skeleton3D
@export var debug_label: Label3D

var templates: Dictionary
var pose: String

signal new_pose(pose: String, previouse_pose: String)

func _ready():
	templates = load_templates()
	
func recognize_pose():
	var best_match_key: String
	var best_match_distance: float = INF
	
	for key in templates.keys():
		var total_distance: float = 0
		
		for bone_id in skeleton.get_bone_count():
			var distance: float = skeleton.get_bone_global_pose(bone_id).origin.distance_to(skeleton.get_bone_global_pose(0).origin)
			var template_distance: float = templates[key][String.num_int64(bone_id)]			
			total_distance += abs(distance - template_distance)
			
			# if current template is already worse than best match, we can move to the next one right away
			if total_distance > best_match_distance:
				break
				
		if total_distance < best_match_distance:
			best_match_key = key
			best_match_distance = total_distance

	if debug_label:
		debug_label.text = best_match_key
	return best_match_key

func load_templates():
		var file = FileAccess.open("res://addons/xr-kit/hand-gesture-recognition/hand_pose_templates.json", FileAccess.READ)
		if file:
			# TODO: catch error when json is incorrect
			return JSON.parse_string(file.get_as_text())
		else:
			return {}


func _on_timer_timeout():
	var recognized_pose: String = recognize_pose()
	if recognized_pose != pose:
		new_pose.emit(recognized_pose, pose)
		pose = recognized_pose
