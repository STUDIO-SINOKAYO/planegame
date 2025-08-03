extends Node

## Global state manager for game-wide variables and settings

# Mouse and interaction state
var MouseEnteredRadius: bool = false : set = set_mouse_entered_radius
var IsDrawing: bool = false : set = set_is_drawing

# Game state tracking - simple and reliable
var game_has_been_played_before: bool = false

# Audio control
var waypoint_sound_enabled: bool = true  ## Global control for waypoint sound

# Audio player for pencil sound
var pencil_audio_player: AudioStreamPlayer

# Signals for state changes (more efficient than polling)
signal mouse_radius_changed(is_inside: bool)
signal drawing_state_changed(is_drawing: bool)

func _ready() -> void:
	# Reset game state on every launch (always show tutorial)
	reset_game_state()
	
	# Load game state from user preferences (will be false after reset)
	load_game_state()
	
	# Create and configure audio player for pencil sound
	pencil_audio_player = AudioStreamPlayer.new()
	add_child(pencil_audio_player)
	
	# Load the pencil sound
	var pencil_sound = load("res://Assets/Sounds/pencil.ogg")
	pencil_audio_player.stream = pencil_sound
	
	# Set to loop
	pencil_audio_player.stream.loop = true

func _input(event: InputEvent) -> void:
	# Debug: Press R to reset game state (for testing)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R and event.ctrl_pressed:
			print("Resetting game state...")
			reset_game_state()
			get_tree().reload_current_scene()

func mark_game_as_played() -> void:
	"""Mark that the player has played the game at least once"""
	if not game_has_been_played_before:
		game_has_been_played_before = true
		save_game_state()

func should_skip_tutorial() -> bool:
	"""Check if we should skip the tutorial and start screen"""
	return game_has_been_played_before

func reset_game_state() -> void:
	"""Reset game state - useful for testing or giving players a fresh start"""
	game_has_been_played_before = false
	save_game_state()

func save_game_state() -> void:
	"""Save game state to user preferences (works on web)"""
	var config = ConfigFile.new()
	config.set_value("game", "has_been_played", game_has_been_played_before)
	config.save("user://game_state.cfg")

func load_game_state() -> void:
	"""Load game state from user preferences"""
	var config = ConfigFile.new()
	if config.load("user://game_state.cfg") == OK:
		game_has_been_played_before = config.get_value("game", "has_been_played", false)

func set_mouse_entered_radius(value: bool) -> void:
	if MouseEnteredRadius != value:
		MouseEnteredRadius = value
		mouse_radius_changed.emit(value)

func set_is_drawing(value: bool) -> void:
	if IsDrawing != value:
		IsDrawing = value
		drawing_state_changed.emit(value)
		
		# Play or stop pencil sound based on drawing state
		if value:
			# Start playing the looping pencil sound
			if pencil_audio_player:
				pencil_audio_player.play()
		else:
			# Stop the pencil sound when not drawing
			if pencil_audio_player:
				pencil_audio_player.stop()
