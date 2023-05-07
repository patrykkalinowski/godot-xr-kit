# Godot XR Kit

Godot XR Kit is a set of addons providing various features for XR development in Godot 4.

## Physics Movement

Physics-based XR movement. Player hands collide with environment and can grab or push physics object in realistic manner. Player body can collide with physics objects and be moved around in space.

![Godot XR Kit - Physics Movement](/screenshots/physics_movement.gif)

### Features

- Physics hand follows controller and can be blocked by world objects
- Players can grab and move objects
  - Heavy objects are harder to move
  - Grabbing heavy objects with two hands makes them easier to move
  - Fingers curl around grabbed objects geometry
- Players can move themselves by pushing away from objects
  - Heavier objects allow for stronger push
- Players can move in space with thrusters (button activated)
- Players can hit objects with their head and push themselves away
- Ghost hand appears when controller hand gets far from physics one
- Body snap rotation
- Body XYZ rotation around static object using hands (trigger activated)

[Read more](/addons/xr-kit/physics-movement/)

## Hand Gesture Recognition

Real-time recognition of hand poses based on predefined templates.

![Godot XR Kit - Hand Gesture Recognition](/screenshots/hand_gesture_recognition.gif)

### Currently tracked hand poses:

- open
- rest
- half_grip
- full_grip
- point
- thumb_up

[Read more](/addons/xr-kit/hand-gesture-recognition/)

## Smooth Input Filter

Applies smoothing to XR hand movement using [1€ filter](https://gery.casiez.net/1euro/). Supports hand and controller tracking. See [1€ filter demo](https://gery.casiez.net/1euro/InteractiveDemo/). Can be used to reduce microstutter or simulate fake weight by increasing hand movement lag.

![Godot XR Kit - Smooth Input Filter](/screenshots/smooth_input_filter.gif)

### Features:

- Supports smoothing movement for hand tracking Skeleton3D and Node3D (ex. XRController3D)
- Reduces jitter while keeping lag to minimum

[Read more](/addons/xr-kit/smooth-input-filter/)

## Cinematic View

Smooth VR preview for recording in native monitor resolution.

![Godot XR Kit - Cinematic View](/screenshots/cinematic_view.gif)

*Raw preview (left) vs Cinematic View*

### Features:

- Full screen VR preview in monitor native resolution
- Smooth preview can be rendered to another screen
- Smoothing parameters can be tuned
- Full range of Godot's camera settings is available 

[Read more](/addons/xr-kit/cinematic-view/)

## Getting started

Repository contains Godot 4.0.2 project with XR and main scene preconfigured. Releases are reduced to addon files only.

Latest release is available in Godot's Asset Library under the name [XR Kit](https://godotengine.org/asset-library/asset/1870) or on [releases page](https://github.com/patrykkalinowski/godot-xr-kit/releases/latest).

To get most recent version of the whole project, [download from master branch](https://github.com/patrykkalinowski/godot-xr-kit/archive/refs/heads/master.zip).

`/addons/xr-kit/examples/playground.tscn` implements Physics Movement, Hand Gesture Recognition and Cinematic View.

`/addons/xr-kit/examples/smooth_input_filter.tscn` implements Smooth Input Filter.

## Compatibility

Plugin should work with every OpenXR runtime supporting Vulkan and using OpenXR hand tracking extension. It works best with SteamVR, as it simulates hand skeleton even when using controllers. In other runtimes, when using controllers, hands will not receive skeleton data and they will not work.

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

Build something with the plugin and share an example scene or recorded video [here](https://github.com/patrykkalinowski/godot-xr-kit/discussions/categories/show-and-tell).

### Ideas

If you have some ideas how to improve the plugin, don't hesitate to [create new discussion](https://github.com/patrykkalinowski/godot-xr-kit/discussions/categories/ideas) or message me directly at [patryk@patrykkalinowski.com](mailto:patryk@patrykkalinowski.com).
