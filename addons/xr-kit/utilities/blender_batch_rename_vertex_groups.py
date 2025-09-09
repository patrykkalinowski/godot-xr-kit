for object in bpy.context.selected_objects:
  print("###")
  print(object.name)
  for vertex_group in object.vertex_groups:
    vertex_group.name = vertex_group.name.replace("Right", "Left")
    print(vertex_group.name)