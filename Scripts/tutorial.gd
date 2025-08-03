extends Node2D

@onready var dotted_line: Sprite2D = $"Dotted Line"
@onready var level_node: Node2D = get_parent()  # Level is the parent of Tutorial

var fade_tween: Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Tutorial _ready() called")
	print("game_has_been_played_before: ", Global.game_has_been_played_before)
	print("dotted_line exists: ", dotted_line != null)
	
	# Check if game has been played before - if so, stay invisible
	if Global.game_has_been_played_before:
		print("Game has been played before - hiding dotted line")
		if dotted_line:
			dotted_line.visible = false
		return
	
	# Initially hide the dotted line (before play is pressed)
	if dotted_line:
		dotted_line.modulate.a = 1.0  # Start visible for testing
		dotted_line.visible = true
		print("Dotted line initialized - visible: ", dotted_line.visible, " alpha: ", dotted_line.modulate.a)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Check if the first line has been drawn to fade out
	if Global.game_started and dotted_line and dotted_line.modulate.a > 0.0:
		fade_out_dotted_line()

func fade_in_dotted_line() -> void:
	"""Fade in the dotted line when play button is pressed"""
	print("fade_in_dotted_line() called")
	print("dotted_line exists: ", dotted_line != null)
	print("game_has_been_played_before: ", Global.game_has_been_played_before)
	
	if not dotted_line or Global.game_has_been_played_before:
		print("Exiting early - dotted_line: ", dotted_line != null, " played_before: ", Global.game_has_been_played_before)
		return
		
	print("Starting fade in - current alpha: ", dotted_line.modulate.a)
	
	# Kill any existing tween
	if fade_tween:
		fade_tween.kill()
	
	# Create fade in tween
	fade_tween = create_tween()
	fade_tween.tween_property(dotted_line, "modulate:a", 1.0, 1.0)  # Fade in over 1 second

func fade_out_dotted_line() -> void:
	"""Fade out the dotted line when first line is drawn"""
	if not dotted_line or Global.game_has_been_played_before:
		return
		
	# Kill any existing tween
	if fade_tween:
		fade_tween.kill()
	
	# Create fade out tween
	fade_tween = create_tween()
	fade_tween.tween_property(dotted_line, "modulate:a", 0.0, 0.5)  # Fade out over 0.5 seconds
