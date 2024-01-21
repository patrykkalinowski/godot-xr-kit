extends Node

@export var camera: XRCamera3D
@export var skeleton: Skeleton3D
@export var pose_name: StringName

var templates: Dictionary

func _ready() -> void:
	templates = load_templates()

func _input(event) -> void:
	# press space to save current pose as template
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			save_pose(pose_name)

# read positions of bones in skeleton and save them to JSON object under a name
func save_pose(name: StringName) -> void:
	var template := { name: {} }

	for bone_id in skeleton.get_bone_count():
		# Wrist bone rotation is relative to player head, so we can detect hand rotation in the world
		if bone_id == 0:
			template[name][bone_id] = skeleton.global_transform.basis.get_rotation_quaternion().angle_to(camera.global_transform.basis.get_rotation_quaternion())

			continue
		# angle from current bone to wrist bone
		template[name][bone_id] = skeleton.get_bone_global_pose(bone_id).basis.get_rotation_quaternion().angle_to(skeleton.get_bone_global_pose(0).basis.get_rotation_quaternion())

	templates.merge(template, true)

	save_templates(templates)

	prints(name, "pose saved!")

func save_templates(templates: Dictionary) -> void:
		var file = FileAccess.open("res://addons/xr-kit/hand-gesture-recognition/hand_pose_templates.json", FileAccess.WRITE)
		var json = JSON.stringify(templates)
		file.store_string(json)

func load_templates() -> Dictionary:
		var file = FileAccess.open("res://addons/xr-kit/hand-gesture-recognition/hand_pose_templates.json", FileAccess.READ)
		if file:
			return JSON.parse_string(file.get_as_text())
		else:
			return {}
