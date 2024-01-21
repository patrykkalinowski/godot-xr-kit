# Godot XR Kit - Hand Gesture Recognition

Real-time recognition of hand poses based on predefined templates.

![Godot XR Kit - Hand Gesture Recognition](/screenshots/hand_gesture_recognition.gif)

## Poses tracked by default:

- open
- rest
- fist
- thumb_up
- one
- two
- three
- four
- five
- middle_finger

## How does it work

Every 100ms, angle of each bone in skeleton to bone 0 (wrist) is compared with angles defined for all template poses. Template with lowest difference (least computed angle difference from current pose) is chosen as recognized pose.

## Getting started

1. Add `HandPoseRecognition.tscn` anywhere to your scene where hand skeleton is available. 
2. Assign your `XRCamera3D` and `Skeleton3D` nodes to `HandPoseRecognition` nodes in property editor. 
3. When new pose is recognized, `HandPoseRecognition` node will fire `new_pose` signal.
4. Current pose can also be queried from `HandPoseRecognition.pose` variable.

Predefined poses in template file (`hand_pose_templates.json`) were created using hand tracking.

## Adding new pose templates

1. Add `HandPoseSave.tscn` anywhere to your scene where hand skeleton is available.
2. Assign your `XRCamera3D` and `Skeleton3D` nodes to `HandPoseSave` node. 
3. During play, press **spacebar** to save skeleton pose as a template. By default, template will be named `custom_pose` and every press of spacebar will override it with current pose. You can change pose name in `HandPoseSave` property editor.
4. You will need to reload the game for new templates to be loaded for recognition.
