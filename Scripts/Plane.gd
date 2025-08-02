extends CharacterBody2D
class_name PlayerPlane

# Tunable physics parameters - mess with these in the editor
@export var base_speed: float = 50.0           # How fast plane moves right
@export var gravity: float = 30.0              # Gentle downward pull for paper airplane
@export var loop_speed_multiplier: float = 50.0 # Speed bonus per loop
@export var rotation_speed: float = 5.0         # How fast plane rotates to face movement
@export var wind_influence_radius: float = 100.0 # How close to drawn lines to feel wind
@export var wind_force_strength: float = 800.0  # How strong the wind effect is

# Loop-specific wind parameters
@export var loop_suction_radius: float = 150.0  # How far loops can suck in the plane
@export var loop_suction_strength: float = 1000.0 # How strong the suction effect is
@export var loop_acceleration: float = 1500.0   # Speed boost when circling through loops

# Game state stuff
var wind_points = []                # Points from the currently drawn line
var loop_centers = []               # Centers of detected loops for suction effect
var loop_paths = []                 # The actual drawn paths of loops for following
var red_line_direction = Vector2.RIGHT  # Overall direction of the red debug line
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

func set_loop_centers(centers: Array):
	# Called with positions of detected loop centers for suction effect
	loop_centers = centers.duplicate()

func set_loop_paths(paths: Array):
	# Called with the actual drawn paths of loops for path following
	loop_paths = paths.duplicate()

func set_red_line_direction(direction: Vector2):
	# Called with the overall direction of the red debug line connecting loop centers
	red_line_direction = direction.normalized() if direction.length() > 0 else Vector2.RIGHT

func apply_wind_forces(delta):
	# This is the core mechanic: drawn lines create wind that pushes the plane around
	# PLUS: detected loops create suction that pulls plane in and accelerates it around
	
	var total_wind_force = Vector2.ZERO
	
	# PART 1: Loop path following forces (follow the actual drawn loops!)
	for i in range(loop_paths.size()):
		if i < loop_centers.size():  # Make sure we have a matching center
			var loop_path = loop_paths[i]
			var loop_center = loop_centers[i]
			
			if loop_path.size() < 3:  # Need at least 3 points for a loop
				continue
				
			# Check if plane is close enough to this loop
			var distance_to_center = global_position.distance_to(loop_center)
			if distance_to_center < loop_suction_radius:
				# Find the closest point on this loop path
				var closest_point = Vector2.ZERO
				var closest_distance = INF
				
				for j in range(loop_path.size()):
					var distance = global_position.distance_to(loop_path[j])
					if distance < closest_distance:
						closest_distance = distance
						closest_point = loop_path[j]
				
				# If close enough to the path, apply forces
				if closest_distance < wind_influence_radius:
					# Use the red line direction - this is the path between loop centers
					# The plane should follow this overall flow direction through the loops
					var path_direction = red_line_direction
					
					# Calculate force strength based on distance
					var path_strength = 1.0 - (closest_distance / wind_influence_radius)
					path_strength = path_strength * path_strength
					
					# Also factor in distance to loop center for suction effect
					var center_strength = 1.0 - (distance_to_center / loop_suction_radius)
					center_strength = center_strength * center_strength
					
					# Combine path following with suction toward path
					var to_path = (closest_point - global_position).normalized()
					var suction_to_path = to_path * loop_suction_strength * center_strength * 0.5
					var follow_path = path_direction * loop_acceleration * path_strength
					
					total_wind_force += suction_to_path + follow_path
	
	
	# Apply the combined wind forces to plane velocity
	velocity += total_wind_force * delta

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
