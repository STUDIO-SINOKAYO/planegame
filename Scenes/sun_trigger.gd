extends Area2D
@onready var animation_player: AnimationPlayer = $"../Sun/AnimationPlayer"


func _on_body_entered(body: Node2D) -> void:
	var plane := body as PlayerPlane
	if not plane:
		return
	animation_player.play("sun jumpscare")
	
