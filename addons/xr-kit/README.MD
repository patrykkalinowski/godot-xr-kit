# Godot XR Kit

Godot XR Kit is a set of addons providing various features for XR development in Godot 4.

## Physics Movement

Physics-based XR movement. Player hands collide with environment and can grab or push physics object in realistic manner. Player body can collide with physics objects and be moved around in space.

![Godot XR Kit - Physics Movement](/screenshots/physics_movement.gif)

[Read more](/addons/xr-kit/physics-movement/)

## Hand Gesture Recognition

Real-time recognition of hand poses based on predefined templates.

![Godot XR Kit - Hand Gesture Recognition](/screenshots/hand_gesture_recognition.gif)

[Read more](/addons/xr-kit/hand-gesture-recognition/)

## Smooth Input Filter

Applies smoothing to XR hand movement using [1€ filter](https://gery.casiez.net/1euro/). Supports hand and controller tracking. See [1€ filter demo](https://gery.casiez.net/1euro/InteractiveDemo/). Can be used to reduce microstutter or simulate fake weight by increasing hand movement lag.

![Godot XR Kit - Smooth Input Filter](/screenshots/smooth_input_filter.gif)

[Read more](/addons/xr-kit/smooth-input-filter/)

## Cinematic View

Smooth VR preview for recording in native monitor resolution.

*Raw preview (left) vs Cinematic View*

![Godot XR Kit - Cinematic View](/screenshots/cinematic_view.gif)

[Read more](/addons/xr-kit/cinematic-view/)

## Getting started

Repository contains Godot 4.5 project with XR and main scene preconfigured. Releases are reduced to addon files only.

To get most recent version of the whole project (for Godot 4.5, without official release yet), [download from master branch](https://github.com/patrykkalinowski/godot-xr-kit/archive/refs/heads/master.zip).

Latest release (for Godot 4.2) is available in Godot's Asset Library under the name [XR Kit](https://godotengine.org/asset-library/asset/1870) or on [releases page](https://github.com/patrykkalinowski/godot-xr-kit/releases/latest).

If you are on Quest, make sure your hardware is configured properly:

- Enable "Developer Runtime Features" in Oculus PCVR app (Settings -> Beta)
- Enable Developer Mode in Meta Quest app on your phone


## Compatibility

XR Kit has been tested with SteamVR and Oculus (PC and standalone) using Meta Quest 3. 

## Contributing

If you'd like to improve the plugin, there are few options:

### Code improvements

Source code contains multiple `TODO` comments with known issues and missing features. You can also take a look at existing [Issues](https://github.com/patrykkalinowski/godot-xr-kit/issues).

### Showcase

Build something with the plugin and share an example scene or recorded video [here](https://github.com/patrykkalinowski/godot-xr-kit/discussions/categories/show-and-tell).

### Ideas

If you have some ideas how to improve the plugin, don't hesitate to [create new discussion](https://github.com/patrykkalinowski/godot-xr-kit/discussions/categories/ideas) or message me directly at [patryk@patrykkalinowski.com](mailto:patryk@patrykkalinowski.com).
