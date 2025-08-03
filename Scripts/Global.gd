extends Node

## Global state manager for game-wide variables and settings

# Mouse and interaction state
var MouseEnteredRadius: bool = false : set = set_mouse_entered_radius
var IsDrawing: bool = false : set = set_is_drawing

# Audio player for pencil sound
var pencil_audio_player: AudioStreamPlayer

# Signals for state changes (more efficient than polling)
signal mouse_radius_changed(is_inside: bool)
signal drawing_state_changed(is_drawing: bool)

func _ready() -> void:
	# Create and configure audio player for pencil sound
	pencil_audio_player = AudioStreamPlayer.new()
	add_child(pencil_audio_player)
	
	# Load the pencil sound
	var pencil_sound = load("res://Assets/Sounds/pencil.ogg")
	pencil_audio_player.stream = pencil_sound
	
	# Set to loop
	pencil_audio_player.stream.loop = true

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
