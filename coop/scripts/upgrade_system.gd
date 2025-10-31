extends Node
# Upgrade System - Manages upgrade definitions and selection logic
# This is an autoload singleton


# Upgrade definition structure
class Upgrade:
	var id: String
	var name: String
	var description: String
	var max_stacks: int  # -1 for infinite
	var rarity: float  # Weight for random selection (higher = more common)
	var compatible_weapons: Array  # Array of weapon IDs, or ["all"] for all weapons

	func _init(
		p_id: String,
		p_name: String,
		p_desc: String,
		p_max: int = -1,
		p_rarity: float = 1.0,
		p_compatible_weapons: Array = ["all"]
	):
		id = p_id
		name = p_name
		description = p_desc
		max_stacks = p_max
		rarity = p_rarity
		compatible_weapons = p_compatible_weapons

	func is_compatible_with_weapon(weapon_id: String) -> bool:
		return "all" in compatible_weapons or weapon_id in compatible_weapons


# Upgrade database
var upgrades: Dictionary = {}


func _ready():
	_initialize_upgrades()


func _initialize_upgrades():
	# ===== SHARED UPGRADES (work with all weapons) =====
	upgrades["damage_boost"] = Upgrade.new(
		"damage_boost", "Power Shot", "+20% damage", -1, 1.0, ["bow", "rocket"]
	)

	upgrades["crit_chance"] = Upgrade.new(
		"crit_chance", "Critical Strike", "+15% crit chance (2x damage)", 6, 0.9, ["all"]
	)

	upgrades["lifesteal"] = Upgrade.new(
		"lifesteal", "Life Steal", "Heal 2 HP per enemy hit", 10, 0.7, ["all"]
	)

	upgrades["poison_arrows"] = Upgrade.new(
		"poison_arrows", "Poison Arrows", "Enemies take 3 damage/sec for 3s", 1, 0.6, ["bow", "rocket"]
	)

	upgrades["damage_shield"] = Upgrade.new(
		"damage_shield",
		"Shield Barrier",
		"Press E: 50% damage reduction for 5s (30s cooldown)",
		1,
		0.5,
		["all"]
	)

	upgrades["xp_magnet"] = Upgrade.new(
		"xp_magnet", "XP Magnet", "2x XP collection range, +10% XP gain", 3, 0.8, ["all"]
	)
	
	# ===== RANGED WEAPON UPGRADES (Bow + Rocket) =====
	upgrades["fire_rate"] = Upgrade.new(
		"fire_rate", "Rapid Fire", "Fire 15% faster", -1, 1.0, ["bow", "rocket"]
	)

	upgrades["pierce"] = Upgrade.new(
		"pierce", "Piercing Shot", "Projectiles pass through +1 enemy", 10, 0.8, ["bow", "rocket"]
	)

	upgrades["homing"] = Upgrade.new(
		"homing", "Homing", "Projectiles track nearest enemy", 5, 0.5, ["bow", "rocket"]
	)

	upgrades["rapid_fire_capacity"] = Upgrade.new(
		"rapid_fire_capacity", "Quick Draw", "+1 rapid fire shot before cooldown", 3, 0.8, ["bow", "rocket"]
	)

	# ===== BOW-SPECIFIC UPGRADES =====
	upgrades["multishot"] = Upgrade.new(
		"multishot", "Multishot", "Fire +1 additional arrow", 5, 0.6, ["bow"]
	)

	upgrades["explosive_arrows"] = Upgrade.new(
		"explosive_arrows", "Explosive Arrows", "+10% chance arrows explode", 10, 0.7, ["bow"]
	)

	upgrades["arrow_speed"] = Upgrade.new(
		"arrow_speed", "Swift Arrows", "+25% arrow speed", 5, 0.9, ["bow"]
	)

	upgrades["arrow_nova"] = Upgrade.new(
		"arrow_nova", "Arrow Nova", "Fire 8 arrows in all directions every 10s", 1, 0.4, ["bow"]
	)

	# ===== SWORD-SPECIFIC UPGRADES (Melee) =====
	upgrades["sweep_attack"] = Upgrade.new(
		"sweep_attack", "Sweep Attack", "+50% melee attack range", 3, 0.7, ["sword"]
	)
	
	upgrades["heavy_strike"] = Upgrade.new(
		"heavy_strike", "Heavy Strike", "+30% melee damage", 5, 0.8, ["sword"]
	)
	
	upgrades["whirlwind"] = Upgrade.new(
		"whirlwind", "Whirlwind", "360° attack hits all nearby enemies", 1, 0.5, ["sword"]
	)
	
	upgrades["dash_strike"] = Upgrade.new(
		"dash_strike", "Dash Strike", "Press Q: Dash forward and attack (10s cooldown)", 1, 0.6, ["sword"]
	)

	upgrades["summon_archer"] = Upgrade.new(
		"summon_archer", "Summon Archer", "Spawn ally archer for 60 seconds", 1, 0.3, ["bow"]
	)

	# ===== ROCKET-SPECIFIC UPGRADES =====
	upgrades["cluster_rockets"] = Upgrade.new(
		"cluster_rockets",
		"Cluster Rockets",
		"Rockets split into 3 smaller rockets on impact",
		3,
		0.6,
		["rocket"]
	)

	upgrades["napalm_trail"] = Upgrade.new(
		"napalm_trail",
		"Napalm Trail",
		"Explosions leave burning ground (5 damage/sec for 3s)",
		1,
		0.5,
		["rocket"]
	)

	upgrades["bunker_buster"] = Upgrade.new(
		"bunker_buster",
		"Bunker Buster",
		"+50% damage vs high-health enemies (>50 HP)",
		3,
		0.7,
		["rocket"]
	)

	upgrades["guided_missiles"] = Upgrade.new(
		"guided_missiles",
		"Guided Missiles",
		"+50% homing strength for rockets",
		3,
		0.6,
		["rocket"]
	)

	upgrades["rocket_barrage"] = Upgrade.new(
		"rocket_barrage",
		"Rocket Barrage",
		"Fire +1 additional rocket",
		3,
		0.5,
		["rocket"]
	)

	upgrades["bigger_boom"] = Upgrade.new(
		"bigger_boom",
		"Bigger Boom",
		"+25% explosion radius and damage",
		5,
		0.8,
		["rocket"]
	)


