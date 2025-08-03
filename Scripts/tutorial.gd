extends Node2D

@onready var dotted_line: Sprite2D = $"Dotted Line"
@onready var level_node: Node2D = get_parent()  # Level is the parent of Tutorial

var fade_tween: Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initially hide the dotted line (before play is pressed)
	if dotted_line:
		dotted_line.modulate.a = 0.0
		dotted_line.visible = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Check if the first line has been drawn to fade out
	if Global.game_started and dotted_line and dotted_line.modulate.a > 0.0:
		fade_out_dotted_line()

func fade_in_dotted_line() -> void:
	"""Fade in the dotted line when play button is pressed"""
	if not dotted_line:
		return
		
	# Kill any existing tween
	if fade_tween:
		fade_tween.kill()
	
	# Create fade in tween
	fade_tween = create_tween()
	fade_tween.tween_property(dotted_line, "modulate:a", 1.0, 1.0)  # Fade in over 1 second

func fade_out_dotted_line() -> void:
	"""Fade out the dotted line when first line is drawn"""
	if not dotted_line:
		return
		
	# Kill any existing tween
	if fade_tween:
		fade_tween.kill()
	
	# Create fade out tween
	fade_tween = create_tween()
	fade_tween.tween_property(dotted_line, "modulate:a", 0.0, 0.5)  # Fade out over 0.5 seconds
