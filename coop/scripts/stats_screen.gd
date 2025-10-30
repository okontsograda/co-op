extends CanvasLayer

# Reference to the player whose stats are being displayed
var player: Node2D = null

func _ready():
	# Start hidden
	hide()

# Show stats for a specific player
func show_stats(p_player: Node2D) -> void:
	player = p_player
	update_display()
	show()

# Update all stat displays
func update_display() -> void:
	if not player:
		return

	# Update player stats
	update_player_stats()

	# Update weapon stats
	update_weapon_stats()

	# Update upgrades list
	update_upgrades_list()

func update_player_stats() -> void:
	# Level
	var level_value = get_node("MarginContainer/VBoxContainer/ScrollContainer/Content/PlayerStats/StatsGrid/LevelValue")
	if level_value:
		level_value.text = str(player.current_level)

	# Health
	var health_value = get_node("MarginContainer/VBoxContainer/ScrollContainer/Content/PlayerStats/StatsGrid/HealthValue")
	if health_value:
		health_value.text = str(player.current_health) + " / " + str(player.max_health)

	# XP
	var xp_value = get_node("MarginContainer/VBoxContainer/ScrollContainer/Content/PlayerStats/StatsGrid/XPValue")
	if xp_value:
		xp_value.text = str(player.current_xp) + " / " + str(player.xp_to_next_level)

func update_weapon_stats() -> void:
	var ws = player.weapon_stats

	# Calculate final damage
	var final_damage = (player.attack_damage + ws.damage) * ws.damage_multiplier
	var damage_value = get_node("MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/DamageValue")
	if damage_value:
		damage_value.text = str(snappedf(final_damage, 0.1))
		if ws.damage_multiplier > 1.0:
			damage_value.text += " (x" + str(snappedf(ws.damage_multiplier, 0.1)) + ")"

	# Fire rate (shots per second)
	var shots_per_sec = 1.0 / ws.fire_cooldown
	var fire_rate_value = get_node("MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/FireRateValue")
	if fire_rate_value:
		fire_rate_value.text = str(snappedf(shots_per_sec, 0.1)) + " shots/sec"

	# Multishot
	var multishot_value = get_node("MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/MultishotValue")
	if multishot_value:
		var arrow_text = " arrow" if ws.multishot_count == 1 else " arrows"
		multishot_value.text = str(ws.multishot_count) + arrow_text

	# Pierce
	var pierce_value = get_node("MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/PierceValue")
	if pierce_value:
		if ws.pierce_count == 0:
			pierce_value.text = "None"
		else:
			var enemy_text = " enemy" if ws.pierce_count == 1 else " enemies"
			pierce_value.text = str(ws.pierce_count) + enemy_text

	# Crit chance
	var crit_value = get_node("MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/CritChanceValue")
	if crit_value:
		crit_value.text = str(snappedf(ws.crit_chance * 100, 1)) + "%"
		if ws.crit_chance > 0:
			crit_value.text += " (x" + str(ws.crit_multiplier) + ")"

	# Arrow speed
	var speed_value = get_node("MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/ArrowSpeedValue")
	if speed_value:
		speed_value.text = str(int(ws.arrow_speed))

	# Explosion chance
	var explosion_value = get_node("MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/ExplosionValue")
	if explosion_value:
		explosion_value.text = str(snappedf(ws.explosion_chance * 100, 1)) + "%"
		if ws.explosion_chance > 0:
			explosion_value.text += " (radius: " + str(int(ws.explosion_radius)) + ")"

	# Lifesteal
	var lifesteal_value = get_node("MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/LifestealValue")
	if lifesteal_value:
		if ws.lifesteal == 0:
			lifesteal_value.text = "None"
		else:
			lifesteal_value.text = str(ws.lifesteal) + " HP per hit"

	# Homing
	var homing_value = get_node("MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/HomingValue")
	if homing_value:
		if ws.homing_strength == 0:
			homing_value.text = "None"
		else:
			homing_value.text = str(snappedf(ws.homing_strength * 100, 1)) + "%"

func update_upgrades_list() -> void:
	var upgrades_list = get_node("MarginContainer/VBoxContainer/ScrollContainer/Content/ActiveUpgrades/UpgradesList")
	if not upgrades_list:
		return

	# Clear existing upgrade labels
	for child in upgrades_list.get_children():
		child.queue_free()

	# If no upgrades, show the "no upgrades" label
	if player.upgrade_stacks.is_empty():
		var no_upgrades = Label.new()
		no_upgrades.text = "No upgrades yet. Level up to unlock upgrades!"
		upgrades_list.add_child(no_upgrades)
		return

	# Sort upgrades by stack count (highest first)
	var sorted_upgrades = player.upgrade_stacks.keys()
	sorted_upgrades.sort_custom(func(a, b): return player.upgrade_stacks[a] > player.upgrade_stacks[b])

	# Display each upgrade
	for upgrade_id in sorted_upgrades:
		var stack_count = player.upgrade_stacks[upgrade_id]
		var upgrade = UpgradeSystem.get_upgrade(upgrade_id)

		if upgrade:
			var upgrade_label = Label.new()
			upgrade_label.text = "• " + upgrade.name + " [Lv. " + str(stack_count) + "]"
			if upgrade.description:
				upgrade_label.text += " - " + upgrade.description
			upgrades_list.add_child(upgrade_label)

func _input(event: InputEvent) -> void:
	# Close stats screen when TAB is pressed
	if visible and event.is_action_pressed("stats_toggle"):
		close_stats()

func close_stats() -> void:
	hide()
	queue_free()
