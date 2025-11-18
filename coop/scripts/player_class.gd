extends RefCounted
class_name PlayerClass

# Static class definitions for different player types
static func get_class_by_name(class_id: String) -> Dictionary:
	var classes = get_all_classes()
	# Convert to lowercase for case-insensitive lookup
	var lower_class_id = class_id.to_lower()
	if classes.has(lower_class_id):
		return classes[lower_class_id]
	return classes["archer"]  # Default to archer


static func get_all_classes() -> Dictionary:
	return {
		"archer":
		{
			"name": "Archer",
			"description": "Balanced stats with standard damage and speed",
			"sprite_frames_path": "res://assets/Characters/Archer/archer_sprite_frames.tres",
			"combat_type": "ranged",  # Uses projectiles (arrows/rockets)
			"attack_range": 0,  # Ranged has unlimited range
			"health_modifier": 1.0,
			"damage_modifier": 1.0,
			"speed_modifier": 1.0,
			"attack_speed_modifier": 1.0,
			"color_tint": Color.WHITE  # No tint for base sprite
		},
		"knight":
		{
			"name": "Knight",
			"description": "Armored melee warrior with high defense",
			"sprite_frames_path": "res://assets/Characters/Knight/knight_sprite_frames.tres",
			"combat_type": "melee",  # Close-range sword attacks
			"attack_range": 60.0,  # Melee attack reach in pixels
			"health_modifier": 1.5,  # 150 health instead of 100
			"damage_modifier": 1.3,  # ~20 damage instead of 15
			"speed_modifier": 0.8,  # Slower movement
			"attack_speed_modifier": 0.9,  # Slightly slower attack speed
			"color_tint": Color.WHITE  # No tint for base sprite
		},
		"mage":
		{
			"name": "Mage",
			"description": "High damage and attack speed, but lower health",
			"sprite_frames_path": "res://assets/Characters/Mage/mage_sprite_frames.tres",
			"combat_type": "ranged",  # Uses magic projectiles
			"attack_range": 0,  # Ranged has unlimited range
			"health_modifier": 0.7,  # 70 health
			"damage_modifier": 1.5,  # ~23 damage
			"speed_modifier": 1.0,
			"attack_speed_modifier": 1.4,  # Much faster attack speed
			"color_tint": Color.WHITE  # No tint for base sprite
		},
		"tank":
		{
			"name": "Tank",
			"description": "Very high health and slow, focused on survival",
			"sprite_frames_path": "res://assets/Characters/Tank/tank_sprite_frames.tres",
			"combat_type": "ranged",  # Uses projectiles
			"attack_range": 0,  # Ranged has unlimited range
			"health_modifier": 2.0,  # 200 health
			"damage_modifier": 0.8,  # ~12 damage
			"speed_modifier": 0.7,  # Quite slow
			"attack_speed_modifier": 1.0,
			"color_tint": Color.WHITE  # No tint for base sprite
		}
	}


static func get_class_names() -> Array:
	return ["archer", "knight", "mage", "tank"]
