# Godot XR Kit - Hand Gesture Recognition

This module for Godot XR Kit enables real-time recognition of hand poses based on predefined templates.

## Currently tracked poses:

- open
- rest
- half_grip
- full_grip
- point
- thumb_up

## How does it work

Module checks distance of every bone in skeleton to bone 0 (wrist) and compares the difference of distances for every template pose. Template with lowest difference (least computed distance from current pose) is chosen as recognized pose.

## Getting started

1. Add `HandPoseRecognition` scene anywhere to your scene where hand skeleton is available. 
2. Attach your `Skeleton3D` node to `HandPoseRecognition` node. 
3. When new pose is recognized, `HandPoseRecognition` node will fire `new_pose` signal. 

Predefined poses in template file (`hand_pose_templates.json`) were created with skeleton conforming to [OpenXR convention of hand joints](https://registry.khronos.org/OpenXR/specs/1.0/html/xrspec.html#_conventions_of_hand_joints)

## Adding new pose templates

1. Add `HandPoseSave` scene anywhere to your scene where hand skeleton is available.
2. Attach your `Skeleton3D` node to `HandPoseSave` node. 
3. During play, press **spacebar** to save skeleton pose as a template. By default, template will be named `custom_pose` and every press of spacebar will override it with current pose. You can change pose name in node variables (right sidebar in editor).
4. You will need to reload the game for new templates to be loaded for recognition.
