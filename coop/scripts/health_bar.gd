extends Control

@onready var fill: Panel = $Fill
@onready var background: Panel = $Background

var max_health: int = 100
var current_health: int = 100
var background_width: float = 60.0  # Fixed width for the health bar background

func _ready() -> void:
	# Create a unique StyleBox for this health bar instance
	var unique_stylebox = StyleBoxFlat.new()
	unique_stylebox.bg_color = Color(0.8, 0.2, 0.2, 1)
	unique_stylebox.corner_radius_top_left = 3
	unique_stylebox.corner_radius_top_right = 3
	unique_stylebox.corner_radius_bottom_right = 3
	unique_stylebox.corner_radius_bottom_left = 3
	fill.add_theme_stylebox_override("panel", unique_stylebox)
	
	# Store the background width to keep health bar size fixed
	if background:
		background_width = background.offset_right - background.offset_left

func update_health(current: int, maximum: int) -> void:
	current_health = current
	max_health = maximum
	
	# Calculate health percentage
	var health_percent = float(current_health) / float(max_health) if max_health > 0 else 0.0
	
	# Update the fill bar width based on actual background width
	# Background goes from offset_left to offset_right, Fill starts at offset_left
	var fill_left = background.offset_left if background else -30.0
	fill.offset_left = fill_left
	fill.offset_right = fill_left + (health_percent * background_width)
	
	# Change color based on health
	var stylebox = fill.get_theme_stylebox("panel")
	if stylebox:
		if health_percent > 0.6:
			# Green when above 60%
			stylebox.bg_color = Color(0.2, 0.8, 0.2, 1)
		elif health_percent > 0.3:
			# Yellow when between 30-60%
			stylebox.bg_color = Color(1.0, 0.8, 0.2, 1)
		else:
			# Red when below 30%
			stylebox.bg_color = Color(0.8, 0.2, 0.2, 1)

