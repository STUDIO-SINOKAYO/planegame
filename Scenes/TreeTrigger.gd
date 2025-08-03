extends Area2D

@onready var animation_player: AnimationPlayer = $"../../Trees/Tree4/AnimationPlayer"



func _on_body_entered(body: Node2D) -> void:
	animation_player.play("tree jumpscare")
