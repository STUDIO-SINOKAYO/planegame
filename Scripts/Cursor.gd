extends Node2D
class_name CustomCursor

## Custom cursor that changes appearance based on interaction state

@export var rotation_speed: float = 5.0
@export var normal_rotation: float = 0.0
@export var default_rotation: float = 90.0

var target_rotation: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	# Convert degrees to radians
	var default_rad := deg_to_rad(default_rotation)
	rotation = default_rad
	target_rotation = default_rad

func _process(delta: float) -> void:
	# Update position to follow mouse
	global_position = get_global_mouse_position()
	
	# Update target rotation based on state
	_update_target_rotation()
	
	# Smoothly rotate toward target
	rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)

func _update_target_rotation() -> void:
	"""Update the target rotation based on current state"""
	if Global.MouseEnteredRadius or Global.IsDrawing:
		target_rotation = deg_to_rad(normal_rotation)
	else:
		target_rotation = deg_to_rad(default_rotation)
