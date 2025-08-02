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
@export var show_velocity_line: bool = true ## Whether to display the velocity direction line
@export var velocity_line_scale: float = 0.5 ## Scale factor for the velocity visualization line
@export var velocity_line_color: Color = Color.RED ## Color of the velocity direction line
@export var velocity_line_width: float = 3.0 ## Width of the velocity direction line in pixels

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

# Signals
signal game_over
signal speed_changed(new_speed: float)
signal loop_detected(loop_count: int)

#-------------------------------------------------------------------------------
func _ready() -> void:
	_initialize_plane()
	_setup_velocity_visualization()

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
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		start_game()
	
	if Input.is_action_just_pressed("right_click"):
		apply_boost()

#-------------------------------------------------------------------------------
func start_game() -> void:
	"""Start the game and enable movement"""
	game_started = true

#-------------------------------------------------------------------------------
func apply_boost() -> void:
	"""Apply speed boost to the plane"""
	if not game_started:
		return
	
	# Get cursor position and calculate direction
	var cursor_position: Vector2 = get_global_mouse_position()
	var boost_direction: Vector2 = (cursor_position - global_position).normalized()
	
	# Set velocity directly toward cursor with full boost speed
	velocity = boost_direction * boost_speed
	
	# Set current speed to boost speed for consistent behavior
	current_speed = boost_speed
	speed_changed.emit(current_speed)
	
	# Clear gravity velocity since we're overriding it
	gravity_velocity = Vector2.ZERO
	
	# Immediately orient the plane toward the cursor for boost
	rotation = boost_direction.angle()

#-------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if not game_started:
		_handle_stationary_state()
		return
	
	
	_update_movement(delta)
	_update_velocity_visualization()
	_update_rotation()
	_check_boundaries()
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
		
		# Gradually rotate toward the velocity direction
		rotation += angle_diff * rotation_speed * get_physics_process_delta_time()

#-------------------------------------------------------------------------------
func _update_movement(delta: float) -> void:
	"""Update plane movement including thrust and gravity"""
	var forward_direction: Vector2 = Vector2.RIGHT.rotated(rotation)
	
	_apply_thrust(forward_direction, delta)
	_apply_gravity(forward_direction, delta)
	_update_final_velocity(forward_direction)

#-------------------------------------------------------------------------------
func _apply_thrust(forward_direction: Vector2, delta: float) -> void:
	"""Apply thrust based on plane's forward direction"""
	var speed_multiplier: float = max(forward_direction.y, 0.0)
	
	if forward_direction.y >= 0.0:
		# Accelerate when pointing downward
		current_speed += speed_acceleration * speed_multiplier
	else:
		# Decelerate when pointing upward
		current_speed -= speed_deceleration
	
	current_speed = clamp(current_speed, 0.0, max_speed)
	speed_changed.emit(current_speed)

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
	var forward_velocity: Vector2 = forward_direction * current_speed
	velocity = forward_velocity + gravity_velocity

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
	
	if velocity_line:
		velocity_line.clear_points()
	
	# Reset position if needed
	velocity = Vector2.ZERO

#-------------------------------------------------------------------------------
func _get_debug_info() -> String:
	"""Get debug information string"""
	return "Speed: %.1f | Loops: %d | Gravity: %s | Game Active: %s" % [
		current_speed, 
		loop_count, 
		str(gravity_velocity), 
		str(game_started)
	]
