extends Node2D

# Animation settings
const FLOAT_SPEED: float = 50.0  # Pixels per second upward
const LIFETIME: float = 1.0  # Total lifetime in seconds
const FADE_START: float = 0.5  # When to start fading (seconds)

var time_alive: float = 0.0
var label: Label = null


func _ready():
	label = get_node("Label")

	# Add some random horizontal offset for variety
	var random_offset = randf_range(-10, 10)
	position.x += random_offset


func _process(delta: float) -> void:
	time_alive += delta

	# Move upward
	position.y -= FLOAT_SPEED * delta

	# Fade out after FADE_START seconds
	if time_alive > FADE_START and label:
		var fade_progress = (time_alive - FADE_START) / (LIFETIME - FADE_START)
		label.modulate.a = 1.0 - fade_progress

	# Destroy after lifetime
	if time_alive >= LIFETIME:
		queue_free()


# Set damage text and optional styling
func set_damage(damage: float, is_crit: bool = false, is_poison: bool = false, is_evade: bool = false) -> void:
	if label:
		var damage_int = int(damage)
		
		if is_evade:
			# Evaded attacks: cyan/blue, larger text
			label.text = "EVADED!"
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))  # Cyan
		elif is_crit:
			# Critical hits: bigger, yellow
			label.text = "CRIT! " + str(damage_int)
			label.add_theme_font_size_override("font_size", 24)
			label.add_theme_color_override("font_color", Color.YELLOW)
		elif is_poison:
			# Poison damage: green/purple for passive damage
			label.text = "☠ " + str(damage_int)
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.3))  # Bright green for poison
		else:
			# Normal hits: white
			label.text = str(damage_int)
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_color_override("font_color", Color.WHITE)


# Set evade text styling
func set_evade_text() -> void:
	if label:
		label.text = "EVADED!"
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))  # Cyan


# Set miss text styling (for when enemy attacks miss)
func set_miss_text() -> void:
	if label:
		label.text = "MISS!"
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))  # Gray
