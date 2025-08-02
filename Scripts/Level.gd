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
var finished_lines: Array = []   # Array of completed lines in world space
var current_drawing: Array = []  # Points of what you're currently drawing
var current_screen: Array = []	# Points of current drawing based on SCREEN POS
var detected_loop_paths: Array = []  # Store the paths of detected loops
var is_drawing = false           
var min_point_distance = 8.0     # Don't add points too close together
var game_over = false            
var center = Line2D.new() 		# FOR DEBUG (detect loops 2)

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
	# Initialize the drawing system - first line will be created when needed
	pass

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

func start_drawing(screen_pos: Vector2, _world_pos: Vector2):
	if current_stamina <= 0:
		return
		
	is_drawing = true
	current_drawing.clear()
	current_screen.clear()
	
	# Create a NEW line for this drawing session
	drawn_path_line = Line2D.new()
	drawn_path_line.width = 3.0
	drawn_path_line.default_color = Color.CYAN
	drawn_path_line.joint_mode = Line2D.LINE_JOINT_ROUND
	drawn_path_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	ui.add_child(drawn_path_line)  # Add to UI layer for drawing
	
	current_drawing.append(screen_pos)         # Store screen coords during drawing
	drawn_path_line.add_point(screen_pos)      # Draw at screen coords for UI
	current_screen.append(screen_pos)		# Store screen coords for debug

func continue_drawing(screen_pos: Vector2, _world_pos: Vector2):
	if current_drawing.size() == 0 or current_stamina <= 0:
		if current_stamina <= 0:
			finish_drawing()  # Auto-stop when stamina runs out
		return
	
	var last_point = current_drawing[current_drawing.size() - 1]
	var distance = screen_pos.distance_to(last_point)  # Check distance in screen space
	
	# Only add points that are far enough apart (keeps line smooth)
	if distance >= min_point_distance:
		current_drawing.append(screen_pos)         # Store screen coords during drawing
		drawn_path_line.add_point(screen_pos)      # Draw at screen coords for UI  
		current_screen.append(screen_pos)

func finish_drawing():
	is_drawing = false
	
	# Move the drawn line from UI layer back to world space for physics
	if drawn_path_line and drawn_path_line.get_parent() == ui:
		ui.remove_child(drawn_path_line)
		add_child(drawn_path_line)  # Add to Level (world space)
		
		# Convert screen coordinates to world coordinates for proper positioning
		drawn_path_line.clear_points()
		var world_coordinates = []
		for screen_point in current_drawing:
			# Convert screen coordinates to world coordinates using the camera
			var camera = get_viewport().get_camera_2d()
			if camera:
				var world_point = camera.global_position + (screen_point - get_viewport_rect().size * 0.5) / camera.zoom
				drawn_path_line.add_point(world_point)
				world_coordinates.append(world_point)
			else:
				# Fallback if no camera
				drawn_path_line.add_point(screen_point)
				world_coordinates.append(screen_point)
		
		# Update current_drawing to world coordinates for physics calculations
		current_drawing = world_coordinates
		
		# Add this line to the finished lines array
		finished_lines.append(drawn_path_line)
		drawn_path_line = null  # Clear reference so new line can be created
	
	# Send the drawn path to the plane if it's long enough
	if current_drawing.size() > 3 and plane:
		var loops = detect_loops_2()                 # Check for loops = speed boost
		if(loops > 0):
			# Send both the path and loop center positions to the plane
			var loop_centers = get_loop_centers()  # Get the red dot positions
			plane.set_wind_path(current_drawing, loops)
			plane.set_loop_centers(loop_centers)   # For suction effect
			plane.set_loop_paths(detected_loop_paths)  # For path following
			plane.set_red_line_direction(get_red_line_direction())  # For overall flow direction

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
	center.clear_points()
	detected_loop_paths.clear()  # Clear previous loop paths
	
	print("=== LOOP DETECTION DEBUG ===")
	print("Drawing size: ", current_drawing.size())
	
	#loop detection mitas idea
	#reset direction counts
	var up_count = 0
	var left_count = 0
	var down_count = 0
	
	# Array to collect all loop centers first
	var loop_centers_found = []
	
	#for calculating size
	var area = 0
	var up = false
	var left = false
	var up_coords = Vector2(0, 0)
	var left_coords = Vector2(0, 0)
	var down_coords = Vector2(0, 0)
	var up_index = 0
	var left_index = 0
	var down_index = 0
	
	if current_drawing.size() < 10:
		print("Drawing too small for loop detection")
		return 0
	var loops = 0
	
	#go through coordinates in drawing
	var prev_x = 0
	var prev_y = 0
	for i in range(1, current_drawing.size()):
		var current_direction = (current_drawing[i] - current_drawing[i-1]).normalized()
		
		if(i > 1):
			if(prev_x != 0 && current_direction.x <= 0 && ((current_direction.x / prev_x) < 0)): #UP
				up_count += 1
				up = true
				up_coords = current_screen[i]
				up_index = i
				print("UP detected at index: ", i)
			if(prev_y != 0 && current_direction.x <= 0 && (current_direction.y / prev_y) < 0): #LEFT
				left_count += 1
				left = true
				left_coords = current_screen[i]
				left_index = i
				print("LEFT detected at index: ", i)
			if(prev_x != 0 && current_direction.x >= 0 && (current_direction.x / prev_x) < 0): #DOWN
				down_count += 1
				down_index = i
				print("DOWN detected at index: ", i, " | up=", up, " left=", left)
				#Calculate and add approx. area of loop
				if up && left:
					print("CREATING LOOP CENTER!")
					down_coords = current_screen[i]
					var a = up_coords.distance_to(down_coords) / 2
					var b = ((up_coords + down_coords) / 2).distance_to(left_coords)
					area += 3.1415 * a * b
					print("AREA: ", area)
					
					# Store loop center for later
					var loop_center_pos = (up_coords + down_coords) / 2
					loop_centers_found.append(loop_center_pos)
					
					# Extract the loop path (from up point to down point)
					var loop_path = []
					var start_idx = min(up_index, left_index)
					var end_idx = down_index
					for j in range(start_idx, min(end_idx + 1, current_drawing.size())):
						loop_path.append(current_drawing[j])  # Use world coordinates for physics
					
					if loop_path.size() > 3:  # Only add meaningful loops
						detected_loop_paths.append(loop_path)
					
					up = false
					left = false
					
		if current_direction.x != 0:
			prev_x = current_direction.x
		if current_direction.y != 0:
			prev_y = current_direction.y
	
	# Now create the red line connecting all loop centers
	if loop_centers_found.size() > 0:
		center.default_color = Color.RED
		center.width = 7
		ui.add_child(center)
		
		# Add all loop center points to create a connected red line
		for loop_center_pos in loop_centers_found:
			center.add_point(loop_center_pos)
	
	loops = min(up_count, left_count, down_count)
	print("Final counts - up:", up_count, " left:", left_count, " down:", down_count)
	print("LOOPS: ", loops)
	print("Loop centers created: ", center.get_point_count())
	
	return loops

