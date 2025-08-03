extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect the area signals to our functions
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


# Called when mouse enters the area
func _on_mouse_entered() -> void:
	Global.MouseEnteredRadius = true
	print("DEBUG: Mouse entered radius - MouseEnteredRadius set to true")


# Called when mouse exits the area
func _on_mouse_exited() -> void:
	Global.MouseEnteredRadius = false
	print("DEBUG: Mouse exited radius - MouseEnteredRadius set to false")
