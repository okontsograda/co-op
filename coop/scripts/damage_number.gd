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
	# Don't process while invisible (in pool)
	if not visible:
		return

	time_alive += delta

	# Move upward
	position.y -= FLOAT_SPEED * delta

	# Fade out after FADE_START seconds
	if time_alive > FADE_START and label:
		var fade_progress = (time_alive - FADE_START) / (LIFETIME - FADE_START)
		label.modulate.a = 1.0 - fade_progress

	# Return to pool or destroy after lifetime
	if time_alive >= LIFETIME:
		# Check if this damage number is part of VFXManager's pool
		var vfx_manager = get_node_or_null("/root/VFXManager")
		if vfx_manager and vfx_manager.has_method("return_to_pool"):
			# Return to pool for reuse
			vfx_manager.return_to_pool(self)
		else:
			# Not pooled, destroy normally
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


# Reset state for pooling/reuse
func reset() -> void:
	time_alive = 0.0
	position = Vector2.ZERO

	# Add new random horizontal offset for variety
	var random_offset = randf_range(-10, 10)
	position.x += random_offset

	# Reset label appearance
	if label:
		label.modulate.a = 1.0  # Full opacity
		label.text = ""
