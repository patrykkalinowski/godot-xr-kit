extends Node

@export var xr_origin: XROrigin3D

@export_group("Skeletons")
@export var source_skeleton: Skeleton3D
@export var destination_skeleton: Skeleton3D

@export_group("Nodes")
@export var source_node: Node3D
@export var destination_node: Node3D

@export_group("Filter Parameters")
@export var allowed_jitter: float = 1 # fcmin (cutoff), decrease to reduce jitter
@export var lag_reduction: float = 5 # beta, increase to reduce lag

var x_filter
var y_filter
var z_filter

# Called when the node enters the scene tree for the first time.
func _ready():
	var OneEuroFilter = load("res://addons/xr-kit/smooth-input-filter/scripts/one_euro_filter.gd")
	var args := {
		"cutoff": allowed_jitter,
		"beta": lag_reduction,
	}
	x_filter = OneEuroFilter.new(args)
	y_filter = OneEuroFilter.new(args)
	z_filter = OneEuroFilter.new(args)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta) -> void:
	if source_skeleton and destination_skeleton:
		var origin: Vector3 = source_skeleton.global_transform.origin - xr_origin.global_transform.origin
		var x: float = x_filter.filter(origin.x, delta)
		var y: float = y_filter.filter(origin.y, delta)
		var z: float = z_filter.filter(origin.z, delta)

		destination_skeleton.set_global_transform(Transform3D(source_skeleton.get_global_transform().basis, xr_origin.global_transform.origin + Vector3(x, y, z)))
		for bone_id in source_skeleton.get_bone_count():
				destination_skeleton.set_bone_pose_position(bone_id, source_skeleton.get_bone_pose_position(bone_id))
				destination_skeleton.set_bone_pose_rotation(bone_id, source_skeleton.get_bone_pose_rotation(bone_id))

	if source_node and destination_node:
		var origin: Vector3 = source_node.global_transform.origin - xr_origin.global_transform.origin
		var x: float = x_filter.filter(origin.x, delta)
		var y: float = y_filter.filter(origin.y, delta)
		var z: float = z_filter.filter(origin.z, delta)

		destination_node.set_global_transform(Transform3D(source_node.get_global_transform().basis, xr_origin.global_transform.origin + Vector3(x, y, z)))
