@tool
extends EditorScript

## This script generates collision shapes for each bone in the hand skeleton.

# Select Skeletons3D in the scene tree for which you want to generate colliders.
var skeleton_nodes = EditorInterface.get_selection().get_selected_nodes()


# Called when the script is executed (using File -> Run in Script Editor).
func _run() -> void:
	for skeleton: Skeleton3D in skeleton_nodes:
		for bone_id: int in skeleton.get_bone_count():
			var bone_name: String = skeleton.get_bone_name(bone_id)
			
			# Do not create colliders for Tip and Touch bones
			if bone_name.ends_with("Tip") or bone_name.ends_with("Touch"):
				continue
			
			# Find or create BoneAttachment3D for each bone
			var bone_attachment: BoneAttachment3D
			if skeleton.get_node_or_null(bone_name) is BoneAttachment3D:
				bone_attachment = skeleton.get_node(bone_name)
			else:
				bone_attachment = BoneAttachment3D.new()
				skeleton.add_child(bone_attachment)
				bone_attachment.owner = get_scene()
				bone_attachment.bone_idx = bone_id
				bone_attachment.set_name(bone_name)
			
			# Create initial CollisionShape under BoneAttachment
			var collision_shape: CollisionShape3D = CollisionShape3D.new()
			collision_shape.shape = SphereShape3D.new()
			collision_shape.shape.radius = 0.01
			bone_attachment.add_child(collision_shape)
			collision_shape.owner = get_scene()
			collision_shape.set_name("CollisionShape3D")
			
			# GENERATE COLLIDER MESHES FROM SKELETON MESH
			## Find meshes for this bone
			#var bone_children: Array = skeleton.find_children(bone_name + "*")
			#for mesh_instance in bone_children.filter(func(node): return node is MeshInstance3D):
				## Generate collider for the mesh shape from MeshInstance3D
				#var collision_shape_node: CollisionShape3D = CollisionShape3D.new()
				#var collision_shape_mesh: ConvexPolygonShape3D = mesh_instance.mesh.create_convex_shape()
				#collision_shape_node.shape = collision_shape_mesh
				#collision_shape_node.set_name("CollisionShape3D")
				## Parent collider to BoneAttachment
				#bone_attachment.add_child(collision_shape_node, true)
				#collision_shape_node.owner = get_scene()
				## Set transform to match the mesh
				#collision_shape_node.transform = bone_attachment.transform.inverse()
