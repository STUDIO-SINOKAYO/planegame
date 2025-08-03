extends Node2D

@onready var dotted_line: Sprite2D = $"Dotted Line"
@onready var tutorial_text: Sprite2D = $"Tutorial Text"
@onready var level_node: Node2D = get_parent()  # Level is the parent of Tutorial

var fade_tween: Tween
var text_fade_tween: Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initially hide the dotted line (before play is pressed)
	if dotted_line:
		dotted_line.modulate.a = 0.0
		dotted_line.visible = true
	
	# Initially hide the tutorial text (before play is pressed)
	if tutorial_text:
		tutorial_text.modulate.a = 0.0
		tutorial_text.visible = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Check if the first line has been drawn to fade out
	if Global.game_started and dotted_line and dotted_line.modulate.a > 0.0:
		fade_out_dotted_line()
	
	# Check if the first line has been drawn to fade out tutorial text
	if Global.game_started and tutorial_text and tutorial_text.modulate.a > 0.0:
		fade_out_tutorial_text()

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

func fade_in_tutorial_text() -> void:
	"""Fade in the tutorial text when play button is pressed"""
	if not tutorial_text:
		return
		
	# Kill any existing tween
	if text_fade_tween:
		text_fade_tween.kill()
	
	# Create fade in tween
	text_fade_tween = create_tween()
	text_fade_tween.tween_property(tutorial_text, "modulate:a", 1.0, 1.0)  # Fade in over 1 second

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

func fade_out_tutorial_text() -> void:
	"""Fade out the tutorial text when first line is drawn"""
	if not tutorial_text:
		return
		
	# Kill any existing tween
	if text_fade_tween:
		text_fade_tween.kill()
	
	# Create fade out tween
	text_fade_tween = create_tween()
	text_fade_tween.tween_property(tutorial_text, "modulate:a", 0.0, 0.5)  # Fade out over 0.5 seconds

func _on_play_button_pressed() -> void:
	"""Called when the play button is pressed to start the tutorial"""
	fade_in_dotted_line()
	fade_in_tutorial_text()
