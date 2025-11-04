extends Node
# Shop Manager - Manages shop items, purchases, and player inventories
# This is an autoload singleton

# Shop item definition
class ShopItem:
	var id: String
	var name: String
	var description: String
	var cost: int
	var category: String  # "weapon", "armor", "consumable", "upgrade"
	var max_purchases: int  # -1 for unlimited
	var stat_bonuses: Dictionary  # Stats this item provides
	var icon_path: String
	
	func _init(
		p_id: String,
		p_name: String,
		p_desc: String,
		p_cost: int,
		p_category: String = "upgrade",
		p_max: int = 1,
		p_bonuses: Dictionary = {},
		p_icon: String = ""
	):
		id = p_id
		name = p_name
		description = p_desc
		cost = p_cost
		category = p_category
		max_purchases = p_max
		stat_bonuses = p_bonuses
		icon_path = p_icon


# Shop items database
var items: Dictionary = {}

# Player purchases tracking {player_name: {item_id: purchase_count}}
var player_purchases: Dictionary = {}


func _ready() -> void:
	_initialize_items()


func _initialize_items() -> void:
	# ===== WEAPONS =====
	items["better_bow"] = ShopItem.new(
		"better_bow",
		"Superior Bow",
		"+10 damage, +20% fire rate",
		50,
		"weapon",
		1,
		{"damage": 10, "fire_rate_mult": 0.8}
	)
	
	items["war_bow"] = ShopItem.new(
		"war_bow",
		"War Bow",
		"+25 damage, +30% fire rate, +1 pierce",
		150,
		"weapon",
		1,
		{"damage": 25, "fire_rate_mult": 0.7, "pierce": 1}
	)
	
	items["legendary_bow"] = ShopItem.new(
		"legendary_bow",
		"Legendary Bow",
		"+50 damage, +50% fire rate, +2 pierce, +1 multishot",
		500,
		"weapon",
		1,
		{"damage": 50, "fire_rate_mult": 0.5, "pierce": 2, "multishot": 1}
	)
	
	# ===== ARMOR =====
	items["leather_armor"] = ShopItem.new(
		"leather_armor",
		"Leather Armor",
		"+20 max HP",
		30,
		"armor",
		1,
		{"max_health": 20}
	)
	
	items["chainmail"] = ShopItem.new(
		"chainmail",
		"Chainmail Armor",
		"+50 max HP, +5% damage reduction",
		100,
		"armor",
		1,
		{"max_health": 50, "damage_reduction": 0.05}
	)
	
	items["plate_armor"] = ShopItem.new(
		"plate_armor",
		"Plate Armor",
		"+100 max HP, +15% damage reduction",
		300,
		"armor",
		1,
		{"max_health": 100, "damage_reduction": 0.15}
	)
	
	# ===== ACCESSORIES =====
	items["attack_ring"] = ShopItem.new(
		"attack_ring",
		"Ring of Power",
		"+15% damage",
		80,
		"upgrade",
		3,
		{"damage_mult": 0.15}
	)
	
	items["speed_boots"] = ShopItem.new(
		"speed_boots",
		"Swift Boots",
		"+20% movement speed",
		60,
		"upgrade",
		2,
		{"speed_mult": 0.2}
	)
	
	items["life_amulet"] = ShopItem.new(
		"life_amulet",
		"Amulet of Vitality",
		"+50 max HP, +3 HP regen per hit",
		120,
		"upgrade",
		2,
		{"max_health": 50, "lifesteal": 3}
	)
	
	items["crit_pendant"] = ShopItem.new(
		"crit_pendant",
		"Critical Pendant",
		"+20% crit chance, +50% crit damage",
		200,
		"upgrade",
		1,
		{"crit_chance": 0.2, "crit_mult": 0.5}
	)
	
	items["lucky_coin"] = ShopItem.new(
		"lucky_coin",
		"Lucky Coin",
		"+50% coin drops from enemies",
		100,
		"upgrade",
		3,
		{"coin_mult": 0.5}
	)
	
	items["xp_tome"] = ShopItem.new(
		"xp_tome",
		"Tome of Knowledge",
		"+30% XP gain",
		150,
		"upgrade",
		3,
		{"xp_mult": 0.3}
	)
	
	# ===== CONSUMABLES =====
	items["health_potion"] = ShopItem.new(
		"health_potion",
		"Health Potion",
		"Instantly restore 50 HP",
		20,
		"consumable",
		-1,  # Unlimited purchases
		{"instant_heal": 50}
	)
	
	items["max_health_potion"] = ShopItem.new(
		"max_health_potion",
		"Greater Health Potion",
		"Instantly restore to full HP",
		40,
		"consumable",
		-1,
		{"instant_heal": 999999}  # Full heal
	)
	
	# ===== SPECIAL UPGRADES =====
	items["pierce_upgrade"] = ShopItem.new(
		"pierce_upgrade",
		"Piercing Upgrade",
		"+1 pierce count",
		50,
		"upgrade",
		5,
		{"pierce": 1}
	)
	
	items["multishot_upgrade"] = ShopItem.new(
		"multishot_upgrade",
		"Multishot Upgrade",
		"+1 arrow per shot",
		100,
		"upgrade",
		3,
		{"multishot": 1}
	)
	
	items["explosion_upgrade"] = ShopItem.new(
		"explosion_upgrade",
		"Explosive Ammo",
		"+20% explosion chance on hit",
		150,
		"upgrade",
		5,
		{"explosion_chance": 0.2}
	)
	
	items["stamina_upgrade"] = ShopItem.new(
		"stamina_upgrade",
		"Stamina Boost",
		"+50 max stamina, +50% stamina regen",
		80,
		"upgrade",
		3,
		{"max_stamina": 50, "stamina_regen_mult": 0.5}
	)


