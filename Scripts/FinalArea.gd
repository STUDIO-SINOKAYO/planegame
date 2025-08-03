extends Node2D

@onready var waypoint_1: Node2D = $"Waypoint 1"
var level_node: Node2D
var plane_node: CharacterBody2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get references to the level and plane nodes
	level_node = get_parent()  # Level is the parent of Final Area
	plane_node = level_node.get_node("Plane")  # Plane is a child of Level


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass	


func _on_final_trigger_area_entered(area: Area2D) -> void:
	# Check if the area that entered is the plane's cursor detection area
	if area.name == "Cursor detection" and area.get_parent() == plane_node:
		print("Plane entered final area - disabling drawing and creating waypoint")
		
		# Disable drawing ability
		plane_node.disable_drawing()
		
		# Create waypoint at Waypoint 1 position
		if waypoint_1:
			var waypoint_pos = waypoint_1.global_position
			plane_node.create_waypoint_at_position(waypoint_pos)
			print("Created waypoint at position: ", waypoint_pos)
