extends Area2D
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
@onready var l: AnimationPlayer = $"../../Lightning/AnimationPlayer"


func _on_body_entered(body: Node2D) -> void:
	animation_player.play("fire appear")
	l.play("leave")
