extends Node2D

func _ready() -> void:
	# Enable Y-sort for proper depth sorting
	y_sort_enabled = true
	
	# Set z_index based on Y position (same as player and enemy)
	# Use the collision position as the "base" of the tree for sorting
	var collision_node = get_node_or_null("StaticBody2D/CollisionShape2D")
	if collision_node:
		# Use the collision's global Y position as the sorting point
		z_index = int(global_position.y + collision_node.position.y)
	else:
		# Fallback to root position
		z_index = int(global_position.y)
	
	print("Tree positioned at ", global_position, " with z_index: ", z_index)

