extends Node2D

# ================================================================================================
# LEVEL CONTROLLER - Main game controller for plane drawing mechanics
# ================================================================================================
# Handles drawing loops that create wind vortexes for the plane
# Draw counterclockwise loops with mouse, plane gets pulled into vortexes and follows the red flow line
# Only loops affect the plane - straight lines just start the game without physics effects
# ================================================================================================

# === NODE REFERENCES ===
# Grabbed automatically when scene loads
@onready var plane: CharacterBody2D = $Plane
@onready var ui: CanvasLayer = $UI  # UI layer for screen-space drawing
@onready var ui_script = $UI  # Reference to UI script for restart control
@onready var stamina_bar: ProgressBar = $UI/StaminaContainer/StaminaBar
@onready var game_over_screen: Control = $UI/GameOverScreen
@onready var settings_button: Button = $UI/SettingsButton
@onready var restart_button: Button = $UI/GameOverScreen/RestartButton
@onready var settings_panel: Control = $UI/SettingsPanel
@onready var close_settings_button: Button = $UI/SettingsPanel/Panel/CloseButton
@onready var speed_label: Label = $UI/Statistics/SpeedLabel
@onready var altitude_label: Label = $UI/Statistics/AltitudeLabel



# === EXPORTED CONFIGURATION VARIABLES ===
# Drawing system settings
@export_group("Drawing Settings")
@export var min_point_distance: float = 8.0  ## Minimum distance between drawing points (pixels). Lower = smoother but more performance cost
@export var drawing_line_width: float = 3.0  ## Width of the cyan drawing line (pixels). Visual preference only
@export var drawing_line_color: Color = Color.CYAN  ## Color of the drawing line while player is drawing

# Loop detection settings
@export_group("Loop Detection")
@export var min_drawing_size_for_loops: int = 10  ## Minimum number of points needed before loop detection starts. Lower = more sensitive
@export var loop_direction_threshold: float = 0.3  ## Sensitivity for detecting direction changes (0.0-1.0). Lower = more sensitive to small turns
@export var require_loop_to_start: bool = true  ## Whether the game requires at least one loop to be drawn before the plane starts moving

# Cleanup system settings
@export_group("Drawing Cleanup")
@export var old_drawing_fade_time: float = 1.0  ## How long (seconds) before old drawings are removed automatically
@export var max_concurrent_drawings: int = 1  ## Maximum number of drawings visible at once. Higher = more visual clutter but shows drawing history
@export var max_drawable_lines: int = 3  ## Maximum total lines that can exist. When exceeded, oldest line is automatically deleted (0 = unlimited)
@export var non_loop_fade_time: float = 0.8  ## How long (seconds) before non-loop lines fade away automatically

# Stamina system settings
@export_group("Stamina System")
@export var max_stamina: float = 100.0        ## Maximum stamina available for drawing. Higher = longer drawing sessions
@export var stamina_drain_per_pixel: float = 0.1  ## How much stamina drains per pixel of line drawn. Higher = shorter drawing distance
@export var stamina_regen_rate: float = 20.0  ## How fast stamina regenerates when not drawing (per second). Higher = faster recovery
@export var low_stamina_threshold: float = 30.0  ## When stamina bar turns red as warning. Should be lower than max_stamina

# Flight display settings
@export_group("Flight Info Display")
@export var pixels_per_meter: float = 100.0  ## Conversion rate for realistic speed/altitude display. 100 pixels = 1 meter by default
@export var ground_level: float = 600.0  ## Y-coordinate where plane crashes into ground. Higher = lower crash altitude

# Waypoint system settings
@export_group("Waypoint System")
@export var plane_proximity_distance: float = 50.0  ## How close (pixels) plane needs to be to drawing to activate waypoints. Higher = easier activation

# Debug settings
@export_group("Debug")
@export var show_debug_prints: bool = true  ## Enable/disable debug console output. Turn off for release builds
@export var show_red_line: bool = true  ## Enable/disable the red debug line connecting loop centers. Visual debug aid only
@export var red_line_width: float = 7.0  ## Width of the red debug line connecting loop centers. Visual debug aid only
@export var red_line_color: Color = Color.RED  ## Color of the red debug line. Visual debug aid only

