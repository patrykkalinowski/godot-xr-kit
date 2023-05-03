# Godot XR Kit - Hand Gesture Recognition

Real-time recognition of hand poses based on predefined templates.

![Godot XR Kit - Hand Gesture Recognition](/screenshots/hand_gesture_recognition.gif)

## Currently tracked poses:

- open
- rest
- half_grip
- full_grip
- point
- thumb_up

## How does it work

Distance of every bone in skeleton to bone 0 (wrist) is compared with distances for every template pose. Template with lowest difference (least computed distance from current pose) is chosen as recognized pose.

## Getting started

1. Add `HandPoseRecognition.tscn` anywhere to your scene where hand skeleton is available. 
2. Assign your `Skeleton3D` node to `HandPoseRecognition` node in property editor. 
3. When new pose is recognized, `HandPoseRecognition` node will fire `new_pose` signal.
4. Current pose can also be queried from `HandPoseRecognition.pose` variable.

Predefined poses in template file (`hand_pose_templates.json`) were created using SteamVR and Valve hands, with skeleton conforming to [OpenXR convention of hand joints](https://registry.khronos.org/OpenXR/specs/1.0/html/xrspec.html#_conventions_of_hand_joints)

## Adding new pose templates

1. Add `HandPoseSave.tscn` anywhere to your scene where hand skeleton is available.
2. Assign your `Skeleton3D` node to `HandPoseSave` node. 
3. During play, press **spacebar** to save skeleton pose as a template. By default, template will be named `custom_pose` and every press of spacebar will override it with current pose. You can change pose name in `HandPoseSave` property editor.
4. You will need to reload the game for new templates to be loaded for recognition.
