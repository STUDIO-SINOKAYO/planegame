extends CharacterBody2D
class_name PlayerPlane

# Movement and Physics Parameters
@export_group("Movement")
@export var base_speed: float = 0.0 ## Starting speed when the game begins
@export var max_speed: float = 600.0 ## Maximum speed the plane can reach
@export var speed_acceleration: float = 10.0 ## How quickly the plane accelerates when pointing downward
@export var speed_deceleration: float = 2.0 ## How quickly the plane slows down when pointing upward
@export var boost_speed: float = 600.0 ## Speed applied when using right-click boost
@export var rotation_speed: float = 0.5 ## How slowly the plane rotates toward its velocity
@export var velocity_rotation_multiplier: float = 1.0 ## Multiplier for rotation speed based on velocity magnitude

@export_group("Physics")
@export var gravity_strength: float = 300.0 ## How strong gravity affects the plane when pointing upward
@export var gravity_damping: float = 0.98 ## Reduces gravity velocity over time (0.0-1.0)
@export var max_upward_angle: float = 0.2 ## Maximum upward angle before gravity kicks in
@export var terminal_velocity: float = 500.0 ## Maximum speed from gravity alone

@export_group("Wind System")
@export var wind_influence_radius: float = 100.0 ## Distance from wind points where the plane is affected
@export var wind_force_strength: float = 800.0 ## Strength of wind forces applied to the plane
@export var loop_speed_multiplier: float = 50.0 ## Speed bonus multiplier for completing loops
@export var lift_power: float = 100.0 ## Additional lift force from wind effects

@export_group("Velocity Visualization")
@export var show_velocity_line: bool = false ## Whether to display the velocity direction line
@export var velocity_line_scale: float = 0.5 ## Scale factor for the velocity visualization line
@export var velocity_line_color: Color = Color.RED ## Color of the velocity direction line
@export var velocity_line_width: float = 3.0 ## Width of the velocity direction line in pixels

@export_group("Waypoint System")
@export var show_waypoint_visual: bool = false ## Whether to display the waypoint visual indicator
@export var enable_debug_waypoint_click: bool = false ## Enable right-click to create waypoints for debugging
@export var waypoint_reach_threshold: float = 50.0 ## Distance threshold to consider waypoint reached

@export_group("Game Settings")
@export var ground_level: float = 600.0 ## Y position where the ground is located (game over point)

# Internal state variables
var wind_points: Array = []
var current_speed: float = 0.0
var loop_count: int = 0
var game_started: bool = false
var debug_wind_info: String = ""
var velocity_line: Line2D
var gravity_velocity: Vector2 = Vector2.ZERO
var waypoint_position: Vector2 = Vector2.ZERO
var has_active_waypoint: bool = false
var waypoint_visual: Node2D
var dead = false
var drawing_enabled: bool = true  # Controls whether the player can draw lines

# Signals
signal game_over
signal speed_changed(new_speed: float)
signal loop_detected(loop_count: int)
signal waypoint_created(position: Vector2)
signal waypoint_reached(position: Vector2)
signal waypoint_cleared()

@onready var plane_boost: AudioStreamPlayer = %PlaneBoost

#-------------------------------------------------------------------------------
func _ready() -> void:
	_initialize_plane()
	_setup_velocity_visualization()
	_setup_waypoint_visualization()

#-------------------------------------------------------------------------------
func _initialize_plane() -> void:
	"""Initialize plane state and properties"""
	current_speed = base_speed
	gravity_velocity = Vector2.ZERO
	game_started = false

#-------------------------------------------------------------------------------
func _setup_velocity_visualization() -> void:
	"""Create and configure the velocity visualization line"""
	if not show_velocity_line:
		return
		
	velocity_line = Line2D.new()
	velocity_line.width = velocity_line_width
	velocity_line.default_color = velocity_line_color
	velocity_line.z_index = 10
	add_child(velocity_line)

#-------------------------------------------------------------------------------
func _setup_waypoint_visualization() -> void:
	"""Create and configure the waypoint visualization"""
	# We'll use the plane's own _draw method instead of creating separate nodes
	pass

