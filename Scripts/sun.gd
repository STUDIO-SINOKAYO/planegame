extends BaseObstacle
class_name SunObstacle

## Sun obstacle that kills the plane on contact

func get_audio_player() -> AudioStreamPlayer:
	return $AudioStreamPlayer as AudioStreamPlayer
