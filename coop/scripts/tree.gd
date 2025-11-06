extends Node2D

func _ready() -> void:
	# Note: y_sort_enabled is already set to true in the scene file
	# The tree's Node2D position should be at the BASE (trunk), not the top
	# The sprite is offset upward, so y-sorting will work based on the base position
	pass

func _process(_delta: float) -> void:
	# Update z_index every frame based on Y position for proper sorting with moving objects
	# Use the base of the tree (the Node2D root position) for sorting
	z_index = int(global_position.y)

