extends Area2D

func _on_body_entered(body: Node2D) -> void:
	print("Entered water")
	body.gravity_strength *= 10


func _on_body_exited(body: Node2D) -> void:
	print("Exited water")
	body.gravity_strength = body.gravity_strength/10