# === GAME STATE VARIABLES ===
# Drawing system variables (non-exported runtime state)
var drawn_path_line: Line2D      # The cyan line you see when drawing
var finished_lines: Array = []   # Array of completed lines in world space
var line_has_loops: Array = []   # Array tracking which finished lines have loops (same index as finished_lines)
var current_drawing: Array = []  # Points of what you're currently drawing
var current_screen: Array = []	# Points of current drawing based on SCREEN POS
var detected_loop_paths: Array = []  # Store the paths of detected loops
var is_drawing = false           
var game_over = false            
var center = Line2D.new() 		# FOR DEBUG (detect loops 2)
var loop_centers: Array = []
var waypoints: Array = []

# Runtime variables
var cleanup_timer: Timer         # Timer for removing old drawings
var current_stamina: float       # Current stamina level (initialized from max_stamina)

# ================================================================================================
# INITIALIZATION
# ================================================================================================

func _ready():
	# Add to group for easy access from other scripts
	add_to_group("level")
	
	# Initialize stamina from exported value
	current_stamina = max_stamina
	
	setup_drawing()
	setup_cleanup_timer()
	
	# Signals are now connected through the editor instead of code
	# Go to each button in the scene and connect their "pressed" signal
	# Connect plane's "game_over" signal to _on_game_over() function

# === INITIALIZATION FUNCTIONS ===

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

# === INPUT HANDLING FUNCTIONS ===

func _input(event):
	if game_over:
		return
	
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_mouse_button(event: InputEventMouseButton):
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and current_stamina > 0:
			# Use event position for consistency instead of get_mouse_position
			var screen_pos = event.position
			var world_pos = get_global_mouse_position()
			start_drawing(screen_pos, world_pos)
		else:
			finish_drawing()

func _handle_mouse_motion(event: InputEventMouseMotion):
	if is_drawing and current_stamina > 0:
		# Use event position for consistency instead of get_mouse_position  
		var screen_pos = event.position
		var world_pos = get_global_mouse_position()
		continue_drawing(screen_pos, world_pos)

# === DRAWING FUNCTIONS ===

func start_drawing(screen_pos: Vector2, world_pos: Vector2):
	if current_stamina <= 0 or not Global.MouseEnteredRadius:
		return
		
	is_drawing = true
	Global.IsDrawing = true
	current_drawing.clear()
	current_screen.clear()
	
	# Create a NEW line for this drawing session
	drawn_path_line = Line2D.new()
	drawn_path_line.width = drawing_line_width
	drawn_path_line.default_color = drawing_line_color
	drawn_path_line.joint_mode = Line2D.LINE_JOINT_ROUND
	drawn_path_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(drawn_path_line)  # Add directly to world space
	
	current_drawing.append(world_pos)         # Store world coords during drawing
	drawn_path_line.add_point(world_pos)      # Draw at world coords
	current_screen.append(screen_pos)		# Store screen coords for debug

func continue_drawing(screen_pos: Vector2, world_pos: Vector2):
	if current_drawing.size() == 0 or current_stamina <= 0:
		if current_stamina <= 0:
			finish_drawing()  # Auto-stop when stamina runs out
		return
	
	var last_point = current_drawing[current_drawing.size() - 1]
	var distance = world_pos.distance_to(last_point)  # Check distance in world space
	
	# Only add points that are far enough apart (keeps line smooth)
	if distance >= min_point_distance:
		# Drain stamina based on the distance of the line segment being drawn
		current_stamina -= distance * stamina_drain_per_pixel
		current_stamina = max(0, current_stamina)
		
		current_drawing.append(world_pos)         # Store world coords during drawing
		drawn_path_line.add_point(world_pos)      # Draw at world coords
		current_screen.append(screen_pos)
		
		# Stop drawing if stamina runs out
		if current_stamina <= 0:
			finish_drawing()

