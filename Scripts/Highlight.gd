extends Sprite2D
class_name PlaneHighlight

## Visual highlight for the plane that responds to mouse proximity and plane state

@export var target_scale: Vector2 = Vector2(0.445, 0.284)
@export var hidden_scale: Vector2 = Vector2(0.2, 0.1)
@export var scale_speed: float = 0.1
@export var distance_threshold: float = 0.01

@onready var plane: PlayerPlane = get_node("../Plane") as PlayerPlane

var is_scaling_down: bool = false
var cached_plane_dead: bool = false
var cached_mouse_state: bool = false
var cached_drawing_state: bool = false

func _ready() -> void:
	_update_cached_states()
	_update_highlight_state()

func _process(_delta: float) -> void:
	# Only update if state has changed
	if _has_state_changed():
		_update_cached_states()
		_update_highlight_state()

func _has_state_changed() -> bool:
	"""Check if any relevant state has changed since last frame"""
	var plane_dead := plane and plane.dead
	var mouse_in_radius := Global.MouseEnteredRadius
	var is_drawing := Global.IsDrawing
	
	return (plane_dead != cached_plane_dead or 
			mouse_in_radius != cached_mouse_state or 
			is_drawing != cached_drawing_state)

func _update_cached_states() -> void:
	"""Cache current states to avoid repeated property access"""
	cached_plane_dead = plane and plane.dead
	cached_mouse_state = Global.MouseEnteredRadius
	cached_drawing_state = Global.IsDrawing

func _update_highlight_state() -> void:
	"""Update highlight visibility and scale based on current state"""
	if cached_plane_dead:
		_hide_immediately()
	elif not cached_mouse_state and not cached_drawing_state:
		_scale_down_and_hide()
	else:
		_show_and_scale_up()

func _hide_immediately() -> void:
	"""Immediately hide the highlight"""
	visible = false
	scale = hidden_scale
	is_scaling_down = false

func _scale_down_and_hide() -> void:
	"""Scale down first, then hide when small enough"""
	if not is_scaling_down:
		is_scaling_down = true
		visible = true

	scale = scale.lerp(hidden_scale, scale_speed)
	
	if scale.distance_to(hidden_scale) < distance_threshold:
		visible = false

func _show_and_scale_up() -> void:
	"""Show and scale up the highlight"""
	visible = true
	is_scaling_down = false
	scale = scale.lerp(target_scale, scale_speed)
