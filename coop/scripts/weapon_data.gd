class_name WeaponData extends RefCounted

# Weapon definition class
# Stores all weapon-specific properties and configurations

# Weapon configuration structure
class WeaponConfig:
	var id: String
	var name: String
	var projectile_scene_path: String
	var base_damage: float
	var fire_cooldown: float
	var projectile_speed: float
	var base_explosion_chance: float
	var base_explosion_radius: float
	var base_explosion_damage: float
	var animation_name: String
	var sound_path: String

	func _init(
		p_id: String,
		p_name: String,
		p_projectile_scene: String,
		p_damage: float = 10.0,
		p_cooldown: float = 0.5,
		p_speed: float = 500.0,
		p_explosion_chance: float = 0.0,
		p_explosion_radius: float = 30.0,
		p_explosion_damage: float = 0.0,
		p_animation: String = "fire",
		p_sound: String = ""
	):
		id = p_id
		name = p_name
		projectile_scene_path = p_projectile_scene
		base_damage = p_damage
		fire_cooldown = p_cooldown
		projectile_speed = p_speed
		base_explosion_chance = p_explosion_chance
		base_explosion_radius = p_explosion_radius
		base_explosion_damage = p_explosion_damage
		animation_name = p_animation
		sound_path = p_sound


# Static weapon definitions
static var weapons: Dictionary = {}

# Initialize weapon definitions
static func initialize_weapons() -> void:
	if weapons.size() > 0:
		return  # Already initialized

	# Bow weapon
	weapons["bow"] = WeaponConfig.new(
		"bow",
		"Bow",
		"res://coop/scenes/arrow.tscn",
		15.0,  # base_damage
		0.5,   # fire_cooldown
		500.0, # projectile_speed
		0.0,   # base_explosion_chance (can be upgraded)
		30.0,  # base_explosion_radius
		0.0,   # base_explosion_damage
		"fire",
		"res://assets/Sounds/SFX/bow_release.mp3"
	)

	# Rocket Launcher weapon
	weapons["rocket"] = WeaponConfig.new(
		"rocket",
		"Rocket Launcher",
		"res://coop/scenes/rocket.tscn",
		30.0,  # base_damage (2x bow)
		1.0,   # fire_cooldown (2x slower than bow)
		300.0, # projectile_speed (slower than arrows)
		1.0,   # base_explosion_chance (always explodes)
		50.0,  # base_explosion_radius (larger than bow)
		20.0,  # base_explosion_damage (guaranteed AoE)
		"fire",  # Can be changed to "fire_rocket" if different animation exists
		"res://assets/Sounds/SFX/bow_release.mp3"  # TODO: Replace with rocket sound
	)

	# Sword weapon (for melee combat)
	weapons["sword"] = WeaponConfig.new(
		"sword",
		"Sword",
		"",  # No projectile for melee
		20.0,  # base_damage (higher than bow)
		1.0,   # fire_cooldown (1 second between swings)
		0.0,   # projectile_speed (not used for melee)
		0.0,   # base_explosion_chance
		0.0,   # base_explosion_radius
		0.0,   # base_explosion_damage
		"attack",  # Uses attack animation instead of fire
		"res://assets/Sounds/SFX/hit.mp3"  # Sword swing sound
	)


# Get weapon configuration by ID
static func get_weapon(weapon_id: String) -> WeaponConfig:
	if weapons.size() == 0:
		initialize_weapons()

	if weapons.has(weapon_id):
		return weapons[weapon_id]

	# Default to bow if weapon not found
	print("Warning: Weapon '", weapon_id, "' not found. Defaulting to bow.")
	return weapons["bow"]


# Get all available weapons
static func get_all_weapons() -> Dictionary:
	if weapons.size() == 0:
		initialize_weapons()
	return weapons


# Get weapon display names for UI
static func get_weapon_names() -> Array:
	if weapons.size() == 0:
		initialize_weapons()

	var names = []
	for weapon_id in weapons.keys():
		names.append(weapons[weapon_id].name)
	return names