func finish_drawing():
	loop_centers = []
	is_drawing = false
	Global.IsDrawing = false
	
	if drawn_path_line:
		var loops = detect_loops_2()  # Check for loops first
		var has_loops = loops > 0
		
		_process_completed_drawing_with_loops(loops)
		
		# Add this line to the finished lines array
		finished_lines.append(drawn_path_line)
		line_has_loops.append(has_loops)  # Track if this line has loops
		
		# If this line has no loops, start immediate fade
		if not has_loops:
			_start_immediate_fade(drawn_path_line)
		
		drawn_path_line = null  # Clear reference so new line can be created
		
		# Enforce maximum drawable lines limit
		_enforce_max_drawable_lines()
		
		# Start cleanup timer to remove old drawings after specified time
		# Use the smaller of max_concurrent_drawings and max_drawable_lines (if max_drawable_lines > 0)
		var effective_max = max_concurrent_drawings
		if max_drawable_lines > 0:
			effective_max = min(max_concurrent_drawings, max_drawable_lines)
		
		if cleanup_timer and finished_lines.size() > effective_max:
			cleanup_timer.start()

func _process_completed_drawing_with_loops(loops: int):
	# Send the drawn path to the plane if it's long enough
	if current_drawing.size() > 3 and plane:
		# Check if we should start the game based on configuration
		var should_start_game = false
		if require_loop_to_start:
			# Only start if at least one loop has been detected
			should_start_game = loops > 0
		else:
			# Start on any line (original behavior)
			should_start_game = true
		
		if should_start_game and not plane.game_started:
			plane.start_game()
		
		if loops > 0:
			_handle_detected_loops(loops)
		else:
			_handle_no_loops()

func _handle_detected_loops(loops: int):
	# Send loop data to the plane for wind physics (no speed changes)
	var _loop_centers = get_loop_centers()  # Get the red dot positions
	var _loop_directions = get_loop_flow_directions()  # Direction each loop points
	plane.set_wind_path(current_drawing, loops)  # Just for game start trigger
	# plane.set_loop_centers(loop_centers)   # For suction effect
	# plane.set_loop_paths(detected_loop_paths)  # For path following
	# plane.set_loop_directions(loop_directions)  # Individual flow directions for each loop

func _handle_no_loops():
	# No loops detected - provide feedback to player if loop is required
	if require_loop_to_start and show_debug_prints:
		print("No loops detected - game will not start until a loop is drawn")
	
	# Show the draw prompt again if the game hasn't started yet and loops are required
	if require_loop_to_start and not plane.game_started:
		var draw_prompt = ui.get_node_or_null("Tutorial/DrawPrompt")
		if draw_prompt and not draw_prompt.visible:
			draw_prompt.visible = true

func _enforce_max_drawable_lines():
	"""Remove oldest lines when max_drawable_lines limit is exceeded"""
	# If max_drawable_lines is 0, allow unlimited lines
	if max_drawable_lines <= 0:
		return
		
	while finished_lines.size() > max_drawable_lines:
		_safely_remove_line_at_index(0)  # Remove oldest line (index 0)
		
		if show_debug_prints:
			print("Removed oldest line. Remaining lines: ", finished_lines.size())

func _start_immediate_fade(line: Line2D):
	"""Start immediate fade effect for a non-loop line"""
	if not line:
		return
		
	# Start fade effect immediately using a tween
	var tween = create_tween()
	if tween:
		tween.tween_property(line, "modulate:a", 0.0, non_loop_fade_time)  # Fade to transparent over non_loop_fade_time seconds
		tween.finished.connect(_on_line_fade_complete.bind(line))
		
		if show_debug_prints:
			print("Starting immediate fade effect for non-loop line over ", non_loop_fade_time, " seconds")

func _on_line_fade_complete(line: Line2D):
	"""Called when the fade effect is complete - remove the line"""
	if not line or not is_instance_valid(line):
		return
		
	# Find and remove from finished_lines array
	var index = finished_lines.find(line)
	if index >= 0:
		_safely_remove_line_at_index(index)
	
	if show_debug_prints:
		print("Non-loop line fade complete - line removed")