#-------------------------------------------------------------------------------
func _draw() -> void:
	"""Custom drawing for waypoint visualization"""
	if has_active_waypoint and show_waypoint_visual:
		# Convert world position to local coordinates
		var local_waypoint_pos = to_local(waypoint_position)
		
		# Draw cross lines
		draw_line(local_waypoint_pos + Vector2(-20, 0), local_waypoint_pos + Vector2(20, 0), Color.RED, 4.0)
		draw_line(local_waypoint_pos + Vector2(0, -20), local_waypoint_pos + Vector2(0, 20), Color.RED, 4.0)
		
		# Draw circle
		draw_arc(local_waypoint_pos, 15.0, 0, TAU, 16, Color.RED, 3.0)

#-------------------------------------------------------------------------------
func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		start_game()
	
	if Input.is_action_just_pressed("right_click") and enable_debug_waypoint_click:
		_create_waypoint()

#-------------------------------------------------------------------------------
func start_game() -> void:
	"""Start the game and enable movement"""
	game_started = true
	# Give the plane a small initial speed so it's not completely stationary
	current_speed = max(base_speed, 200.0)  # Minimum 10 speed to get started
	
#-------------------------------------------------------------------------------
func _create_waypoint() -> void:
	"""Create a waypoint at waypoint_position"""
	if not game_started:
		return
	waypoint_position = get_global_mouse_position()
	# Set waypoint position to parameter location
	has_active_waypoint = true
	
	# Debug print to verify waypoint creation
	print("Waypoint created at: ", waypoint_position)
	print("Plane position: ", global_position)
	
	# Emit signal for external listeners
	waypoint_created.emit(waypoint_position)
	
	# Create visual representation
	_update_waypoint_visual()

#-------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if not game_started:
		_handle_stationary_state()
		return
	
	if not dead:
		_update_movement(delta)
		_update_velocity_visualization()
		_update_rotation()
		_check_boundaries()

		# Redraw if we have an active waypoint to keep it visible
		if has_active_waypoint:
			queue_redraw()
	
		move_and_slide()

#-------------------------------------------------------------------------------
func _handle_stationary_state() -> void:
	"""Handle plane behavior when game hasn't started"""
	velocity = Vector2.ZERO
	_update_velocity_visualization()

#-------------------------------------------------------------------------------
func _update_rotation() -> void:
	"""Update plane rotation to gradually face velocity direction"""
	# Only rotate if we have significant velocity
	if velocity.length() > 10.0:
		var target_angle: float = velocity.angle()
		var current_angle: float = rotation
		
		# Calculate the shortest angular distance
		var angle_diff: float = target_angle - current_angle
		
		# Normalize to [-PI, PI] range
		while angle_diff > PI:
			angle_diff -= 2 * PI
		while angle_diff < -PI:
			angle_diff += 2 * PI
		
		# Calculate velocity-based rotation speed
		var velocity_factor: float = (velocity.length() / max_speed) * velocity_rotation_multiplier
		var final_rotation_speed: float = rotation_speed * (1.0 + velocity_factor)
		
		# Gradually rotate toward the velocity direction
		rotation += angle_diff * final_rotation_speed * get_physics_process_delta_time()

#-------------------------------------------------------------------------------
func _update_movement(delta: float) -> void:
	"""Update plane movement including thrust and gravity"""
	var forward_direction: Vector2 = Vector2.RIGHT.rotated(rotation)
	
	# Check if we have an active waypoint
	if has_active_waypoint:
		_apply_waypoint_thrust(delta)
		_check_waypoint_reached()
	else:
		_apply_thrust(forward_direction, delta)
	
	_apply_gravity(forward_direction, delta)
	_update_final_velocity(forward_direction)

#-------------------------------------------------------------------------------
func _apply_thrust(forward_direction: Vector2, _delta: float) -> void:
	"""Apply thrust based on plane's forward direction"""
	var speed_multiplier: float = max(forward_direction.y, 0.0)
	
	if forward_direction.y >= 0.0:
		# Accelerate when pointing downward
		current_speed += speed_acceleration * speed_multiplier
	else:
		# Decelerate when pointing upward
		current_speed -= speed_deceleration
	
	# Allow for minimum movement so gravity can take effect
	var minimum_speed = max(base_speed, 10.0)
	current_speed = clamp(current_speed, minimum_speed, max_speed)
	speed_changed.emit(current_speed)

