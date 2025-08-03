extends BaseObstacle
class_name SolidObstacle

## Solid obstacle that crashes the plane on contact

func get_audio_player() -> AudioStreamPlayer:
	return %Crash as AudioStreamPlayer