func _safely_remove_line_at_index(index: int):
	"""Safely remove a line and maintain array synchronization"""
	if index < 0 or index >= finished_lines.size():
		return
		
	var line = finished_lines[index]
	
	# Remove from scene
	if line and is_instance_valid(line):
		if line.get_parent():
			line.get_parent().remove_child(line)
		line.queue_free()
	
	# Remove from arrays
	finished_lines.remove_at(index)
	if index < line_has_loops.size():
		line_has_loops.remove_at(index)

# === LOOP DETECTION FUNCTIONS ===

func detect_loops() -> int:
	# Simple loop detection - counts direction changes to estimate loops
	# This is the old detection method, now replaced by detect_loops_2()
	if current_drawing.size() < min_drawing_size_for_loops:
		return 0
	
	var loops = 0
	var direction_changes = 0
	var last_direction = Vector2.ZERO
	
	for i in range(1, current_drawing.size()):
		var current_direction = (current_drawing[i] - current_drawing[i-1]).normalized()
		
		if last_direction != Vector2.ZERO:
			var angle_change = abs(last_direction.angle_to(current_direction))
			if angle_change > PI * loop_direction_threshold:  # Big direction change
				direction_changes += 1
		
		last_direction = current_direction
	
	# Rough guess: full loop = about 8 big direction changes
	# NOTE: This old method is not used anymore, see detect_loops_2() instead
	loops = max(0, direction_changes / 8.0)
	return int(loops)

func detect_loops_2() -> int:
	_reset_loop_detection()
	_print_loop_detection_debug()
	
	if current_drawing.size() < min_drawing_size_for_loops:
		if show_debug_prints:
			print("Drawing too small for loop detection")
		return 0
	
	var loop_data = _analyze_drawing_for_loops()
	var loops = _finalize_loop_detection(loop_data)
	
	return loops

func _reset_loop_detection():
	center.clear_points()
	detected_loop_paths.clear()  # Clear previous loop paths

func _print_loop_detection_debug():
	if show_debug_prints:
		print("=== LOOP DETECTION DEBUG ===")
		print("Drawing size: ", current_drawing.size())

func _analyze_drawing_for_loops() -> Dictionary:
	# Mita's loop detection algorithm - detects counterclockwise loops by finding
	# specific directional pattern: UP movement, then LEFT movement, then DOWN movement
	# Each detected pattern creates a wind vortex at the calculated loop center
	
	var loop_data = {
		"up_count": 0,
		"left_count": 0,
		"down_count": 0,
		"loop_centers_found": [],
		"area": 0
	}
	
	# Variables for tracking directional changes
	var directional_state = _create_directional_state()
	var prev_direction = Vector2.ZERO
	
	# Analyze each segment of the drawn line to detect directional changes
	for i in range(1, current_drawing.size()):
		var current_direction = (current_drawing[i] - current_drawing[i-1]).normalized()
		
		if i > 1:
			_check_directional_changes(i, current_direction, prev_direction, directional_state, loop_data)
		
		# Track the previous direction components for comparison
		prev_direction = _update_previous_direction(current_direction, prev_direction)
	
	return loop_data

func _create_directional_state() -> Dictionary:
	return {
		"up": false,
		"left": false,
		"up_coords": Vector2.ZERO,
		"up_coords_global": Vector2.ZERO,
		"left_coords": Vector2.ZERO,
		"down_coords": Vector2.ZERO,
		"down_coords_global": Vector2.ZERO,
		"up_index": 0,
		"left_index": 0,
		"down_index": 0
	}

func _check_directional_changes(i: int, current_direction: Vector2, prev_direction: Vector2, directional_state: Dictionary, loop_data: Dictionary):
	# Detect upward movement (negative change in x direction)
	if _is_upward_movement(current_direction, prev_direction):
		_handle_upward_movement(i, directional_state, loop_data)
	
	# Detect leftward movement (negative change in y direction while moving left)
	if _is_leftward_movement(current_direction, prev_direction):
		_handle_leftward_movement(i, directional_state, loop_data)
	
	# Detect downward movement (positive change in x direction after going up and left)
	if _is_downward_movement(current_direction, prev_direction):
		_handle_downward_movement(i, directional_state, loop_data)

