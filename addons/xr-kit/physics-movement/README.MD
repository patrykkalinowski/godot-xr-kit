# Godot XR Kit - Physics Movement

Scripts and scenes for physics-based XR movement. Player hands collide with environment and can grab or push physics object in realistic manner. Player body can collide with physics objects and be moved around in space.

Physics Movement is in alpha stage. Provided hand models are [from Valve](https://github.com/ValveSoftware/openvr/wiki/Hand-Skeleton) and are not open source.

![Godot XR Kit - Physics Movement](/screenshots/physics_movement.gif)

## Features

- Physics hand follows controller and can be blocked by world objects
- Player can grab and move objects
  - Heavy objects are harder to move
  - Grabbing heavy objects with two hands makes them easier to move
  - Fingers curl around grabbed objects geometry
- Player can move themselves by pushing away from objects
  - Heavier objects allow for stronger push
- Player can move in zero G with thrusters
- Player can brake in zero G with thruster brake
- Player can hit objects with their head and push themselves away
- ~~Ghost hand appears when controller hand gets far from physics one~~
- Physics hand is reset to controller position if it gets too far from it (ex. hand got stuck)
- Joystick snap rotation
- Smooth 6 degrees of freedom rotation around grabbed static object (trigger activated)
- ~~Fingers wiggle a little when hand is moving~~

## How does it work

Usually in VR games, player hand is just a visual object which clips through walls and doesn't react to physics in general.

This addon introduces physics-based hand which tries to follow real-world player hand driven by controller, but as physics object it reacts to environment and can push other RigidBodies or be stopped by a wall.

To make sure physics hand works in predictable ways, only wrist bone is responsible for physics movement and acts as driving force for the whole hand. physics fingers are simply colliders for wrist RigidBody and are always following controller fingers poses. Additionally, fingers use Inverse Kinematics to procedurally define positions on grabbed objects and react on forces applied to them, ex. simulating inertia during fast hand movements.

Addon as been tested with SteamVR and Oculus OpenXR runtimes. Hand tracking is supported in Oculus.

Custom OpenXR Action Map is provided for control scheme used by Physics Movement, you can find it at `addons/xr-kit/physics-movement/openxr_action_map.tres`.

## Getting started

Physics Movement requires Jolt Physics engine to be set in Project Settings (default since Godot 4.4).

Open main scene with example playground at `/addons/xr-kit/main/main.tscn`. It implements physics movement in zero gravity with some objects to interact with.

`/addons/xr-kit/physics_movement/player/scenes/xr_player.tscn` contains player code for physics movement. 


## Known issues

- Free rotation (when you press trigger while holding an object) has several rotation bugs

## Godot 3.5

Early version of this addon developed for Godot 3.5 is available on branch `godot-3.5`
