extends Area2D
class_name BaseObstacle

## Base class for all obstacle interactions
## Provides common functionality for collision handling and audio playback

@export var crash_sprite_region := Rect2(1170, 0, 1170, 980)
@export var death_timer_duration := 1.0
@export var should_stop_plane := true
@export var should_kill_plane := true

@onready var timer: Timer = $Timer
var audio_player: AudioStreamPlayer

# Cached references for better performance
var collision_shape_cache: CollisionShape2D
var sprite_cache: Sprite2D

# Override this in derived classes to specify audio player
func get_audio_player() -> AudioStreamPlayer:
	return null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	audio_player = get_audio_player()  # Get audio player after child classes are ready
	if timer:
		timer.timeout.connect(_on_timer_timeout)
		timer.wait_time = death_timer_duration

func _on_body_entered(body: Node2D) -> void:
	if not is_instance_valid(body):
		return
		
	var plane := body as PlayerPlane
	if not plane:
		return
	
	# Handle death logic
	handle_plane_death(plane)
	
	# Play audio if available
	if audio_player:
		audio_player.play()
	
	# Start timer for scene reload
	if timer:
		timer.start()

func handle_plane_death(plane: PlayerPlane) -> void:
	"""Handle the plane death sequence"""
	# Cache references for better performance (only once per plane)
	if not collision_shape_cache:
		collision_shape_cache = plane.get_node("CollisionShape2D") as CollisionShape2D
	if not sprite_cache:
		sprite_cache = plane.get_node("Sprite2D") as Sprite2D
	
	if collision_shape_cache:
		collision_shape_cache.queue_free()
	
	if sprite_cache:
		sprite_cache.region_rect = crash_sprite_region
	
	if should_stop_plane:
		plane.current_speed = 0
		
	if should_kill_plane:
		plane.dead = true

func _on_timer_timeout() -> void:
	"""Restart the game intelligently"""
	# Get the level controller to use smart restart
	var level = get_tree().get_first_node_in_group("level")
	if not level:
		level = get_node("/root/Level")  # Fallback path
	
	if level and level.has_method("restart_game_directly"):
		# Use smart restart if available
		var ui_script = level.get_node("UI")
		if ui_script and ui_script.game_has_started_once:
			level.restart_game_directly()
		else:
			get_tree().reload_current_scene()
	else:
		# Fallback to scene reload
		get_tree().reload_current_scene()