func _is_upward_movement(current_direction: Vector2, prev_direction: Vector2) -> bool:
	return prev_direction.x != 0 && current_direction.x <= 0 && ((current_direction.x / prev_direction.x) < 0)

func _is_leftward_movement(current_direction: Vector2, prev_direction: Vector2) -> bool:
	return prev_direction.y != 0 && current_direction.x <= 0 && (current_direction.y / prev_direction.y) < 0

func _is_downward_movement(current_direction: Vector2, prev_direction: Vector2) -> bool:
	return prev_direction.x != 0 && current_direction.x >= 0 && (current_direction.x / prev_direction.x) < 0

func _handle_upward_movement(i: int, directional_state: Dictionary, loop_data: Dictionary):
	loop_data.up_count += 1
	directional_state.up = true
	directional_state.up_coords = current_screen[i]
	directional_state.up_coords_global = current_drawing[i]
	directional_state.up_index = i
	if show_debug_prints:
		print("UP detected at index: ", i)

func _handle_leftward_movement(i: int, directional_state: Dictionary, loop_data: Dictionary):
	loop_data.left_count += 1
	directional_state.left = true
	directional_state.left_coords = current_screen[i]
	directional_state.left_index = i
	if show_debug_prints:
		print("LEFT detected at index: ", i)

func _handle_downward_movement(i: int, directional_state: Dictionary, loop_data: Dictionary):
	loop_data.down_count += 1
	directional_state.down_index = i
	directional_state.down_coords_global = current_drawing[i]
	if show_debug_prints:
		print("DOWN detected at index: ", i, " | up=", directional_state.up, " left=", directional_state.left)
	
	# When we have UP→LEFT→DOWN sequence, create a loop center and calculate area
	if directional_state.up && directional_state.left:
		_create_loop_from_sequence(i, directional_state, loop_data)

func _create_loop_from_sequence(i: int, directional_state: Dictionary, loop_data: Dictionary):
	if show_debug_prints:
		print("CREATING LOOP CENTER!")
	directional_state.down_coords = current_screen[i]
	if show_debug_prints:
		print("UP coords: ", directional_state.up_coords)
		print("LEFT coords: ", directional_state.left_coords)
		print("DOWN coords: ", directional_state.down_coords)
	
	# Calculate elliptical area approximation for the detected loop using world coordinates
	var a = directional_state.up_coords_global.distance_to(directional_state.down_coords_global) / 2
	var b = ((directional_state.up_coords_global + directional_state.down_coords_global) / 2).distance_to(current_drawing[directional_state.left_index])
	loop_data.area += 3.1415 * a * b
	if show_debug_prints:
		print("AREA: ", loop_data.area)
	
	# Calculate the center point between up and down coordinates in world space
	var loop_center_pos = (directional_state.up_coords_global + directional_state.down_coords_global) / 2
	if show_debug_prints:
		print("Calculated loop center: ", loop_center_pos)
	loop_data.loop_centers_found.append(loop_center_pos)
	loop_centers.append(loop_center_pos)
	
	# Extract the path segment from this loop for wind physics
	_extract_loop_path(directional_state)
	
	# Reset flags to look for the next loop pattern
	directional_state.up = false
	directional_state.left = false

func _extract_loop_path(directional_state: Dictionary):
	var loop_path = []
	var start_idx = min(directional_state.up_index, directional_state.left_index)
	var end_idx = directional_state.down_index
	for j in range(start_idx, min(end_idx + 1, current_drawing.size())):
		loop_path.append(current_drawing[j])  # Use world coordinates for physics
	
	# Only store loops with enough points to be meaningful
	if loop_path.size() > 3:  # Only add meaningful loops
		detected_loop_paths.append(loop_path)

