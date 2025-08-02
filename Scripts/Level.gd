extends Node2D

# Main game controller - handles drawing loops that create wind vortexes for the plane
# Draw counterclockwise loops with mouse, plane gets pulled into vortexes and follows the red flow line
# Only loops affect the plane - straight lines just start the game without physics effects

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

# Old drawing cleanup system
var cleanup_timer: Timer         # Timer for removing old drawings
var old_drawing_fade_time: float = 1.0  # How long old drawings stay visible after new one

# Stamina prevents infinite drawing spam
var max_stamina: float = 100.0        
var current_stamina: float = 100.0    
var stamina_drain_rate: float = 30.0  # Drains while drawing
var stamina_regen_rate: float = 20.0  # Comes back when not drawing

# Ground level where plane crashes
var ground_level: float = 600.0

func _ready():
	setup_drawing()
	setup_cleanup_timer()
	
	# Signals are now connected through the editor instead of code
	# Go to each button in the scene and connect their "pressed" signal
	# Connect plane's "game_over" signal to _on_game_over() function

func setup_drawing():
	# Initialize the drawing system - first line will be created when needed
	pass

func setup_cleanup_timer():
	# Create timer for cleaning up old drawings
	cleanup_timer = Timer.new()
	cleanup_timer.wait_time = old_drawing_fade_time
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(_on_cleanup_old_drawings)
	add_child(cleanup_timer)

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
		
		# Start cleanup timer to remove old drawings after 1 second
		if cleanup_timer and finished_lines.size() > 1:
			cleanup_timer.start()
	
	# Send the drawn path to the plane if it's long enough
	if current_drawing.size() > 3 and plane:
		var loops = detect_loops_2()                 # Check for loops = wind physics
		if(loops > 0):
			# Create the red line connecting loop centers AFTER reparenting
			create_red_line_after_reparent()
			
			# Send loop data to the plane for wind physics (no speed changes)
			var loop_centers = get_loop_centers()  # Get the red dot positions
			var loop_directions = get_loop_flow_directions()  # Direction each loop points
			plane.set_wind_path(current_drawing, loops)  # Just for game start trigger
			plane.set_loop_centers(loop_centers)   # For suction effect
			plane.set_loop_paths(detected_loop_paths)  # For path following
			plane.set_loop_directions(loop_directions)  # Individual flow directions for each loop
		else:
			# No loops detected - just start the game if needed
			if not plane.game_started:
				plane.game_started = true

func detect_loops() -> int:
	# Simple loop detection - counts direction changes to estimate loops
	# This is the old detection method, now replaced by detect_loops_2()
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
	# NOTE: This old method is not used anymore, see detect_loops_2() instead
	loops = max(0, direction_changes / 8.0)
	return int(loops)

func detect_loops_2() -> int:
	center.clear_points()
	detected_loop_paths.clear()  # Clear previous loop paths
	
	print("=== LOOP DETECTION DEBUG ===")
	print("Drawing size: ", current_drawing.size())
	
	# Mita's loop detection algorithm - detects counterclockwise loops by finding
	# specific directional pattern: UP movement, then LEFT movement, then DOWN movement
	# Each detected pattern creates a wind vortex at the calculated loop center
	#reset direction counts
	var up_count = 0
	var left_count = 0
	var down_count = 0
	
	# Array to collect all loop centers before creating the red debug line
	var loop_centers_found = []
	
	# Variables for calculating loop area and tracking directional changes
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
	
	# Analyze each segment of the drawn line to detect directional changes
	# Look for the pattern: upward movement → leftward movement → downward movement
	var prev_x = 0
	var prev_y = 0
	for i in range(1, current_drawing.size()):
		var current_direction = (current_drawing[i] - current_drawing[i-1]).normalized()
		
		if(i > 1):
			# Detect upward movement (negative change in x direction)
			if(prev_x != 0 && current_direction.x <= 0 && ((current_direction.x / prev_x) < 0)): #UP
				up_count += 1
				up = true
				up_coords = current_screen[i]
				up_index = i
				print("UP detected at index: ", i)
			# Detect leftward movement (negative change in y direction while moving left)
			if(prev_y != 0 && current_direction.x <= 0 && (current_direction.y / prev_y) < 0): #LEFT
				left_count += 1
				left = true
				left_coords = current_screen[i]
				left_index = i
				print("LEFT detected at index: ", i)
			# Detect downward movement (positive change in x direction after going up and left)
			if(prev_x != 0 && current_direction.x >= 0 && (current_direction.x / prev_x) < 0): #DOWN
				down_count += 1
				down_index = i
				print("DOWN detected at index: ", i, " | up=", up, " left=", left)
				# When we have UP→LEFT→DOWN sequence, create a loop center and calculate area
				if up && left:
					print("CREATING LOOP CENTER!")
					down_coords = current_screen[i]
					print("UP coords: ", up_coords)
					print("LEFT coords: ", left_coords)
					print("DOWN coords: ", down_coords)
					
					# Calculate elliptical area approximation for the detected loop
					var a = up_coords.distance_to(down_coords) / 2
					var b = ((up_coords + down_coords) / 2).distance_to(left_coords)
					area += 3.1415 * a * b
					print("AREA: ", area)
					
					# Calculate the center point between up and down coordinates
					var loop_center_pos = (up_coords + down_coords) / 2
					print("Calculated loop center: ", loop_center_pos)
					loop_centers_found.append(loop_center_pos)
					
					# Extract the path segment from this loop for wind physics
					var loop_path = []
					var start_idx = min(up_index, left_index)
					var end_idx = down_index
					for j in range(start_idx, min(end_idx + 1, current_drawing.size())):
						loop_path.append(current_drawing[j])  # Use world coordinates for physics
					
					# Only store loops with enough points to be meaningful
					if loop_path.size() > 3:  # Only add meaningful loops
						detected_loop_paths.append(loop_path)
					
					# Reset flags to look for the next loop pattern
					up = false
					left = false
					
		# Track the previous direction components for comparison
		if current_direction.x != 0:
			prev_x = current_direction.x
		if current_direction.y != 0:
			prev_y = current_direction.y
	
	# Create the red debug line connecting all detected loop centers
	# This shows the overall flow direction for the wind vortex system
	if loop_centers_found.size() > 0:
		# Don't create the red line here - it will be created after reparenting
		pass
	
	# Final loop count is the minimum of all three directional changes
	# (ensures we only count complete UP→LEFT→DOWN sequences)
	loops = min(up_count, left_count, down_count)
	print("Final counts - up:", up_count, " left:", left_count, " down:", down_count)
	print("LOOPS: ", loops)
	
	# Store loop centers for later red line creation (after reparenting)
	center.clear_points()  # Clear any previous points
	if loop_centers_found.size() > 0:
		# Sort loop centers by X coordinate (left to right) for consistent flow direction
		loop_centers_found.sort_custom(func(a, b): return a.x < b.x)
		print("Sorted loop centers by X coordinate: ", loop_centers_found)
		
		for loop_center_pos in loop_centers_found:
			center.add_point(loop_center_pos)
	
	print("Loop centers found for red line: ", loop_centers_found.size())
	
	return loops

