extends Node2D

# Animation settings
const FLOAT_SPEED: float = 50.0  # Pixels per second upward
const LIFETIME: float = 1.0  # Total lifetime in seconds
const FADE_START: float = 0.5  # When to start fading (seconds)

var time_alive: float = 0.0
var label: Label = null


func _ready():
	print("DamageNumber ", self, " _ready() called")
	label = get_node("Label")
	print("  Label found: ", label)
	print("  Initial visible state: ", visible)

	# Add some random horizontal offset for variety
	var random_offset = randf_range(-10, 10)
	position.x += random_offset
	print("  Random offset applied: ", random_offset)


func _process(delta: float) -> void:
	# Don't process while invisible (in pool)
	if not visible:
		return

	time_alive += delta

	# Log every 0.5 seconds while visible
	if int(time_alive * 2) != int((time_alive - delta) * 2):
		print("DamageNumber ", self, " _process - time_alive: ", time_alive, " visible: ", visible, " position: ", global_position)

	# Move upward
	position.y -= FLOAT_SPEED * delta

	# Fade out after FADE_START seconds
	if time_alive > FADE_START and label:
		var fade_progress = (time_alive - FADE_START) / (LIFETIME - FADE_START)
		label.modulate.a = 1.0 - fade_progress

	# Return to pool or destroy after lifetime
	if time_alive >= LIFETIME:
		print("DamageNumber ", self, " - LIFETIME reached, returning to pool or destroying")
		# Check if this damage number is part of VFXManager's pool
		var vfx_manager = get_node_or_null("/root/VFXManager")
		if vfx_manager and vfx_manager.has_method("return_to_pool"):
			print("  Returning to VFXManager pool")
			# Return to pool for reuse
			vfx_manager.return_to_pool(self)
		else:
			print("  No VFXManager found, calling queue_free()")
			# Not pooled, destroy normally
			queue_free()


# Set damage text and optional styling
func set_damage(damage: float, is_crit: bool = false, is_poison: bool = false, is_evade: bool = false) -> void:
	print("DamageNumber ", self, " set_damage() called - damage: ", damage, " is_crit: ", is_crit, " label: ", label)
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

		print("  Label text set to: '", label.text, "'")
	else:
		print("  ERROR: Label is null!")


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
	print("DamageNumber ", self, " reset() called - time_alive before: ", time_alive)
	time_alive = 0.0
	position = Vector2.ZERO

	# Add new random horizontal offset for variety
	var random_offset = randf_range(-10, 10)
	position.x += random_offset

	# Reset label appearance
	if label:
		label.modulate.a = 1.0  # Full opacity
		label.text = ""
		print("  Label reset - opacity: ", label.modulate.a, " text: ''")
	else:
		print("  ERROR: Label is null during reset!")

	print("  Reset complete - time_alive: ", time_alive, " position: ", position)
