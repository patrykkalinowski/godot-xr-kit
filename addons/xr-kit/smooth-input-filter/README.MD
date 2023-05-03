# Godot XR Kit - Smooth Input Filter

Applies smoothing to XR hand movement using [1€ filter](https://gery.casiez.net/1euro/). Supports hand and controller tracking. See [1€ filter demo](https://gery.casiez.net/1euro/InteractiveDemo/). Can be used to reduce microstutter or simulate fake weight by increasing hand movement lag.

![Godot XR Kit - Smooth Input Filter](/screenshots/smooth_input_filter.gif)

## Features:

- Supports smoothing movement for hand tracking Skeleton3D and Node3D (ex. XRController3D)
- Reduces jitter while keeping lag to minimum

## How does it work

Every axis of source node global_transform's origin (`Vector3`) is passed through 1 euro filter, which returns new `Vector3` with smoothed out values. This new `Vector3` is then used as new origin. 

## Getting started

1. Add `smooth_open_xr_hand.tscn` anywhere to your scene.
2. You need to duplicate nodes you want to smooth, these duplicates will follow source nodes with filter applied.
2. If you are using hand tracking, assign `Skeleton3D` node controlled by `OpenXRHand` as **Source Skeleton**. Assign `Skeleton3D` node you want to have smoothed as **Destination Skeleton**.
3. If you are using controllers or want to smooth out movement of any other 3D node, assign nodes to **Source Node** and **Destination Node**.
4. Tune filter with **Allowed Jitter** and **Lag Reduction** parameters.

## Tuning the filter

- fcmin = Allowed Jitter
- beta = Lag Reduction

To minimize jitter and lag when tracking human motion, the two parameters (fcmin and beta) can be set using a simple two-step procedure. First beta is set to 0 and fcmin (mincutoff) to a reasonable middle-ground value such as 1 Hz. Then the body part is held steady or moved at a very low speed while fcmin is adjusted to remove jitter and preserve an acceptable lag during these slow movements (decreasing fcmin reduces jitter but increases lag, fcmin must be > 0). Next, the body part is moved quickly in different directions while beta is increased with a focus on minimizing lag. First find the right order of magnitude to tune beta, which depends on the kind of data you manipulate and their units: do not hesitate to start with values like 0.001 or 0.0001. You can first multiply and divide beta by factor 10 until you notice an effect on latency when moving quickly. Note that parameters fcmin and beta have clear conceptual relationships: **if high speed lag is a problem, increase beta; if slow speed jitter is a problem, decrease fcmin**. ~ [source](https://gery.casiez.net/1euro/)
