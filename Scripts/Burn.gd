extends BaseObstacle
class_name BurnObstacle

## Burning obstacle that ignites the plane on contact

func get_audio_player() -> AudioStreamPlayer:
	# Find the Burn audio player in the level scene
	# Try multiple methods to find the level node
	var level = get_tree().get_first_node_in_group("level")
	if not level:
		# Alternative: go up the tree to find the root scene
		level = get_tree().current_scene
	if level:
		var burn_player = level.get_node_or_null("Burn") as AudioStreamPlayer
		return burn_player
	return null
