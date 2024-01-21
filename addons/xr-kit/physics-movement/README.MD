# Godot XR Kit - Physics Movement

Scripts and scenes for physics-based XR movement. Player hands collide with environment and can grab or push physics object in realistic manner. Player body can collide with physics objects and be moved around in space.

*Physics Movement is in alpha stage.*

![Godot XR Kit - Physics Movement](/screenshots/physics_movement.gif)

## Features

- Physics hand follows controller and can be blocked by world objects
- Player can grab and move objects
  - Heavy objects are harder to move
  - Grabbing heavy objects with two hands makes them easier to move
  - Fingers curl around grabbed objects geometry
- Player can move themselves by pushing away from objects
  - Heavier objects allow for stronger push
- Player can move in space with thrusters
- Player can brake in space with thruster brake
- Player can hit objects with their head and push themselves away
- Ghost hand appears when controller hand gets far from physics one
- Physics hand is reset to controller position if it gets too far from it (ex. hand got stuck)
- Joystick snap rotation
- Smooth 6 degrees of freedom rotation around grabbed static object (trigger activated)
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

Physics Movement requires [Jolt Physics engine](https://github.com/godot-jolt/godot-jolt). It is already included in this repository.

`/addons/xr-kit/physics_movement/scenes/player.tscn` contains everything needed for physics movement, including XR interface initialization.

`/addons/xr-kit/examples/playground.tscn` implements `player.tscn` with some additional objects to interact with.

## Known issues

- Provided hand models (valve_hand_models) were designed for SteamVR where hands have fixed size. Oculus hand tracking changes skeleton size based on user hands, which messes up the mesh due to incorrect mesh skinning
- Free rotation (when you press trigger while holding an object) has several rotation bugs
- Joystick rotation around static object applies incorrect rotation value depending on angle
- Body does not retain momentum during grab (grabbing when moving will stop body, pushback and thrusters don't work when holding an object)

## Godot 3.5

Early version of this addon developed for Godot 3.5 is available on branch `godot-3.5`
