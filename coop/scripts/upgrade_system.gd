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

	func _init(p_id: String, p_name: String, p_desc: String, p_max: int = -1, p_rarity: float = 1.0):
		id = p_id
		name = p_name
		description = p_desc
		max_stacks = p_max
		rarity = p_rarity

# Upgrade database
var upgrades: Dictionary = {}

func _ready():
	_initialize_upgrades()

func _initialize_upgrades():
	# Combat Upgrades
	upgrades["fire_rate"] = Upgrade.new(
		"fire_rate",
		"Rapid Fire",
		"Fire 15% faster",
		-1,  # Infinite stacks
		1.0
	)

	upgrades["damage_boost"] = Upgrade.new(
		"damage_boost",
		"Power Shot",
		"+20% arrow damage",
		-1,
		1.0
	)

	upgrades["pierce"] = Upgrade.new(
		"pierce",
		"Piercing Arrows",
		"Arrows pass through +1 enemy",
		10,  # Max 10 stacks
		0.8
	)

	upgrades["multishot"] = Upgrade.new(
		"multishot",
		"Multishot",
		"Fire +1 additional arrow",
		5,  # Max 5 stacks (6 total arrows)
		0.6
	)

	upgrades["crit_chance"] = Upgrade.new(
		"crit_chance",
		"Critical Strike",
		"+15% crit chance (2x damage)",
		6,  # Max 90% crit chance
		0.9
	)

	upgrades["explosive_arrows"] = Upgrade.new(
		"explosive_arrows",
		"Explosive Arrows",
		"+10% chance arrows explode",
		10,  # Max 100% chance
		0.7
	)

	upgrades["arrow_speed"] = Upgrade.new(
		"arrow_speed",
		"Swift Arrows",
		"+25% arrow speed",
		5,
		0.9
	)

	upgrades["lifesteal"] = Upgrade.new(
		"lifesteal",
		"Life Steal",
		"Heal 2 HP per enemy hit",
		10,
		0.7
	)

	upgrades["rapid_fire_capacity"] = Upgrade.new(
		"rapid_fire_capacity",
		"Quick Draw",
		"+1 rapid fire arrow before cooldown",
		3,
		0.8
	)

	# Special Abilities
	upgrades["poison_arrows"] = Upgrade.new(
		"poison_arrows",
		"Poison Arrows",
		"Enemies take 3 damage/sec for 3s",
		1,  # Only need once
		0.6
	)

	upgrades["homing"] = Upgrade.new(
		"homing",
		"Homing Arrows",
		"Arrows track nearest enemy",
		5,
		0.5
	)

	upgrades["arrow_nova"] = Upgrade.new(
		"arrow_nova",
		"Arrow Nova",
		"Fire 8 arrows in all directions every 10s",
		1,
		0.4
	)

	upgrades["summon_archer"] = Upgrade.new(
		"summon_archer",
		"Summon Archer",
		"Spawn ally archer for 60 seconds",
		1,
		0.3
	)

	upgrades["damage_shield"] = Upgrade.new(
		"damage_shield",
		"Shield Barrier",
		"Press E: 50% damage reduction for 5s (30s cooldown)",
		1,
		0.5
	)

	upgrades["xp_magnet"] = Upgrade.new(
		"xp_magnet",
		"XP Magnet",
		"2x XP collection range, +10% XP gain",
		3,
		0.8
	)

# Get random upgrades for selection (excludes maxed upgrades)
func get_random_upgrades(count: int, current_stacks: Dictionary) -> Array[Upgrade]:
	var available_upgrades: Array[Upgrade] = []

	# Filter out maxed upgrades
	for upgrade_id in upgrades:
		var upgrade = upgrades[upgrade_id]
		var current_count = current_stacks.get(upgrade_id, 0)

		# Include if not maxed (max_stacks == -1 means infinite)
		if upgrade.max_stacks == -1 or current_count < upgrade.max_stacks:
			available_upgrades.append(upgrade)

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
