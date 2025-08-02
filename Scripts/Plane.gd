extends CharacterBody2D
class_name PlayerPlane


# Tunable physics parameters - mess with these in the editor
@export var base_speed: float = 100.0           # How fast plane moves right
@export var gravity: float = 9.8           # Downward pull
@export var loop_speed_multiplier: float = 50.0 # Speed bonus per loop
@export var rotation_speed: float = 5.0         # How fast plane rotates to face movement
@export var wind_influence_radius: float = 100.0 # How close to drawn lines to feel wind
@export var wind_force_strength: float = 800.0  # How strong the wind effect is
@export var lift_power: float = 100
@export var terminal_velocity: float = 500
# Game state stuff
var wind_points = []                # Points from the currently drawn line
var current_speed: float            # Actual speed (base + loop bonuses)
var loop_count: int = 0             # How many loops detected
var ground_level: float = 600.0     # Y position = death
var game_started: bool = false      # Don't move until first line drawn
var debug_wind_info: String = ""    # Debug text
signal game_over

#-------------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if Input.is_action_pressed("ui_accept"):
		game_started = true
#-------------------------------------------------------------------------------
func _ready():
	current_speed = base_speed
#---=PHYSICSPROCESS=------------------------------------------------------------
func _physics_process(delta): 
	if not game_started:
		velocity = Vector2.ZERO
		return
	
	# Set up base speed
	current_speed = base_speed
	# Get angle of mouse in relation to node
	var direction: Vector2 = get_global_mouse_position() - global_position
	var mouseangle: float = direction.angle()
	
	#Rotate node in accordance to mouse
	rotation = mouseangle
	
	# Rotational components
	var forward: Vector2 = Vector2.RIGHT.rotated(rotation)  # plane's nose direction
	var right: Vector2 = Vector2(-forward.y, forward.x)
	# Velocity components

	velocity.y += gravity
	velocity.y = min(velocity.y, terminal_velocity) # THESE TWO ARE USED TO CLAMP THE VELOCITY TO 
	velocity.x = min(velocity.x, terminal_velocity) # THE TERMINAL VELOCITY
	var velocity_magnitude = velocity.length() # VELOCITY MAGNITUDE
	
	# Lift, drag, and angle of attack
	var lift: float = 0
	var drag: float = 0
	var angle_of_attack: float = 0
	
	
	
	print("forward: ", forward)
	print("velocity_magnitude: ", velocity_magnitude)
	
	move_and_slide()
#-------------------------------------------------------------------------------
func apply_wind_forces(delta):
	pass
# ------------------------------------------------------------------------------
func reset_plane():
	# Reset everything for new game
	wind_points.clear()         
	loop_count = 0              
	current_speed = base_speed  
	game_started = false