func create_red_line_after_reparent():
	# Create the red debug line connecting loop centers after drawing is reparented to world space
	# This ensures the red line coordinates match the world coordinate system
	if center.get_point_count() > 0:
		# Remove existing red line if any
		if center.get_parent():
			center.get_parent().remove_child(center)
		
		# Convert screen coordinates to world coordinates for the red line
		var world_centers = []
		var camera = get_viewport().get_camera_2d()
		
		print("=== CREATING RED LINE AFTER REPARENT ===")
		for i in range(center.get_point_count()):
			var screen_center = center.get_point_position(i)
			print("Screen center ", i, ": ", screen_center)
			
			if camera:
				var world_center = camera.global_position + (screen_center - get_viewport_rect().size * 0.5) / camera.zoom
				world_centers.append(world_center)
				print("World center ", i, ": ", world_center)
			else:
				world_centers.append(screen_center)
				print("World center ", i, " (no camera): ", screen_center)
		
		# Clear and recreate the red line with world coordinates
		center.clear_points()
		center.default_color = Color.RED
		center.width = 7
		add_child(center)  # Add to Level (world space) instead of UI
		
		# Add world coordinate points to the red line
		for world_center in world_centers:
			center.add_point(world_center)
		
		print("Red line created with ", center.get_point_count(), " world coordinate points")

func get_loop_centers() -> Array:
	# Extract the center points from the red line for loop suction physics
	# Red line is now already in world coordinates after reparenting
	var centers = []
	
	print("=== LOOP CENTERS (already in world coords) ===")
	
	for i in range(center.get_point_count()):
		var world_center = center.get_point_position(i)
		centers.append(world_center)
		print("World center ", i, ": ", world_center)
	
	print("Final loop centers for physics: ", centers)
	return centers

func get_red_line_direction() -> Vector2:
	# Calculate the overall direction of the red debug line (connecting loop centers)
	if center.get_point_count() < 2:
		return Vector2.RIGHT  # Default direction if no line
	
	# Calculate direction from first to last point of red line
	var start_point = center.get_point_position(0)
	var end_point = center.get_point_position(center.get_point_count() - 1)
	
	return (end_point - start_point).normalized()

func get_loop_flow_directions() -> Array:
	# Calculate individual flow directions for each loop pointing to the center of the next loop
	var directions = []
	
	print("=== LOOP FLOW DIRECTIONS ===")
	print("Red line point count: ", center.get_point_count())
	
	if center.get_point_count() < 2:
		# If only one or no loops, use default right direction
		print("Only one or no loops, using default directions")
		for i in range(center.get_point_count()):
			directions.append(Vector2.RIGHT)
			print("Direction ", i, ": ", Vector2.RIGHT, " (default)")
		return directions
	
	# For each loop, calculate direction from its center to the next loop's center
	for i in range(center.get_point_count()):
		if i < center.get_point_count() - 1:
			# Point from current loop center to next loop center
			var current_loop_center = center.get_point_position(i)
			var next_loop_center = center.get_point_position(i + 1)
			var direction = (next_loop_center - current_loop_center).normalized()
			directions.append(direction)
			print("Direction ", i, ": from ", current_loop_center, " to ", next_loop_center, " = ", direction)
		else:
			# For the last loop, use the overall direction or continue in same direction as previous
			if directions.size() > 0:
				directions.append(directions[directions.size() - 1])  # Same direction as previous loop
				print("Direction ", i, ": ", directions[directions.size() - 1], " (same as previous)")
			else:
				directions.append(Vector2.RIGHT)  # Fallback
				print("Direction ", i, ": ", Vector2.RIGHT, " (fallback)")
	
	print("Final flow directions: ", directions)
	return directions

func _draw():
	# Only draw the red line connecting loop centers - no debug circles or arrows
	pass

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

func _on_cleanup_old_drawings():
	# Remove all old drawings except the most recent one
	# Keep the last drawing visible, remove all others
	while finished_lines.size() > 1:
		var old_line = finished_lines[0]  # Get the oldest line
		if old_line and old_line.get_parent():
			old_line.get_parent().remove_child(old_line)
			old_line.queue_free()
		finished_lines.remove_at(0)  # Remove from array