func get_loop_centers() -> Array:
	# Extract the center points from the debug line for loop suction physics
	# Convert from screen coordinates to world coordinates for plane physics
	var centers = []
	var camera = get_viewport().get_camera_2d()
	
	for i in range(center.get_point_count()):
		var screen_center = center.get_point_position(i)
		
		if camera:
			# Convert screen coordinates to world coordinates for physics
			var world_center = camera.global_position + (screen_center - get_viewport_rect().size * 0.5) / camera.zoom
			centers.append(world_center)
		else:
			# Fallback if no camera
			centers.append(screen_center)
	
	print("Loop centers for physics: ", centers)
	return centers

func get_red_line_direction() -> Vector2:
	# Calculate the overall direction of the red debug line (connecting loop centers)
	if center.get_point_count() < 2:
		return Vector2.RIGHT  # Default direction if no line
	
	# Calculate direction from first to last point of red line
	var start_point = center.get_point_position(0)
	var end_point = center.get_point_position(center.get_point_count() - 1)
	
	return (end_point - start_point).normalized()

func _draw():
	# Draw debug circles around loop centers to show force radius
	if center.get_point_count() > 0:
		print("Drawing debug circles for ", center.get_point_count(), " loop centers")
		for i in range(center.get_point_count()):
			var loop_center_screen = center.get_point_position(i)
			print("Loop center ", i, " at screen pos: ", loop_center_screen)
			
			# Since the center Line2D is in UI space, but _draw() is in world space,
			# we need to convert screen coordinates to world coordinates
			var camera = get_viewport().get_camera_2d()
			if camera:
				# Convert from UI screen coordinates to world coordinates
				var world_center = camera.global_position + (loop_center_screen - get_viewport_rect().size * 0.5) / camera.zoom
				print("Converting to world pos: ", world_center)
				
				# Draw the suction radius (larger circle) - yellow
				draw_arc(world_center, 150.0, 0, TAU, 64, Color.YELLOW, 3.0)
				
				# Draw the wind influence radius (smaller circle) - orange  
				draw_arc(world_center, 100.0, 0, TAU, 32, Color.ORANGE, 2.0)
			else:
				print("No camera found!")
				# Fallback - draw at screen coordinates directly
				draw_arc(loop_center_screen, 150.0, 0, TAU, 64, Color.YELLOW, 3.0)
				draw_arc(loop_center_screen, 100.0, 0, TAU, 32, Color.ORANGE, 2.0)

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
