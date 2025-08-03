extends Area2D
class_name CursorDetection

## Detects when mouse cursor enters/exits the plane's interaction radius

# Signal for other objects to listen to
signal mouse_radius_changed(is_inside: bool)

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	Global.MouseEnteredRadius = true
	mouse_radius_changed.emit(true)

func _on_mouse_exited() -> void:
	Global.MouseEnteredRadius = false
	mouse_radius_changed.emit(false)
