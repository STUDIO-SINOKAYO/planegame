extends Area2D

@onready var timer = $Timer

func _on_body_entered(body):
	print("death")
	body.get_node("CollisionShape2D").queue_free()
	timer.start()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_timer_timeout():
	get_tree().reload_current_scene()
