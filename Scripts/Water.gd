extends Area2D
@onready var water: AudioStreamPlayer = $"../Water"

func _on_body_entered(body: Node2D) -> void:
	print("Entered water")
	water.play()
	body.current_speed = 20
