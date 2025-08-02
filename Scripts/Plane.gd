extends CharacterBody2D
class_name PlayerPlane

# Tunable physics parameters - mess with these in the editor
@export var base_speed: float = 50.0           # How fast plane moves right
@export var gravity: float = 30.0              # Gentle downward pull for paper airplane
@export var loop_speed_multiplier: float = 50.0 # UNUSED - kept for compatibility, speed no longer changes
@export var rotation_speed: float = 10.0         # How fast plane rotates to face movement
@export var wind_influence_radius: float = 100.0 # How close to loop paths to feel wind forces
@export var wind_force_strength: float = 800.0  # UNUSED - individual loop forces calculated differently

# Wind vortex parameters - controls how loops affect plane movement
@export var loop_suction_radius: float = 100.0  # How close to loop centers before they start pulling the plane in
@export var loop_suction_strength: float = 30.0  # How hard loops suck the plane toward their centers (gentle so it doesn't go crazy)
@export var loop_acceleration: float = 80.0      # How hard loops push the plane toward the next loop in the chain (also gentle)

# Game state variables
var wind_points = []                # UNUSED - kept for compatibility, no longer used for physics
var loop_centers = []               # World positions of detected loop centers for suction physics
var loop_paths = []                 # Actual drawn path segments of each detected loop
var loop_directions = []            # Individual flow directions for each loop (points to next loop)
var red_line_direction = Vector2.RIGHT  # VISUAL ONLY - not used in physics, only for red line display
var current_speed: float            # Constant rightward speed - wind forces affect velocity, not speed
var loop_count: int = 0             # Number of loops detected (for reference only, doesn't affect speed)
var ground_level: float = 600.0     # Y coordinate where plane crashes
var game_started: bool = false      # Plane doesn't move until first drawing is made
var debug_wind_info: String = ""    # UNUSED - legacy debug text

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
	
	# Speed stays constant - only wind forces affect movement, not base speed

func set_loop_centers(centers: Array):
	# Called with world positions of detected loop centers for vortex suction physics
	loop_centers = centers.duplicate()

func set_loop_paths(paths: Array):
	# Called with the actual drawn path segments of each loop for wind force calculations
	loop_paths = paths.duplicate()

func set_loop_directions(directions: Array):
	# Called with individual flow directions for each loop (each points to the next loop center)
	# These directions are the only ones used for physics - red line is just visual
	loop_directions = directions.duplicate()

func apply_wind_forces(delta):
	# Core wind vortex physics: loops create suction and directional forces
	# When the plane gets near a loop, it gets sucked toward the center AND pushed toward the next loop
	# This creates a smooth flow between loops - no forces from straight lines, only loops matter
	
	var total_wind_force = Vector2.ZERO
	
	# Go through each detected loop and see if it should affect the plane
	for i in range(loop_paths.size()):
		if i < loop_centers.size():  # Make sure we have both path and center data
			var loop_path = loop_paths[i]
			var loop_center = loop_centers[i]
			
			if loop_path.size() < 3:  # Skip broken loops with too few points
				continue
				
			# Check if plane is close enough to this loop to feel its effects
			var distance_to_center = global_position.distance_to(loop_center)
			if distance_to_center < loop_suction_radius:
				# Apply wind forces if plane is within the influence zone
				if distance_to_center < wind_influence_radius:
					# Get the direction this loop should push the plane (toward the next loop)
					var path_direction = Vector2.RIGHT  # Default fallback if something breaks
					if i < loop_directions.size():
						path_direction = loop_directions[i]
					# These directions point from this loop center to the next one
					
					# Calculate how strong the forces should be based on distance (closer = stronger)
					var path_strength = 1.0 - (distance_to_center / wind_influence_radius)
					path_strength = path_strength * path_strength  # Square it for smooth falloff
					
					var center_strength = 1.0 - (distance_to_center / loop_suction_radius)
					center_strength = center_strength * center_strength  # Square it for smooth falloff
					
					# Force 1: Suction toward the loop center (creates the vortex effect)
					# This pulls the plane into the loop center so it doesn't just fly past
					var to_center = (loop_center - global_position).normalized()
					var suction_to_center = to_center * loop_suction_strength * center_strength
					
					# Force 2: Push toward the next loop in the chain
					# This is what makes the plane flow from one loop to the next
					var follow_path = path_direction * loop_acceleration * path_strength
					
					# Add both forces together for this loop's total effect
					total_wind_force += suction_to_center + follow_path
	
	
	# Apply all the accumulated wind forces to the plane's velocity
	# This is where the magic happens - all those loop forces get added to the plane's movement
	velocity += total_wind_force * delta

func get_closest_point_on_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> Vector2:
	# Math utility: find the closest point on a line segment to a given point
	# Projects the point onto the line segment and clamps to segment boundaries
	# Used for precise distance calculations in wind force physics
	var segment = segment_end - segment_start
	var segment_length_squared = segment.length_squared()
	
	if segment_length_squared == 0:
		return segment_start
	
	# Project point onto line and clamp to segment bounds (not infinite line)
	var t = (point - segment_start).dot(segment) / segment_length_squared
	t = clamp(t, 0.0, 1.0)  # Keep within segment boundaries
	
	return segment_start + t * segment

func reset_plane():
	# Reset all plane state for new game - clears wind data and stops movement
	wind_points.clear()         
	loop_count = 0              
	current_speed = base_speed  # Restore constant base speed
	game_started = false        # Wait for new drawing to start movement
