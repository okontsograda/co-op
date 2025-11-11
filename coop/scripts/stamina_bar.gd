extends Control

@onready var fill: Panel = $Fill
@onready var background: Panel = $Background

var max_stamina: float = 100.0
var current_stamina: float = 100.0
var background_width: float = 60.0  # Fixed width for the stamina bar background


func _ready() -> void:
	# Create a unique StyleBox for this stamina bar instance
	var unique_stylebox = StyleBoxFlat.new()
	unique_stylebox.bg_color = Color(0.2, 0.6, 0.9, 1)  # Blue color for stamina
	unique_stylebox.corner_radius_top_left = 3
	unique_stylebox.corner_radius_top_right = 3
	unique_stylebox.corner_radius_bottom_right = 3
	unique_stylebox.corner_radius_bottom_left = 3
	fill.add_theme_stylebox_override("panel", unique_stylebox)

	# Store the background width to keep stamina bar size fixed
	if background:
		background_width = background.offset_right - background.offset_left


func update_stamina(current: float, maximum: float) -> void:
	current_stamina = current
	max_stamina = maximum

	# Calculate stamina percentage
	var stamina_percent = current_stamina / max_stamina if max_stamina > 0 else 0.0

	# Update the fill bar width based on actual background width
	# Background goes from offset_left to offset_right, Fill starts at offset_left
	if not fill or not background:
		return

	var fill_left = background.offset_left if background else -30.0
	fill.offset_left = fill_left
	fill.offset_right = fill_left + (stamina_percent * background_width)

	# Change color based on stamina level
	var stylebox = fill.get_theme_stylebox("panel")
	if stylebox:
		if stamina_percent > 0.6:
			# Bright blue when above 60%
			stylebox.bg_color = Color(0.2, 0.6, 0.9, 1)
		elif stamina_percent > 0.3:
			# Medium blue when between 30-60%
			stylebox.bg_color = Color(0.3, 0.5, 0.8, 1)
		else:
			# Dark blue/cyan when below 30%
			stylebox.bg_color = Color(0.4, 0.4, 0.7, 1)