func _update_previous_direction(current_direction: Vector2, prev_direction: Vector2) -> Vector2:
	var updated_prev = prev_direction
	if current_direction.x != 0:
		updated_prev.x = current_direction.x
	if current_direction.y != 0:
		updated_prev.y = current_direction.y
	return updated_prev

func _finalize_loop_detection(loop_data: Dictionary) -> int:
	_create_red_line_centers(loop_data.loop_centers_found)
	
	# Final loop count is the minimum of all three directional changes
	# (ensures we only count complete UP→LEFT→DOWN sequences)
	var loops = min(loop_data.up_count, loop_data.left_count, loop_data.down_count)
	if show_debug_prints:
		print("Final counts - up:", loop_data.up_count, " left:", loop_data.left_count, " down:", loop_data.down_count)
		print("LOOPS: ", loops)
		print("Loop centers found for red line: ", loop_centers.size())
	
	return loops

func _create_red_line_centers(loop_centers_found: Array):
	# Create the red debug line connecting all detected loop centers
	# This shows the overall flow direction for the wind vortex system
	if loop_centers_found.size() > 0 and show_red_line:
		# Clear any previous points
		center.clear_points()
		center.default_color = red_line_color
		center.width = red_line_width
		add_child(center)  # Add to Level (world space)
		
		# Sort loop centers by X coordinate (left to right) for consistent flow direction
		loop_centers_found.sort_custom(func(a, b): return a.x < b.x)
		if show_debug_prints:
			print("Sorted loop centers by X coordinate: ", loop_centers_found)
		
		# Add world coordinate points directly to the red line
		for loop_center_pos in loop_centers_found:
			center.add_point(loop_center_pos)
		
		if show_debug_prints:
			print("Red line created with ", center.get_point_count(), " world coordinate points")
	elif not show_red_line:
		# If red line is disabled, clear any existing points but still store loop centers
		center.clear_points()
		if show_debug_prints:
			print("Red line disabled - not creating visual line")

func get_loop_centers() -> Array:
	# Extract the center points from the red line for loop suction physics
	# Red line is already in world coordinates
	var centers = []
	
	if show_debug_prints:
		print("=== LOOP CENTERS (world coords) ===")
	
	for i in range(center.get_point_count()):
		var world_center = center.get_point_position(i)
		centers.append(world_center)
		if show_debug_prints:
			print("World center ", i, ": ", world_center)
	
	if show_debug_prints:
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
	
	if show_debug_prints:
		print("=== LOOP FLOW DIRECTIONS ===")
		print("Red line point count: ", center.get_point_count())
	
	if center.get_point_count() < 2:
		# If only one or no loops, use default right direction
		if show_debug_prints:
			print("Only one or no loops, using default directions")
		for i in range(center.get_point_count()):
			directions.append(Vector2.RIGHT)
			if show_debug_prints:
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
			if show_debug_prints:
				print("Direction ", i, ": from ", current_loop_center, " to ", next_loop_center, " = ", direction)
		else:
			# For the last loop, use the overall direction or continue in same direction as previous
			if directions.size() > 0:
				directions.append(directions[directions.size() - 1])  # Same direction as previous loop
				if show_debug_prints:
					print("Direction ", i, ": ", directions[directions.size() - 1], " (same as previous)")
			else:
				directions.append(Vector2.RIGHT)  # Fallback
				if show_debug_prints:
					print("Direction ", i, ": ", Vector2.RIGHT, " (fallback)")
	
	if show_debug_prints:
		print("Final flow directions: ", directions)
	return directions

# === RENDERING FUNCTION ===

func _draw():
	# Only draw the red line connecting loop centers - no debug circles or arrows
	pass

# === MAIN PROCESS FUNCTION ===

func _process(delta):
	update_stamina(delta)      
	update_stamina_bar()   
	update_flight_info()    
	create_plane_waypoints()
	queue_redraw()

# === UI UPDATE FUNCTIONS ===

func update_stamina(delta):
	# Only regenerate stamina when not drawing - draining is now handled in continue_drawing()
	if not is_drawing and current_stamina < max_stamina:
		current_stamina += stamina_regen_rate * delta
		current_stamina = min(max_stamina, current_stamina)

