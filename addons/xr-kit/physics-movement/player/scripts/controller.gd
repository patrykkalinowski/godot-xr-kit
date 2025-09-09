extends Node3D

var target_position: Vector3
@export var SIDE: String
var held_object: Node3D
var free_rotation: bool

var click_duration: float
const long_click_duration: float = 0.2

signal click(released: bool)
signal long_click(released: bool)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	
func _input(event: InputEvent) -> void:
	if event.is_action_released(SIDE + "_click"):
		handle_click(click_duration, true)
		click_duration = 0 # reset click duration for next press

	if click_duration > long_click_duration and Input.is_action_pressed("mouse_wheel_up"):
		move_tracker(0.05)

	if click_duration > long_click_duration and Input.is_action_pressed("mouse_wheel_down"):
		move_tracker(-0.05)
		

func _physics_process(delta: float) -> void:
	if $RayCast3D.is_colliding():
		target_position = $RayCast3D.get_collision_point()
		held_object = $RayCast3D.get_collider()
		$Tracker.global_transform.origin = target_position
		$Tracker.look_at(target_position - $RayCast3D.get_collision_normal(), %Camera.global_transform.basis.y)
		$Tracker.rotate_x(deg_to_rad(90))
			

func _process(delta: float) -> void:
	# Measure how long the button has been pressed
	if Input.is_action_pressed(SIDE + "_click"):
		click_duration += delta
		handle_click(click_duration)


func handle_click(duration: float, released: bool = false) -> void:
	if duration >= long_click_duration:
		long_click.emit(released)
		
	else:
		click.emit(released)
		
func move_tracker(distance: float) -> void:
	# Move controller tracker forward and backward
	var new_tracker_position = $Tracker.global_transform.origin - %Camera.global_transform.basis.z.normalized() * distance
	# Make sure tracker is not getting too far from camera
	if %Camera.global_transform.origin.distance_to(new_tracker_position) > 0.6:
		return
	else:
		$Tracker.global_transform.origin = new_tracker_position
