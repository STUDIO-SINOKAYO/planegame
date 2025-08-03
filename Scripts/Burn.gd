extends BaseObstacle
class_name BurnObstacle

## Fire/burning obstacle that kills the plane on contact

func get_audio_player() -> AudioStreamPlayer:
	return %Burn as AudioStreamPlayer
