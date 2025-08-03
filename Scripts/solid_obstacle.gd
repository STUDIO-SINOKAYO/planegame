extends Area2D

@onready var timer = $Timer

func _on_body_entered(body):
	print("death")
	body.get_node("CollisionShape2D").queue_free()
	body.current_speed = 0
	body.get_node("Sprite2D").region_rect = Vector4(1170, 0, 1170, 980)
	body.dead = true
	timer.start()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_timer_timeout():
	get_tree().reload_current_scene()
