# Godot XR Kit - Cinematic View

Smooth VR preview for recording in native monitor resolution.

![Godot XR Kit - Cinematic View](/screenshots/cinematic_view.gif)

*Raw preview (left) vs Cinematic View*

## Features:

- Full screen VR preview in monitor native resolution
- Smooth preview can be rendered to another screen
- Smoothing parameters can be tuned
- Full range of Godot's camera settings is available 

## How does it work

Cinematic View creates new separate window with player camera view smoothed out. Camera translation is smoothed using [1€ filter](https://gery.casiez.net/1euro/), while rotation is slerped Basis. 

## Getting started

1. Go to Project Settings, toggle **Advanced settings** and disable **Embed Subwindows** option in **Display -> Window** tab 
2. Add `cinematic_view.tscn` anywhere to your scene.
3. Assign your `XRCamera3D` node to `CinematicView` node in property editor. 
4. Start a project. Cinematic View will appear as full screen window on your main screen.
5. Record videos using capture software such as OBS Studio or Nvidia Shadowplay.

Cinematic View is implemented in `/addons/xr-kit/examples/playground.tscn`.