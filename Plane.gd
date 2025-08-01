extends CharacterBody2D
class_name PlayerPlane

@export var follow_speed: float = 150.0
@export var rotation_speed: float = 5.0

var path_points = []
var current_target_index = 0
var is_following_path = false
var path_complete = false

func _ready():
	pass

func _physics_process(delta):
	if is_following_path and not path_complete:
		follow_path(delta)

func set_path(points: Array):
	"""Set the path for the plane to follow"""
	path_points = points.duplicate()
	current_target_index = 0
	is_following_path = true
	path_complete = false
	
	# Position plane at start of path
	if path_points.size() > 0:
		global_position = path_points[0]

func follow_path(delta):
	if current_target_index >= path_points.size():
		path_complete = true
		velocity = Vector2.ZERO
		return
	
	var target = path_points[current_target_index]
	var distance_to_target = global_position.distance_to(target)
	
	# If close enough to current target, move to next point
	if distance_to_target < 10.0:
		current_target_index += 1
		return
	
	# Move towards target
	var direction = (target - global_position).normalized()
	velocity = direction * follow_speed
	
	# Rotate to face movement direction
	var target_rotation = direction.angle()
	rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)
	
	move_and_slide()

func reset_plane():
	"""Reset the plane for a new path"""
	path_points.clear()
	current_target_index = 0
	is_following_path = false
	path_complete = false
	velocity = Vector2.ZERO
