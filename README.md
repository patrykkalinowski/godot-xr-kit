# Godot XR Physical Movement Kit

This plugin for Godot 3 provides scripts and scenes for physics-based XR movement. Player hands collide with environment and can grab or push physics object in realistic manner. Player body can be pushed away from other objects using hands or head.

[Watch the showcase video](https://github.com/patrykkalinowski/godot-xr-physical-movement/blob/master/img/showcase.mp4)

## Features

- Physical hand follows controller and can be blocked by world objects
- Players can grab and move objects
  - Heavy objects are harder to move
  - Grabbing heavy objects with two hands makes them easier to move
- Players can move themselves by pushing away from objects
  - Heavier objects allow for stronger push
- Players can move in space with thrusters (button activated)
- Players can hit objects with their head and push themselves away
- Ghost hand appears when controller hand gets far from physical one
- Body snap rotation

## Requirements

[godot-openxr](https://github.com/GodotVR/godot_openxr) plugin is required. You can download it from [AssetLib](https://docs.godotengine.org/en/stable/community/asset_library/using_assetlib.html#in-the-editor) directly in engine (it's called OpenXR Plugin). Compatibility is tested with version 1.3.0.

## Limitations & known issues

- Plugin is currently coded only for zero G environment
- Physical hand takes the shortest way to reach controller rotation, so it might rotate in the opposite direction to how controller was rotated
- Fingers are not curling around grabbed objects with good enough reliability
- Body cannot be rotated using hands

## How does it work

OpenXR runtime provides positions of every bone in player's hand, which are then used to position hand mesh. This controller hand mesh is just a visual object which clips through walls and doesn't react to physics in general.

Godot XR Physical Movement Kit introduces a copy of controller hand mesh which is driven by physics-based RigidBody. Physical hand tries to follow controller, but as physics object it reacts to environment - it can be stopped by a wall or push other RigidBodies.

To make sure physical hand works in predictable ways, only wrist bone is responsible for physical movement and acts as driving force for the whole hand. Physical fingers are simply colliders for wrist RigidBody and are always following controller fingers. Additionally, finger colliders utilise raycasts to freeze fingers when they touch object surface during grab.

This plugin uses OpenXR convention of 26 joints for hand tracking: 4 joints for the thumb finger, 5 joints for the other four fingers, and the wrist and palm of the hands.

Example scenes in `/addons/godot-xr-physical-movement/examples` folder and main `Player.tscn` scene use Valve hands model from `godot-openxr` plugin which conform to this convention.

![OpenXR Hands](img/openxr_hands.png)
*Source: https://registry.khronos.org/OpenXR/specs/1.0/html/xrspec.html#_conventions_of_hand_joints*

## Godot 4.0

Currently I am unable to port this plugin to Godot 4 as I can’t get my headset (Reverb G2) to work with any of 4.0 versions.

