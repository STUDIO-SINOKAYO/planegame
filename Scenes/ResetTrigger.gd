extends Area2D

@onready var house: AnimationPlayer = $"../Obstacles/HouseSnow3/AnimationPlayer"
@onready var fire: AnimationPlayer = $"../Obstacles/Fire2/AnimationPlayer"
@onready var lightning: AnimationPlayer = $"../Obstacles/Lightning/AnimationPlayer"


func _on_body_entered(body: Node2D) -> void:
	var plane := body as PlayerPlane
	if not plane:
		return
	house.play("STAY")
	fire.play("RESET")
	lightning.play("STAY")