#-------------------------------------------------------------------------------
func _apply_waypoint_thrust(delta: float) -> void:
	"""Apply thrust towards the active waypoint"""
	if not game_started or not has_active_waypoint:
		return
	
	# Calculate direction towards waypoint
	var waypoint_direction: Vector2 = (waypoint_position - global_position).normalized()
	
	# Apply constant thrust force towards waypoint
	var thrust_force: Vector2 = waypoint_direction * boost_speed
	
	# Lerp current velocity towards the target velocity
	var lerp_factor: float = 5.0 * delta  # Adjust this value to control lerp speed
	velocity = velocity.lerp(thrust_force, lerp_factor)
	
	# Update current speed to match the velocity magnitude
	current_speed = velocity.length()
	speed_changed.emit(current_speed)

#-------------------------------------------------------------------------------
func _check_waypoint_reached() -> void:
	"""Check if the plane has reached the waypoint"""
	if not has_active_waypoint:
		return
	
	var distance_to_waypoint: float = global_position.distance_to(waypoint_position)
	
	if distance_to_waypoint <= waypoint_reach_threshold:
		# Only play sound if globally enabled
		if Global.waypoint_sound_enabled:
			plane_boost.play()
		var reached_position = waypoint_position  # Store before clearing
		_clear_waypoint()
		waypoint_reached.emit(reached_position)

#-------------------------------------------------------------------------------
func _clear_waypoint() -> void:
	"""Clear the active waypoint"""
	has_active_waypoint = false
	waypoint_position = Vector2.ZERO
	_update_waypoint_visual()
	waypoint_cleared.emit()

#-------------------------------------------------------------------------------
func _update_waypoint_visual() -> void:
	"""Update the visual representation of the waypoint"""
	# Simply trigger a redraw since we're using _draw() method now
	queue_redraw()
	
	if has_active_waypoint:
		print("Creating waypoint visual at: ", waypoint_position)
		print("Waypoint visual updated")
	# Removed debug print for clearing waypoint to reduce console spam

#-------------------------------------------------------------------------------
func _apply_gravity(forward_direction: Vector2, delta: float) -> void:
	"""Apply gravity effects based on plane orientation"""
	if forward_direction.y < 0.0:
		# Apply stronger gravity when pointing upward
		var upward_factor: float = -min(forward_direction.y, max_upward_angle)
		gravity_velocity += Vector2.DOWN * gravity_strength * delta * upward_factor
		gravity_velocity *= gravity_damping
	
	# Clamp gravity velocity to prevent excessive speeds
	if gravity_velocity.length() > terminal_velocity:
		gravity_velocity = gravity_velocity.normalized() * terminal_velocity

#-------------------------------------------------------------------------------
func _update_final_velocity(forward_direction: Vector2) -> void:
	"""Combine thrust and gravity to create final velocity"""
	# Only apply normal thrust velocity if waypoint isn't active
	if not has_active_waypoint:
		# Preserve momentum by keeping existing velocity and only adding thrust influence
		var forward_velocity: Vector2 = forward_direction * current_speed
		# Gradually blend the current velocity with the desired forward velocity to preserve momentum
		var momentum_factor: float = 0.95  # How much of the existing velocity to keep (0.0-1.0)
		velocity = velocity * momentum_factor + (forward_velocity + gravity_velocity) * (1.0 - momentum_factor)

#-------------------------------------------------------------------------------
func _update_velocity_visualization() -> void:
	"""Update the Line2D that visualizes the velocity vector"""
	if not show_velocity_line or not velocity_line:
		return
	
	velocity_line.clear_points()
	
	if velocity.length() > 0.1:
		velocity_line.add_point(Vector2.ZERO)
		# Convert to local coordinates and scale
		var local_velocity: Vector2 = velocity.rotated(-rotation) * velocity_line_scale
		velocity_line.add_point(local_velocity)

#-------------------------------------------------------------------------------
func _check_boundaries() -> void:
	"""Check if plane has hit ground or other boundaries"""
	if global_position.y >= ground_level:
		## Commented out for thing
		#_trigger_game_over() 
		pass

#-------------------------------------------------------------------------------
func _trigger_game_over() -> void:
	"""Handle game over state"""
	game_over.emit()

#-------------------------------------------------------------------------------
func set_wind_path(current_drawing: Array, loops: int) -> void:
	"""Set the current wind path for physics calculations"""
	wind_points = current_drawing
	loop_count = loops
	loop_detected.emit(loop_count)

