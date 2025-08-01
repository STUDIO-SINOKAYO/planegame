extends Node2D

@onready var plane: CharacterBody2D = $Plane
var drawn_path_line: Line2D
var current_drawing: Array = []
var is_drawing = false
var min_point_distance = 10.0  # Minimum distance between path points

func _ready():
	setup_drawing()

func setup_drawing():
	# Create line for drawing path
	drawn_path_line = Line2D.new()
	drawn_path_line.width = 4.0
	drawn_path_line.default_color = Color.GREEN
	drawn_path_line.joint_mode = Line2D.LINE_JOINT_ROUND
	drawn_path_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(drawn_path_line)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drawing(event.position)
			else:
				finish_drawing()
	
	elif event is InputEventMouseMotion:
		if is_drawing:
			continue_drawing(event.position)

# Keep the old _input function commented for testing
# func _input(event):

func start_drawing(mouse_pos: Vector2):
	"""Start drawing a new path"""
	is_drawing = true
	current_drawing.clear()
	drawn_path_line.clear_points()
	current_drawing.append(mouse_pos)
	drawn_path_line.add_point(mouse_pos)
	
	# Reset plane
	if plane:
		plane.reset_plane()

func continue_drawing(mouse_pos: Vector2):
	"""Continue drawing the path"""
	if current_drawing.size() == 0:
		return
	
	var last_point = current_drawing[current_drawing.size() - 1]
	var distance = mouse_pos.distance_to(last_point)
	
	# Only add point if it's far enough from the last one
	if distance >= min_point_distance:
		current_drawing.append(mouse_pos)
		drawn_path_line.add_point(mouse_pos)

func finish_drawing():
	"""Finish drawing and make plane follow the path"""
	is_drawing = false
	
	if current_drawing.size() > 1 and plane:
		# Make plane follow the drawn path
		plane.set_path(current_drawing)

func _process(_delta):
	queue_redraw()

func _draw():
	pass