# Get random upgrades for selection (excludes maxed upgrades and incompatible weapons)
func get_random_upgrades(
	count: int, current_stacks: Dictionary, weapon_id: String = "bow"
) -> Array[Upgrade]:
	var available_upgrades: Array[Upgrade] = []

	print("=== UPGRADE SYSTEM DEBUG ===")
	print("Filtering upgrades for weapon: ", weapon_id)

	# Filter out maxed upgrades and incompatible weapons
	for upgrade_id in upgrades:
		var upgrade = upgrades[upgrade_id]
		var current_count = current_stacks.get(upgrade_id, 0)

		# Check weapon compatibility
		var is_compatible = upgrade.is_compatible_with_weapon(weapon_id)
		if not is_compatible:
			continue

		# Include if not maxed (max_stacks == -1 means infinite)
		if upgrade.max_stacks == -1 or current_count < upgrade.max_stacks:
			available_upgrades.append(upgrade)
			print("  - Added: ", upgrade.name, " (compatible: ", upgrade.compatible_weapons, ")")

	# If not enough available, return what we have
	if available_upgrades.size() <= count:
		return available_upgrades

	# Weighted random selection
	var selected: Array[Upgrade] = []
	var available_copy = available_upgrades.duplicate()

	for i in range(count):
		if available_copy.is_empty():
			break

		# Calculate total weight
		var total_weight = 0.0
		for upgrade in available_copy:
			total_weight += upgrade.rarity

		# Select based on weight
		var random_value = randf() * total_weight
		var cumulative_weight = 0.0

		for j in range(available_copy.size()):
			cumulative_weight += available_copy[j].rarity
			if random_value <= cumulative_weight:
				selected.append(available_copy[j])
				available_copy.remove_at(j)
				break

	return selected


# Get upgrade by ID
func get_upgrade(upgrade_id: String) -> Upgrade:
	return upgrades.get(upgrade_id, null)
