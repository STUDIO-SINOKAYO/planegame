extends Area2D

@onready var timer = $Timer
@onready var audio_stream_player: AudioStreamPlayer = $"../AudioStreamPlayer"

func _on_body_entered(body: Node2D) -> void:
	print("death")
	body.get_node("CollisionShape2D").queue_free()
	body.get_node("Sprite2D").region_rect = Rect2(1170, 0, 1170, 980)
	audio_stream_player.play()
	timer.start()

func _on_timer_timeout() -> void:
	get_tree().reload_current_scene()