func update_stamina_bar():
	# Update the progress bar and change color based on stamina
	stamina_bar.value = current_stamina
	
	var style = StyleBoxFlat.new()
	if current_stamina > low_stamina_threshold:
		style.bg_color = Color.GREEN  # Good stamina
	else:
		style.bg_color = Color.RED    # Low stamina warning
	
	stamina_bar.add_theme_stylebox_override("fill", style)

func update_flight_info():
	_update_speed_display()
	_update_altitude_display()

func _update_speed_display():
	# Update speed display (convert from pixels/sec to m/s for readability)
	var speed_ms = plane.velocity.length() / pixels_per_meter  # Convert pixels to meters
	speed_label.text = "Speed: %.1f m/s" % speed_ms

func _update_altitude_display():
	# Update altitude display (higher Y = lower altitude, so invert it)
	var altitude_m = (ground_level - plane.global_position.y) / pixels_per_meter  # Convert to meters
	altitude_label.text = "Altitude: %.1f m" % max(0, altitude_m)  # Don't show negative altitude

# === PLANE WAYPOINT FUNCTIONS ===

func create_plane_waypoints():
	if _is_plane_near_drawing():
		_add_loop_centers_to_waypoints()
		_start_first_waypoint()
		_reset_loop_centers()

func _is_plane_near_drawing() -> bool:
	for i in range(0, current_drawing.size()):
		if plane.position.distance_to(current_drawing[i]) < plane_proximity_distance:
			return true
	return false

func _add_loop_centers_to_waypoints():
	for i in range(0, loop_centers.size()):
		waypoints.append(loop_centers[i])

func _start_first_waypoint():
	# Start first waypoint
	if loop_centers.size() > 0:
		plane.create_waypoint_at_position(waypoints.pop_front())

func _reset_loop_centers():
	# Reset loop_centers
	loop_centers = []

# === BUTTON CALLBACKS ===

func _on_game_over():
	game_over = true
	game_over_screen.visible = true

func _on_settings_pressed():
	settings_panel.visible = true

func _on_close_settings_pressed():
	settings_panel.visible = false

func _on_restart_pressed():
	# Smart restart: check if game has started before
	if ui_script.game_has_started_once:
		# Quick restart without tutorial/start screen
		restart_game_directly()
	else:
		# First time, do full scene reload
		get_tree().reload_current_scene()

func restart_game_directly():
	"""Restart the game without tutorial or start screen"""
	# Reset game state
	game_over = false
	current_stamina = max_stamina
	
	# Clear all drawings
	clear_all_drawings()
	
	# Reset plane
	plane.reset_plane()
	
	# Reset UI
	ui_script.start_game_directly()
	game_over_screen.hide()
	stamina_bar.value = max_stamina
	
	# Reset any other game state as needed
	setup_drawing()

func clear_all_drawings():
	"""Clear all existing drawings from the scene"""
	# Clear current drawing arrays
	current_drawing.clear()
	current_screen.clear()
	
	# Remove all finished lines from scene
	for line in finished_lines:
		if is_instance_valid(line):
			line.queue_free()
	finished_lines.clear()
	line_has_loops.clear()  # Clear loop tracking array
	
	# Clear current drawn line if it exists
	if drawn_path_line:
		drawn_path_line.queue_free()
		drawn_path_line = null
	
	# Reset loop detection
	_reset_loop_detection()

func _on_cleanup_old_drawings():
	# Remove old drawings to stay within max_concurrent_drawings limit
	# Keep the most recent drawings visible, remove oldest ones
	# Also enforce max_drawable_lines limit if it's set (> 0)
	var effective_max = max_concurrent_drawings
	if max_drawable_lines > 0:
		effective_max = min(max_concurrent_drawings, max_drawable_lines)
	
	while finished_lines.size() > effective_max:
		_safely_remove_line_at_index(0)  # Remove oldest line (index 0)


func _on_plane_waypoint_reached(_pos: Vector2) -> void:
	if waypoints.size() > 0:
		plane.create_waypoint_at_position(waypoints.pop_front())
