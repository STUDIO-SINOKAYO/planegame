extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Hide the default cursor when the mouse is over the window
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Make the node follow the mouse cursor position
	global_position = get_global_mouse_position()
