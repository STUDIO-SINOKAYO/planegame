extends Sprite2D

@onready var plane: CharacterBody2D = get_node("../Plane")  # Adjust path as needed

var target_scale: Vector2 = Vector2(0.445, 0.284)
var hidden_scale: Vector2 = Vector2(0.2, 0.1)
var is_scaling_down: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set initial state
	update_highlight_state()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	update_highlight_state()

func update_highlight_state():
	# Check if plane is dead first - this takes absolute priority
	var is_plane_dead = plane and plane.dead if plane else false
	
	if is_plane_dead:
		# Plane is dead - immediately go invisible regardless of any other conditions
		visible = false
		scale = hidden_scale
		is_scaling_down = false
		return  # Exit early to prevent any other logic from running
	
	# Only continue with normal highlight logic if plane is alive
	if not Global.MouseEnteredRadius and not Global.IsDrawing:
		# Mouse not in radius AND not drawing - scale down first, then go invisible
		if not is_scaling_down:
			# Start scaling down
			is_scaling_down = true
			visible = true  # Keep visible while scaling
		
		# Scale down towards hidden scale
		scale = scale.lerp(hidden_scale, 0.1)
		
		# Check if we're close enough to the target to hide
		if scale.distance_to(hidden_scale) < 0.01:
			visible = false
	else:
		# Mouse is in radius OR currently drawing - show and scale up
		visible = true
		is_scaling_down = false
		scale = scale.lerp(target_scale, 0.1)