#-------------------------------------------------------------------------------
func apply_wind_forces(delta: float) -> void:
	"""Apply wind forces based on proximity to drawn lines"""
	if wind_points.is_empty():
		return
	
	var closest_distance: float = INF
	var wind_force: Vector2 = Vector2.ZERO
	
	for point in wind_points:
		var distance: float = global_position.distance_to(point)
		if distance < wind_influence_radius and distance < closest_distance:
			closest_distance = distance
			# Calculate wind direction (simplified)
			var direction: Vector2 = (point - global_position).normalized()
			var strength: float = (wind_influence_radius - distance) / wind_influence_radius
			wind_force = direction * wind_force_strength * strength
	
	if wind_force.length() > 0:
		velocity += wind_force * delta

#-------------------------------------------------------------------------------
func get_current_speed() -> float:
	"""Get the current speed of the plane"""
	return current_speed

#-------------------------------------------------------------------------------
func get_loop_count() -> int:
	"""Get the current loop count"""
	return loop_count

#-------------------------------------------------------------------------------
func is_game_active() -> bool:
	"""Check if the game is currently active"""
	return game_started

#-------------------------------------------------------------------------------
func reset_plane() -> void:
	"""Reset plane to initial state for new game"""
	wind_points.clear()
	loop_count = 0
	current_speed = base_speed
	gravity_velocity = Vector2.ZERO
	game_started = false
	dead = false  # Ensure plane is not dead after reset
	_clear_waypoint()
	
	if velocity_line:
		velocity_line.clear_points()
	
	# Reset position if needed
	velocity = Vector2.ZERO

#-------------------------------------------------------------------------------
# PUBLIC WAYPOINT INTERFACE
#-------------------------------------------------------------------------------
func create_waypoint_at_position(world_position: Vector2) -> bool:
	"""Create a waypoint at a specific world position. Returns true if successful."""
	if not game_started:
		return false
	
	waypoint_position = world_position
	has_active_waypoint = true
	_update_waypoint_visual()
	
	waypoint_created.emit(world_position)
	print("Waypoint created programmatically at: ", world_position)
	
	return true

#-------------------------------------------------------------------------------
func get_waypoint_position() -> Vector2:
	"""Get the current waypoint position. Returns Vector2.ZERO if no active waypoint."""
	return waypoint_position if has_active_waypoint else Vector2.ZERO

#-------------------------------------------------------------------------------
func get_distance_to_waypoint() -> float:
	"""Get distance to current waypoint. Returns -1 if no active waypoint."""
	if not has_active_waypoint:
		return -1.0
	return global_position.distance_to(waypoint_position)

#-------------------------------------------------------------------------------
func has_waypoint() -> bool:
	"""Check if there's currently an active waypoint."""
	return has_active_waypoint

#-------------------------------------------------------------------------------
func clear_waypoint_public() -> bool:
	"""Public method to clear the current waypoint. Returns true if waypoint was cleared."""
	if not has_active_waypoint:
		return false
	
	_clear_waypoint()
	return true

#-------------------------------------------------------------------------------
func set_waypoint_reach_threshold(new_threshold: float) -> void:
	"""Set the distance threshold for considering a waypoint reached."""
	waypoint_reach_threshold = new_threshold

#-------------------------------------------------------------------------------
func set_waypoint_visibility(show_visual: bool) -> void:
	"""Toggle waypoint visual visibility."""
	show_waypoint_visual = show_visual
	queue_redraw()

#-------------------------------------------------------------------------------
func set_velocity_line_visibility(show_line: bool) -> void:
	"""Toggle velocity line visibility."""
	show_velocity_line = show_line
	if velocity_line:
		velocity_line.visible = show_line

#-------------------------------------------------------------------------------
func _get_debug_info() -> String:
	"""Get debug information string"""
	return "Speed: %.1f | Loops: %d | Gravity: %s | Game Active: %s" % [
		current_speed, 
		loop_count, 
		str(gravity_velocity), 
		str(game_started)
	]

#-------------------------------------------------------------------------------
func disable_drawing() -> void:
	"""Disable the ability to draw lines"""
	drawing_enabled = false

#-------------------------------------------------------------------------------
func enable_drawing() -> void:
	"""Enable the ability to draw lines"""
	drawing_enabled = true

#-------------------------------------------------------------------------------
func is_drawing_enabled() -> bool:
	"""Check if drawing is currently enabled"""
	return drawing_enabled
