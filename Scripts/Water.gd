extends Area2D
class_name WaterObstacle

## Water area that slows down the plane

@export var water_speed: float = 50.0
@onready var water_audio: AudioStreamPlayer = $"../Water"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	var plane := body as PlayerPlane
	if not plane:
		return
	
	if water_audio:
		water_audio.play()
	
	plane.current_speed = water_speed
