extends CharacterBody2D
class_name PlayerPlane

# Tunable physics parameters - mess with these in the editor
@export var base_speed: float = 200.0           # How fast plane moves right
@export var gravity: float = 500.0              # Downward pull
@export var loop_speed_multiplier: float = 50.0 # Speed bonus per loop
@export var rotation_speed: float = 5.0         # How fast plane rotates to face movement
@export var wind_influence_radius: float = 100.0 # How close to drawn lines to feel wind
@export var wind_force_strength: float = 800.0  # How strong the wind effect is

# Game state stuff
var wind_points = []                # Points from the currently drawn line
var current_speed: float            # Actual speed (base + loop bonuses)
var loop_count: int = 0             # How many loops detected
var ground_level: float = 600.0     # Y position = death
var game_started: bool = false      # Don't move until first line drawn
var debug_wind_info: String = ""    # Debug text

signal game_over

func _ready():
	current_speed = base_speed

func _physics_process(delta):
	# Don't move until player draws first line
	if not game_started:
		velocity = Vector2.ZERO
		return
	
	# Core physics: gravity + rightward movement
	velocity.y += gravity * delta
	velocity.x = current_speed
	
	# Apply wind forces from nearby drawn lines (the main mechanic!)
	apply_wind_forces(delta)
	
	# Always point the plane towards where it's moving
	if velocity.length() > 0:
		var target_rotation = velocity.normalized().angle()
		rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)
	
	move_and_slide()
	
	# Check if we hit the ground = game over
	if global_position.y >= ground_level:
		emit_signal("game_over")

func set_wind_path(points: Array, detected_loops: int = 0):
	# Called when player finishes drawing a line
	wind_points = points.duplicate()
	loop_count = detected_loops
	
	# Start physics on first line drawn
	if not game_started:
		game_started = true
	
	# More loops = faster plane!
	current_speed = base_speed + (loop_count * loop_speed_multiplier)

func apply_wind_forces(delta):
	# This is the core mechanic: drawn lines create wind that pushes the plane around
	# Instead of following paths rigidly, plane gets "blown" by nearby line segments
	if wind_points.size() < 2:
		debug_wind_info = "No wind points"
		return
	
	var total_wind_force = Vector2.ZERO
	var influences = 0
	var closest_distance = INF
	
	# Check each segment of the drawn line
	for i in range(wind_points.size() - 1):
		var segment_start = wind_points[i]
		var segment_end = wind_points[i + 1]
		
		# Find closest point on this line segment to the plane
		var closest_point = get_closest_point_on_segment(global_position, segment_start, segment_end)
		var distance = global_position.distance_to(closest_point)
		closest_distance = min(closest_distance, distance)
		
		# If close enough, apply wind force
		if distance < wind_influence_radius:
			# Wind direction = along the line segment
			var wind_direction = (segment_end - segment_start).normalized()
			
			# Closer = stronger effect (squared falloff for smooth feel)
			var influence_strength = 1.0 - (distance / wind_influence_radius)
			influence_strength = influence_strength * influence_strength
			
			var wind_force = wind_direction * wind_force_strength * influence_strength
			
			# Extra lift for upward lines (helps counter gravity)
			if wind_direction.y < 0:  # Line goes up
				wind_force.y *= 2.0
			
			total_wind_force += wind_force
			influences += 1
	
	# Debug info for troubleshooting
	debug_wind_info = "Influences: " + str(influences) + " | Closest: " + str(int(closest_distance)) + " | Force: " + str(total_wind_force)
	
	# Apply the wind to plane velocity
	if influences > 0:
		var average_force = total_wind_force / influences
		velocity += average_force * delta

func get_closest_point_on_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> Vector2:
	# Math utility: find closest point on a line segment to the plane
	# Used to calculate how close plane is to each drawn line segment
	var segment = segment_end - segment_start
	var segment_length_squared = segment.length_squared()
	
	if segment_length_squared == 0:
		return segment_start
	
	# Project point onto line and clamp to segment bounds
	var t = (point - segment_start).dot(segment) / segment_length_squared
	t = clamp(t, 0.0, 1.0)  # Keep within segment (not infinite line)
	
	return segment_start + t * segment

func reset_plane():
	# Reset everything for new game
	wind_points.clear()         
	loop_count = 0              
	current_speed = base_speed  
	game_started = false
