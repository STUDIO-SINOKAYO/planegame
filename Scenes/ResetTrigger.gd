extends Area2D

@onready var fire: AnimationPlayer = $"../Obstacles/Fire2/AnimationPlayer"


func _on_body_entered(body: Node2D) -> void:
	var plane := body as PlayerPlane
	if not plane:
		return
	fire.play("RESET")
