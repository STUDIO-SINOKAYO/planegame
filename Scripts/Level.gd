extends Node2D

# Main game controller - handles drawing lines that turn into wind currents for the plane
# Draw with mouse, plane gets blown around by your lines instead of following them rigidly

# Node references - grabbed automatically when scene loads
@onready var plane: CharacterBody2D = $Plane
@onready var ui: CanvasLayer = $UI  # UI layer for screen-space drawing
@onready var stamina_bar: ProgressBar = $UI/StaminaContainer/StaminaBar
@onready var game_over_screen: Control = $UI/GameOverScreen
@onready var settings_button: Button = $UI/SettingsButton
@onready var restart_button: Button = $UI/GameOverScreen/RestartButton
@onready var settings_panel: Control = $UI/SettingsPanel
@onready var close_settings_button: Button = $UI/SettingsPanel/Panel/CloseButton
@onready var speed_label: Label = $UI/Statistics/SpeedLabel
@onready var altitude_label: Label = $UI/Statistics/AltitudeLabel

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
	# Put it in the UI layer so camera movement doesn't affect it
	drawn_path_line = Line2D.new()
	drawn_path_line.width = 3.0
	drawn_path_line.default_color = Color.CYAN
	drawn_path_line.joint_mode = Line2D.LINE_JOINT_ROUND
	drawn_path_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	ui.add_child(drawn_path_line)  # Add to UI layer instead of world space

func _input(event):
	if game_over:
		return
	
	# Mouse button handling
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and current_stamina > 0:
				# Use viewport mouse position for screen coordinates
				var screen_pos = get_viewport().get_mouse_position()
				# Use global mouse position for world coordinates (physics)
				var world_pos = get_global_mouse_position()
				start_drawing(screen_pos, world_pos)
			else:
				finish_drawing()
	
	# Mouse dragging
	elif event is InputEventMouseMotion:
		if is_drawing and current_stamina > 0:
			var screen_pos = get_viewport().get_mouse_position()
			var world_pos = get_global_mouse_position()
			continue_drawing(screen_pos, world_pos)

func start_drawing(screen_pos: Vector2, world_pos: Vector2):
	if current_stamina <= 0:
		return
		
	is_drawing = true
	current_drawing.clear()                    
	drawn_path_line.clear_points()             
	current_drawing.append(world_pos)          # Store world coords for physics
	drawn_path_line.add_point(screen_pos)      # Draw at screen coords for UI

func continue_drawing(screen_pos: Vector2, world_pos: Vector2):
	if current_drawing.size() == 0 or current_stamina <= 0:
		if current_stamina <= 0:
			finish_drawing()  # Auto-stop when stamina runs out
		return
	
	var last_point = current_drawing[current_drawing.size() - 1]
	var distance = world_pos.distance_to(last_point)  # Check distance in world space
	
	# Only add points that are far enough apart (keeps line smooth)
	if distance >= min_point_distance:
		current_drawing.append(world_pos)          # Store world coords for physics
		drawn_path_line.add_point(screen_pos)      # Draw at screen coords for UI       

func finish_drawing():
	is_drawing = false
	
	# Send the drawn path to the plane if it's long enough
	if current_drawing.size() > 3 and plane:
		var loops = detect_loops_2()                 # Check for loops = speed boost
		if(loops > 0):
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

func detect_loops_2() -> int:
	#loop detection mitas idea
	#reset direction counts
	var up_count = 0
	var left_count = 0
	var down_count = 0
	
	if current_drawing.size() < 10:
		return 0
	var loops = 0
	
	#go through directions
	var prev_direction = Vector2(0,0)
	var prev_x = 0
	var prev_y = 0
	for i in range(1, current_drawing.size()):
		var current_direction = (current_drawing[i] - current_drawing[i-1]).normalized()
		
		if(i > 1):
			if(prev_x != 0 && current_direction.x <= 0 && ((current_direction.x / prev_x) < 0)):
				up_count += 1
			if(prev_x != 0 && current_direction.x >= 0 && (current_direction.x / prev_x) < 0):
				down_count += 1
			if(prev_y != 0 && current_direction.x <= 0 && (current_direction.y / prev_y) < 0):
				left_count += 1
		if current_direction.x != 0:
			prev_x = current_direction.x
		if current_direction.y != 0:
			prev_y = current_direction.y
		prev_direction = current_direction
	loops = min(up_count, left_count, down_count)
	print(up_count)
	print(left_count)
	print(down_count)
	print("LOOPS: ")
	print(loops)
	
	return loops

func _process(delta):
	update_stamina(delta)      
	update_stamina_bar()   
	update_flight_info()    
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

func update_flight_info():
	# Update speed display (convert from pixels/sec to m/s for readability)
	var speed_ms = plane.velocity.length() / 100.0  # Assume 100 pixels = 1 meter cus yk
	speed_label.text = "Speed: %.1f m/s" % speed_ms
	
	# Update altitude display (higher Y = lower altitude, so invert it)
	var altitude_m = (ground_level - plane.global_position.y) / 100.0  # Convert to meters
	altitude_label.text = "Altitude: %.1f m" % max(0, altitude_m)  # Don't show negative altitude


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
