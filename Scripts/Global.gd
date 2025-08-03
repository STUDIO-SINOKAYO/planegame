extends Node

## Global state manager for game-wide variables and settings

# Mouse and interaction state
var MouseEnteredRadius: bool = false : set = set_mouse_entered_radius
var IsDrawing: bool = false : set = set_is_drawing

# Signals for state changes (more efficient than polling)
signal mouse_radius_changed(is_inside: bool)
signal drawing_state_changed(is_drawing: bool)

func set_mouse_entered_radius(value: bool) -> void:
	if MouseEnteredRadius != value:
		MouseEnteredRadius = value
		mouse_radius_changed.emit(value)

func set_is_drawing(value: bool) -> void:
	if IsDrawing != value:
		IsDrawing = value
		drawing_state_changed.emit(value)
