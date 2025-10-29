extends Control

@onready var fill: Panel = $Fill

var max_health: int = 100
var current_health: int = 100

func _ready() -> void:
	# Create a unique StyleBox for this health bar instance
	var unique_stylebox = StyleBoxFlat.new()
	unique_stylebox.bg_color = Color(0.8, 0.2, 0.2, 1)
	unique_stylebox.corner_radius_top_left = 3
	unique_stylebox.corner_radius_top_right = 3
	unique_stylebox.corner_radius_bottom_right = 3
	unique_stylebox.corner_radius_bottom_left = 3
	fill.add_theme_stylebox_override("panel", unique_stylebox)

func update_health(current: int, maximum: int) -> void:
	current_health = current
	max_health = maximum
	
	# Calculate health percentage
	var health_percent = float(current_health) / float(max_health) if max_health > 0 else 0.0
	
	# Update the fill bar width (100 pixel total width: -50 to +50)
	fill.offset_right = -50.0 + (health_percent * 100.0)
	
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