# Get items by category
func get_items_by_category(category: String) -> Array[ShopItem]:
	var result: Array[ShopItem] = []
	for item_id in items:
		var item = items[item_id]
		if item.category == category:
			result.append(item)
	return result


# Get all categories
func get_categories() -> Array[String]:
	return ["weapon", "armor", "upgrade", "consumable"]


# Get all items
func get_all_items() -> Array[ShopItem]:
	var result: Array[ShopItem] = []
	for item_id in items:
		result.append(items[item_id])
	return result


# Get item by ID
func get_item(item_id: String) -> ShopItem:
	return items.get(item_id, null)


# Check if player can afford item
func can_afford(player: Node, item_id: String) -> bool:
	var item = get_item(item_id)
	if not item:
		return false
	
	if "coins" not in player:
		return false
	
	return player.coins >= item.cost


# Check if player has reached max purchases for an item
func has_max_purchases(player_name: String, item_id: String) -> bool:
	var item = get_item(item_id)
	if not item:
		return true
	
	if item.max_purchases == -1:
		return false  # Unlimited
	
	var purchases = get_purchase_count(player_name, item_id)
	return purchases >= item.max_purchases


# Get number of times player has purchased an item
func get_purchase_count(player_name: String, item_id: String) -> int:
	if not player_purchases.has(player_name):
		return 0
	return player_purchases[player_name].get(item_id, 0)


# Attempt to purchase an item
func purchase_item(player: Node, item_id: String) -> bool:
	var item = get_item(item_id)
	if not item:
		print("ERROR: Item not found: ", item_id)
		return false
	
	# Check if player can afford
	if not can_afford(player, item_id):
		print("Player cannot afford ", item.name)
		return false
	
	var player_name = str(player.name)
	
	# Check max purchases
	if has_max_purchases(player_name, item_id):
		print("Player has reached max purchases for ", item.name)
		return false
	
	# Deduct coins
	player.coins -= item.cost
	player.update_coin_display()
	
	# Sync coins to all clients
	player.rpc("sync_player_coins", player.coins)
	
	# Track purchase
	if not player_purchases.has(player_name):
		player_purchases[player_name] = {}
	
	if not player_purchases[player_name].has(item_id):
		player_purchases[player_name][item_id] = 0
	
	player_purchases[player_name][item_id] += 1
	
	# Apply item effects
	apply_item_effects(player, item)
	
	print("Player ", player_name, " purchased ", item.name, " for ", item.cost, " coins")
	return true


