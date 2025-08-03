extends Node

@export var slowdown_scale: float = 0.15  ## Time scale when drawing (0.0-1.0). Lower = slower
@export var normal_scale: float = 1.0    ## Normal time scale when not drawing
@export var transition_speed: float = 10 ## How fast to lerp between time scales. Higher = faster transition

var previous_drawing_state: bool = false
var target_time_scale: float = 1.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Ensure we start with normal time scale
	Engine.time_scale = normal_scale
	target_time_scale = normal_scale
	previous_drawing_state = Global.IsDrawing

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Check if drawing state has changed
	if Global.IsDrawing != previous_drawing_state:
		if Global.IsDrawing:
			# Player started drawing - target slow time (will lerp)
			target_time_scale = slowdown_scale
		else:
			# Player stopped drawing - instantly return to normal time
			Engine.time_scale = normal_scale
			target_time_scale = normal_scale
		
		# Update previous state
		previous_drawing_state = Global.IsDrawing
	
	# Only lerp when drawing (slowing down), instant when stopping
	if Global.IsDrawing and Engine.time_scale > target_time_scale:
		# Smoothly lerp towards slow time scale only when drawing
		Engine.time_scale = lerp(Engine.time_scale, target_time_scale, transition_speed * delta)
