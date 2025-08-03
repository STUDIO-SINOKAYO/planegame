extends BaseObstacle
class_name SunObstacle

## Sun obstacle that kills the plane on contact

func get_audio_player() -> AudioStreamPlayer:
	return $AudioStreamPlayer as AudioStreamPlayer

# Override timer timeout to always use scene reload for sun (most reliable)
func _on_timer_timeout() -> void:
	"""Always use scene reload for sun crashes (most reliable)"""
	get_tree().reload_current_scene()
