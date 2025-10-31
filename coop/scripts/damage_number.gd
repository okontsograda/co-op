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
func set_damage(damage: float, is_crit: bool = false, is_poison: bool = false) -> void:
	if label:
		var damage_int = int(damage)
		label.text = str(damage_int)

		if is_crit:
			# Critical hits: bigger, yellow
			label.add_theme_font_size_override("font_size", 24)
			label.add_theme_color_override("font_color", Color.YELLOW)
			label.text = "CRIT! " + label.text
		elif is_poison:
			# Poison damage: green/purple for passive damage
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.3))  # Bright green for poison
			label.text = "☠ " + label.text
		else:
			# Normal hits: white
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_color_override("font_color", Color.WHITE)
