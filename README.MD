# Godot XR Kit

Godot XR Kit as a set of modules providing various features for XR development in Godot 4.

## Physical Movement

Physics-based XR movement. Player hands collide with environment and can grab or push physics object in realistic manner. Player body can collide with physics objects and be moved around in space.

### Features

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

[Read more](/addons/xr-kit/physical-movement/)


## Hand Gesture Recognition

Real-time recognition of hand poses based on predefined templates.

### Currently tracked hand poses:

- open
- rest
- half_grip
- full_grip
- point
- thumb_up

[Read more](/addons/xr-kit/hand-gesture-recognition/)

## Getting started

Repository contains Godot v4.0.1 project with XR and main scene preconfigured.

1. Download project using [this link](https://github.com/patrykkalinowski/godot-xr-kit/archive/refs/heads/master.zip).
2. Click `Run Project` or press F5
3. `Playground` scene from examples folder will be loaded

`Playground` scene implements every module in XR Kit.

## Compatibility

Plugin should work with every OpenXR runtime supporting Vulkan and using OpenXR hand tracking extension. It works best with SteamVR, as it simulates hand skeleton even when using controllers. In other runtimes, when using controllers hands will not receive skeleton data and they will not work.

For plugin to be fully compatible with all OpenXR runtimes, it needs hand models with animations - which is planned, but not yet implemented.

| Headset | Runtime | Compatible |
|---|---|:---:|
| HP Reverb G2 | SteamVR | Yes |
| Pico 4 | Standalone | No hand tracking |
| Meta Quest 2 | Standalone | Hand tracking only (no controllers)
| Other | ? | ? |

## Contributing

If you'd like to improve the plugin, there are few options:

### Test compatibility with other headsets and runtimes

I don't have access to other headset than mine (HP Reverb G2). Compatibility checks with other headsets are more than welcome.

### Code improvements

Source code contains multiple `TODO` comments with known issues and missing features. You can also take a look at existing [Issues](https://github.com/patrykkalinowski/godot-xr-kit/issues).

### Showcase

Build something with the plugin and share an example scene or recorded video

### Ideas

If you have some ideas how to improve the plugin, don't hesitate to [create an issue](https://github.com/patrykkalinowski/godot-xr-kit/issues/new) or message me directly at [patryk@patrykkalinowski.com](mailto:patryk@patrykkalinowski.com).
