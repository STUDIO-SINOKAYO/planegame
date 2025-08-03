extends CanvasLayer

@onready var camera: Camera2D = $"../Plane/Camera2D"
@onready var plane: PlayerPlane = $"../Plane"
@onready var start_screen: Control = $StartScreen
@onready var cursor: Node2D = $"../Cursor"
@onready var draw_prompt: RichTextLabel = $Tutorial/DrawPrompt

var camera_tween: Tween

func _ready() -> void:
	camera.position = Vector2.ZERO
	# Create tween for smooth camera transitions
	camera_tween = create_tween()
	camera_tween.kill()  # Stop it initially
	
	# Check if we should skip the start screen entirely
	if Global.should_skip_tutorial():
		start_game_directly()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if draw_prompt.visible:
			# Hide the draw prompt when the player clicks
			draw_prompt.hide()

func _on_play_button_pressed() -> void:
	start_screen.hide()
	cursor.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	# Mark that the game has been played
	Global.mark_game_as_played()
	
	# Smooth camera transition
	camera_tween = create_tween()
	camera_tween.tween_property(camera, "position", Vector2(260, -50), 3.0)
	camera_tween.set_ease(Tween.EASE_OUT)
	camera_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Show draw prompt after tween is over (Godot 4 syntax)
	camera_tween.finished.connect(_on_camera_tween_completed)

func _on_camera_tween_completed() -> void:
	draw_prompt.show()

func start_game_directly() -> void:
	"""Start the game without tutorial or start screen (for restarts)"""
	# Ensure start screen is hidden
	if start_screen:
		start_screen.hide()
	
	# Ensure draw prompt is hidden
	if draw_prompt:
		draw_prompt.hide()
	
	# Show cursor
	if cursor:
		cursor.show()
	
	# Set mouse mode
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	# Set camera position immediately
	if camera:
		camera.position = Vector2(260, -50)
