extends Node2D

# Main game controller - handles drawing lines that turn into wind currents for the plane
# Draw with mouse, plane gets blown around by your lines instead of following them rigidly

# Node references - grabbed automatically when scene loads
@onready var plane: CharacterBody2D = $Plane
@onready var stamina_bar: ProgressBar = $UI/StaminaContainer/StaminaBar
@onready var game_over_screen: Control = $UI/GameOverScreen
@onready var settings_button: Button = $UI/SettingsButton
@onready var restart_button: Button = $UI/GameOverScreen/RestartButton
@onready var settings_panel: Control = $UI/SettingsPanel
@onready var close_settings_button: Button = $UI/SettingsPanel/Panel/CloseButton

# Drawing stuff
var drawn_path_line: Line2D      # The cyan line you see when drawing
var current_drawing: Array = []  # Points of what you're currently drawing
var is_drawing = false           
var min_point_distance = 8.0     # Don't add points too close together
var game_over = false            

# Stamina prevents infinite drawing spam
var max_stamina: float = 100.0        
var current_stamina: float = 100.0    
var stamina_drain_rate: float = 30.0  # Drains while drawing
var stamina_regen_rate: float = 20.0  # Comes back when not drawing

# Ground level where plane crashes
var ground_level: float = 600.0

func _ready():
	setup_drawing()
	
	# Signals are now connected through the editor instead of code
	# Go to each button in the scene and connect their "pressed" signal
	# Connect plane's "game_over" signal to _on_game_over() function

func setup_drawing():
	# Create the cyan line that shows your drawing
	drawn_path_line = Line2D.new()
	drawn_path_line.width = 3.0
	drawn_path_line.default_color = Color.CYAN
	drawn_path_line.joint_mode = Line2D.LINE_JOINT_ROUND
	drawn_path_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(drawn_path_line)

func _input(event):
	if game_over:
		return
	
	# Mouse button handling
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and current_stamina > 0:
				# Important: get_global_mouse_position() works with cameras
				var world_pos = get_global_mouse_position()
				start_drawing(world_pos)
			else:
				finish_drawing()
	
	# Mouse dragging
	elif event is InputEventMouseMotion:
		if is_drawing and current_stamina > 0:
			var world_pos = get_global_mouse_position()
			continue_drawing(world_pos)

func start_drawing(mouse_pos: Vector2):
	if current_stamina <= 0:
		return
		
	is_drawing = true
	current_drawing.clear()                    
	drawn_path_line.clear_points()             
	current_drawing.append(mouse_pos)          
	drawn_path_line.add_point(mouse_pos)       

func continue_drawing(mouse_pos: Vector2):
	if current_drawing.size() == 0 or current_stamina <= 0:
		if current_stamina <= 0:
			finish_drawing()  # Auto-stop when stamina runs out
		return
	
	var last_point = current_drawing[current_drawing.size() - 1]
	var distance = mouse_pos.distance_to(last_point)
	
	# Only add points that are far enough apart (keeps line smooth)
	if distance >= min_point_distance:
		current_drawing.append(mouse_pos)          
		drawn_path_line.add_point(mouse_pos)       

func finish_drawing():
	is_drawing = false
	
	# Send the drawn path to the plane if it's long enough
	if current_drawing.size() > 3 and plane:
		var loops = detect_loops()                 # Check for loops = speed boost
		plane.set_wind_path(current_drawing, loops)

func detect_loops() -> int:
	# Simple loop detection - counts direction changes to estimate loops
	# More loops = more speed for the plane
	if current_drawing.size() < 10:
		return 0
	
	var loops = 0
	var direction_changes = 0
	var last_direction = Vector2.ZERO
	
	for i in range(1, current_drawing.size()):
		var current_direction = (current_drawing[i] - current_drawing[i-1]).normalized()
		
		if last_direction != Vector2.ZERO:
			var angle_change = abs(last_direction.angle_to(current_direction))
			if angle_change > PI * 0.3:  # Big direction change (~54 degrees)
				direction_changes += 1
		
		last_direction = current_direction
	
	# Rough guess: full loop = about 8 big direction changes
	loops = max(0, direction_changes / 8.0)
	return int(loops)

func _process(delta):
	update_stamina(delta)      
	update_stamina_bar()       
	queue_redraw()             

func update_stamina(delta):
	# Drain stamina while drawing, regen when not
	if is_drawing and current_stamina > 0:
		current_stamina -= stamina_drain_rate * delta
		current_stamina = max(0, current_stamina)
	elif not is_drawing and current_stamina < max_stamina:
		current_stamina += stamina_regen_rate * delta
		current_stamina = min(max_stamina, current_stamina)

func update_stamina_bar():
	# Update the progress bar and change color based on stamina
	stamina_bar.value = current_stamina
	
	var style = StyleBoxFlat.new()
	if current_stamina > 30:
		style.bg_color = Color.GREEN  # Good stamina
	else:
		style.bg_color = Color.RED    # Low stamina warning
	
	stamina_bar.add_theme_stylebox_override("fill", style)

# Button callbacks
func _on_game_over():
	game_over = true
	game_over_screen.visible = true

func _on_settings_pressed():
	settings_panel.visible = true

func _on_close_settings_pressed():
	settings_panel.visible = false

func _on_restart_pressed():
	# Just reload the whole scene, easiest way to reset everything
	get_tree().reload_current_scene()

func restart_game():
	# Internal reset function, not used by main restart button
	game_over = false
	game_over_screen.visible = false
	current_stamina = max_stamina              
	current_drawing.clear()                    
	drawn_path_line.clear_points()             
	plane.global_position = Vector2(100, 200)  
	plane.velocity = Vector2.ZERO              
	plane.reset_plane()
