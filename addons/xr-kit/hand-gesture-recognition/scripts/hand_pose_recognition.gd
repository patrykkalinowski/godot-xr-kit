extends Node

signal new_pose(previous_pose: StringName, pose: StringName)

@export var skeleton: Skeleton3D
@export var debug_label: Label3D

var templates: Dictionary
var pose: StringName


func _ready() -> void:
  templates = load_templates()
  
func recognize_pose() -> StringName:
  var best_match_key: StringName
  var best_match_distance: float = INF
  
  for key in templates.keys():
    var total_distance := 0.0
    
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