# Apply item stat bonuses to player
func apply_item_effects(player: Node, item: ShopItem) -> void:
	print("Applying effects for ", item.name)
	
	# Handle consumables (instant effects)
	if item.category == "consumable":
		if item.stat_bonuses.has("instant_heal"):
			var heal_amount = item.stat_bonuses.instant_heal
			# Cap at max health
			var actual_heal = min(heal_amount, player.max_health - player.current_health)
			player.heal(actual_heal)
			print("  - Healed ", actual_heal, " HP")
		return
	
	# Handle permanent stat bonuses
	var bonuses = item.stat_bonuses
	
	# Damage bonuses
	if bonuses.has("damage"):
		player.attack_damage += int(bonuses.damage)
		print("  - Attack damage: +", bonuses.damage)
	
	if bonuses.has("damage_mult"):
		player.weapon_stats.damage_multiplier += bonuses.damage_mult
		print("  - Damage multiplier: +", bonuses.damage_mult * 100, "%")
	
	# Fire rate
	if bonuses.has("fire_rate_mult"):
		player.weapon_stats.fire_cooldown *= bonuses.fire_rate_mult
		print("  - Fire cooldown: ", player.weapon_stats.fire_cooldown)
	
	# Pierce
	if bonuses.has("pierce"):
		player.weapon_stats.pierce_count += int(bonuses.pierce)
		print("  - Pierce count: +", bonuses.pierce)
	
	# Multishot
	if bonuses.has("multishot"):
		player.weapon_stats.multishot_count += int(bonuses.multishot)
		print("  - Multishot: +", bonuses.multishot)
	
	# Health
	if bonuses.has("max_health"):
		player.max_health += int(bonuses.max_health)
		player.current_health += int(bonuses.max_health)  # Also increase current HP
		player.update_health_display()
		print("  - Max health: +", bonuses.max_health)
	
	# Lifesteal
	if bonuses.has("lifesteal"):
		player.weapon_stats.lifesteal += int(bonuses.lifesteal)
		print("  - Lifesteal: +", bonuses.lifesteal)
	
	# Speed
	if bonuses.has("speed_mult"):
		player.class_speed_modifier += bonuses.speed_mult
		print("  - Speed multiplier: +", bonuses.speed_mult * 100, "%")
	
	# Crit
	if bonuses.has("crit_chance"):
		player.weapon_stats.crit_chance += bonuses.crit_chance
		print("  - Crit chance: +", bonuses.crit_chance * 100, "%")
	
	if bonuses.has("crit_mult"):
		player.weapon_stats.crit_multiplier += bonuses.crit_mult
		print("  - Crit multiplier: +", bonuses.crit_mult)
	
	# Explosion
	if bonuses.has("explosion_chance"):
		player.weapon_stats.explosion_chance += bonuses.explosion_chance
		print("  - Explosion chance: +", bonuses.explosion_chance * 100, "%")
	
	# Stamina
	if bonuses.has("max_stamina"):
		player.max_stamina += bonuses.max_stamina
		player.current_stamina += bonuses.max_stamina
		player.update_stamina_display()
		print("  - Max stamina: +", bonuses.max_stamina)
	
	if bonuses.has("stamina_regen_mult"):
		player.stamina_regen_rate *= (1.0 + bonuses.stamina_regen_mult)
		print("  - Stamina regen: +", bonuses.stamina_regen_mult * 100, "%")
	
	# Note: coin_mult and xp_mult would need to be tracked separately
	# and applied in the respective collection functions
	if bonuses.has("coin_mult"):
		print("  - Coin multiplier: +", bonuses.coin_mult * 100, "% (not yet implemented)")
	
	if bonuses.has("xp_mult"):
		print("  - XP multiplier: +", bonuses.xp_mult * 100, "% (not yet implemented)")


# Reset purchases for a player (useful for testing or new game)
func reset_player_purchases(player_name: String) -> void:
	if player_purchases.has(player_name):
		player_purchases.erase(player_name)


# Reset all purchases
func reset_all_purchases() -> void:
	player_purchases.clear()

