import bpy

# This Blender script switches the names of the bones in the animations (action groups and fcurves) between left and right hand.
# Renamed animations can be appended to the file with the other hand

source = ""
target = ""
for action in bpy.data.actions:
    for group in action.groups:
        if group.name.endswith("_L"):
            source = "_L"
            target = "_R"
        elif group.name.endswith("_R"):
            source = "_R"
            target = "_L"
        group.name = group.name.replace(source, target)
        
        for fcurve in group.channels:
            fcurve.data_path = fcurve.data_path.replace(source, target)