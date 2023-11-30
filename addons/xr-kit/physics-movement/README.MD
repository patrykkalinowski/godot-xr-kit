# Godot XR Kit - Physics Movement

Scripts and scenes for physics-based XR movement. Player hands collide with environment and can grab or push physics object in realistic manner. Player body can collide with physics objects and be moved around in space.

*Physics Movement is in alpha stage.*

![Godot XR Kit - Physics Movement](/screenshots/physics_movement.gif)

## Features

- Physics hand follows controller and can be blocked by world objects
- Players can grab and move objects
  - Heavy objects are harder to move
  - Grabbing heavy objects with two hands makes them easier to move
  - Fingers curl around grabbed objects geometry
- Players can move themselves by pushing away from objects
  - Heavier objects allow for stronger push
- Players can move in space with thrusters
- Players can brake in space with thruster brake
- Players can hit objects with their head and push themselves away
- Ghost hand appears when controller hand gets far from physics one
- Physics hand is teleported to controller position if it gets too far from it (ex. hand got stuck)
- Body snap rotation
- Body smooth XYZ rotation around static object using hands (trigger activated)
- Fingers wiggle a little when hand is moving

## How does it work

Usually in VR games, player hand is just a visual object which clips through walls and doesn't react to physics in general.

This addon introduces a copy of controller hand mesh which is driven by physics-based RigidBody. Physics hand tries to follow player hand driven by controller, but as physics object it reacts to environment and can push other RigidBodies or be stopped by a wall.

To make sure physics hand works in predictable ways, only wrist bone is responsible for physics movement and acts as driving force for the whole hand. physics fingers are simply colliders for wrist RigidBody and are always following controller fingers poses. Additionally, fingers use Inverse Kinematics to procedurally define positions on grabbed objects and react on forces applied to them, ex. simulating inertia during fast hand movements.

Provided hand models use OpenXR convention of 26 joints for hand tracking: 4 joints for the thumb finger, 5 joints for the other four fingers, and the wrist and palm of the hands.

![OpenXR Hands](/screenshots/openxr_hands.png)
*Source: https://registry.khronos.org/OpenXR/specs/1.0/html/xrspec.html#_conventions_of_hand_joints*

Addon as been tested with SteamVR and Oculus OpenXR runtimes. Hand tracking is supported in Oculus.

Custom OpenXR Action Map is provided for control scheme used by Physics Movement, you can find it at `addons/xr-kit/physics-movement/openxr_action_map.tres`.

## Getting started

`/addons/xr-kit/physics_movement/scenes/player.tscn` contains everything needed for physics movement, including XR interface initialization.

`/addons/xr-kit/examples/playground.tscn` implements `player.tscn` with some additional objects to interact with.

## Known issues

Provided hand models (valve_hand_models) were designed for SteamVR and have some issues with finger placement in Oculus runtime. In the end, you should replace them with your own hand models.

## Godot 3.5

Early version of this addon developed for Godot 3.5 is available on branch `godot-3.5`
