extends Node2D

# Target rotation for the cursor sprite
var target_rotation: float = 0.0
# Rotation speed for lerping
var rotation_speed: float = 5.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Hide the default cursor when the mouse is over the window
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	# Set initial rotation to 90 degrees (default state)
	rotation = deg_to_rad(90)
	target_rotation = deg_to_rad(90)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Make the node follow the mouse cursor position
	global_position = get_global_mouse_position()
	
	# Set target rotation based on MouseEnteredRadius
	if Global.MouseEnteredRadius or Global.IsDrawing:
		target_rotation = 0.0  # Normal rotation when in radius
	else:
		target_rotation = deg_to_rad(90)  # 90 degrees clockwise (default)
	
	# Lerp the rotation towards the target
	rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)
