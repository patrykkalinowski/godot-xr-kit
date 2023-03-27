# Godot XR Physical Movement Kit

This plugin for Godot 4 provides scripts and scenes for physics-based XR movement. Player hands collide with environment and can grab or push physics object in realistic manner. Player body can collide with physics objects and be moved around in space.

*It is still a work in progress, not ready to be dropped in as-is to your game.*

## Features

- Physical hand follows controller and can be blocked by world objects
- Players can grab and move objects
  - Heavy objects are harder to move
  - Grabbing heavy objects with two hands makes them easier to move
  - Fingers curl around grabbed objects geometry
- Players can move themselves by pushing away from objects
  - Heavier objects allow for stronger push
- Players can move in space with thrusters (button activated)
- Players can hit objects with their head and push themselves away
- Ghost hand appears when controller hand gets far from physical one
- Body snap rotation
- Body rotation around static object using hands (around Y axis)

---

## Getting started

Refer to [Godot documentation on XR](https://docs.godotengine.org/en/stable/tutorials/xr/setting_up_xr.html) to setup your Godot project for XR (enable OpenXR and XR shaders).

Complete XR scene is available in `examples/Playground.tscn`. It should work out of the box after your project is setup for XR.

---

## Compatibility

Plugin is tested for SteamVR. It should work with every OpenXR runtime supporting Vulkan and using OpenXR hand tracking extension.

| Headset | Runtime | Compatible |
|---|---|:---:|
| HP Reverb G2 | SteamVR | Yes |
| Pico 4 | Standalone | No hand tracking |
| Meta Quest 2 | Standalone | Hand tracking only (no controllers)
| Other | ? | ? |

---

## How does it work

OpenXR runtime provides positions of every bone in player's hand, which are then used to position hand mesh. This controller hand mesh is just a visual object which clips through walls and doesn't react to physics in general.

Godot XR Physical Movement Kit introduces a copy of controller hand mesh which is driven by physics-based RigidBody. Physical hand tries to follow controller, but as physics object it reacts to environment and can be stopped by a wall or push other RigidBodies.

To make sure physical hand works in predictable ways, only wrist bone is responsible for physical movement and acts as driving force for the whole hand. Physical fingers are simply colliders for wrist RigidBody and are always following controller fingers. Additionally, finger colliders utilise raycasts to freeze fingers when they touch object surface during grab.

This plugin uses OpenXR convention of 26 joints for hand tracking: 4 joints for the thumb finger, 5 joints for the other four fingers, and the wrist and palm of the hands.

![OpenXR Hands](openxr_hands.png)
*Source: https://registry.khronos.org/OpenXR/specs/1.0/html/xrspec.html#_conventions_of_hand_joints*

---

## Contributing

If you'd like to improve the plugin, there are few options:

### Test compatibility with other headsets and runtimes

I am unable to test this plugin on different headset because I don't own them.

### Code improvements

Source code contains multiple `TODO` comments with known issues and missing features.

### Showcase

Build something with the plugin and share an example scene or recorded video

### Ideas

If you have some ideas how to improve the plugin, don't hesitate to [create an issue](https://github.com/patrykkalinowski/godot-xr-physical-movement/issues/new)

---

## Godot 3.5

Early version of this plugin developed for Godot 3.5 is available on branch `godot-3.5`
