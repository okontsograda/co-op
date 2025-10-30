extends Control

@onready var fill: Panel = $Fill

var max_xp: int = 100
var current_xp: int = 0


func _ready() -> void:
	# Create a unique StyleBox for this XP bar instance
	var unique_stylebox = StyleBoxFlat.new()
	unique_stylebox.bg_color = Color(0.2, 0.4, 0.8, 1)  # Blue color
	unique_stylebox.corner_radius_top_left = 3
	unique_stylebox.corner_radius_top_right = 3
	unique_stylebox.corner_radius_bottom_right = 3
	unique_stylebox.corner_radius_bottom_left = 3
	fill.add_theme_stylebox_override("panel", unique_stylebox)


func update_xp(current: int, maximum: int) -> void:
	current_xp = current
	max_xp = maximum

	# Calculate XP percentage
	var xp_percent = float(current_xp) / float(max_xp) if max_xp > 0 else 0.0

	# Update the fill bar width
	fill.offset_right = -30.0 + (xp_percent * 60.0)
