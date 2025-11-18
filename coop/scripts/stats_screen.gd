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


# Get player's class name
func get_player_class_name() -> String:
	if not player:
		return "Unknown"
	
	# Try to get from LobbyManager first (most up-to-date)
	var peer_id = player.name.to_int() if player.name.is_valid_int() else 0
	if LobbyManager and LobbyManager.players.has(peer_id):
		var class_id = LobbyManager.players[peer_id].get("class", "archer")
		var class_data = PlayerClass.get_class_by_name(class_id)
		return class_data.get("name", "Unknown")
	
	# Try to get class from metadata (fallback)
	if player.has_meta("selected_class"):
		var class_id = str(player.get_meta("selected_class")).to_lower()
		var class_data = PlayerClass.get_class_by_name(class_id)
		return class_data.get("name", "Unknown")
	
	# Try to infer from combat type and stats
	# combat_type is always defined in player.gd, so we can access it directly
	if player.combat_type == "melee":
		return "Knight"
	else:
		# Could be Archer, Mage, or Tank - default to Archer
		return "Archer"


# Get player's class description
func get_player_class_description() -> String:
	if not player:
		return ""
	
	# Try to get from LobbyManager first (most up-to-date)
	var peer_id = player.name.to_int() if player.name.is_valid_int() else 0
	if LobbyManager and LobbyManager.players.has(peer_id):
		var class_id = LobbyManager.players[peer_id].get("class", "archer")
		var class_data = PlayerClass.get_class_by_name(class_id)
		return class_data.get("description", "")
	
	# Try to get class from metadata (fallback)
	if player.has_meta("selected_class"):
		var class_id = str(player.get_meta("selected_class")).to_lower()
		var class_data = PlayerClass.get_class_by_name(class_id)
		return class_data.get("description", "")
	
	return ""


# Update all stat displays
func update_display() -> void:
	if not player:
		return

	# Update player stats (includes class info)
	update_player_stats()

	# Update weapon/melee stats
	update_weapon_stats()

	# Update upgrades list
	update_upgrades_list()


func update_player_stats() -> void:
	# Class Name
	var class_label = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/PlayerStats/StatsGrid/ClassLabel"
	)
	var class_value = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/PlayerStats/StatsGrid/ClassValue"
	)
	if class_label and class_value:
		var player_class_name = get_player_class_name()
		var class_desc = get_player_class_description()
		class_value.text = player_class_name
		if class_desc != "":
			class_value.text += " - " + class_desc
	
	# Team Level
	var level_value = get_node(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/PlayerStats/StatsGrid/LevelValue"
	)
	if level_value:
		level_value.text = str(TeamXP.get_team_level())

	# Health
	var health_value = get_node(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/PlayerStats/StatsGrid/HealthValue"
	)
	if health_value:
		health_value.text = str(player.current_health) + " / " + str(player.max_health)

	# Team XP
	var xp_value = get_node(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/PlayerStats/StatsGrid/XPValue"
	)
	if xp_value:
		xp_value.text = str(TeamXP.get_team_xp()) + " / " + str(TeamXP.get_xp_to_next_level())
	
	# Base Stats Section
	update_base_stats()
	
	# Class-Modified Stats Section
	update_class_modified_stats()


func update_base_stats() -> void:
	# Base Health
	var base_health_value = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/BaseStats/StatsGrid/BaseHealthValue"
	)
	if base_health_value:
		base_health_value.text = str(player.base_max_health)
	
	# Base Damage
	var base_damage_value = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/BaseStats/StatsGrid/BaseDamageValue"
	)
	if base_damage_value:
		base_damage_value.text = str(player.base_attack_damage)
	
	# Base Walk Speed
	var base_walk_speed_value = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/BaseStats/StatsGrid/BaseWalkSpeedValue"
	)
	if base_walk_speed_value:
		base_walk_speed_value.text = str(snappedf(player.base_walk_speed, 0.1))
	
	# Base Run Speed
	var base_run_speed_value = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/BaseStats/StatsGrid/BaseRunSpeedValue"
	)
	if base_run_speed_value:
		base_run_speed_value.text = str(snappedf(player.base_run_speed, 0.1))
	
	# Base Fire Cooldown
	var base_fire_cooldown_value = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/BaseStats/StatsGrid/BaseFireCooldownValue"
	)
	if base_fire_cooldown_value:
		base_fire_cooldown_value.text = str(snappedf(player.base_fire_cooldown, 0.1)) + "s"


func update_class_modified_stats() -> void:
	# Modified Health
	var modified_health_value = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/ClassModifiedStats/StatsGrid/ModifiedHealthValue"
	)
	if modified_health_value:
		modified_health_value.text = str(player.current_health) + " / " + str(player.max_health)
	
	# Modified Damage
	var modified_damage_value = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/ClassModifiedStats/StatsGrid/ModifiedDamageValue"
	)
	if modified_damage_value:
		modified_damage_value.text = str(player.attack_damage)
	
	# Modified Walk Speed
	var modified_walk_speed_value = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/ClassModifiedStats/StatsGrid/ModifiedWalkSpeedValue"
	)
	if modified_walk_speed_value:
		modified_walk_speed_value.text = str(snappedf(player.walk_speed, 0.1))
	
	# Modified Run Speed
	var modified_run_speed_value = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/ClassModifiedStats/StatsGrid/ModifiedRunSpeedValue"
	)
	if modified_run_speed_value:
		modified_run_speed_value.text = str(snappedf(player.run_speed, 0.1))
	
	# Modified Fire Cooldown
	var modified_fire_cooldown_value = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/ClassModifiedStats/StatsGrid/ModifiedFireCooldownValue"
	)
	if modified_fire_cooldown_value:
		modified_fire_cooldown_value.text = str(snappedf(player.fire_cooldown, 0.1)) + "s"


func update_weapon_stats() -> void:
	var ws = player.weapon_stats
	# combat_type is always defined in player.gd
	var is_melee = player.combat_type == "melee"
	
	# Update section title based on combat type
	var section_title = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/SectionTitle"
	)
	if section_title:
		if is_melee:
			section_title.text = "MELEE STATS"
		else:
			section_title.text = "WEAPON STATS"
	
	# Calculate final damage
	var final_damage = (player.attack_damage + ws.damage) * ws.damage_multiplier
	var damage_value = get_node(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/DamageValue"
	)
	if damage_value:
		damage_value.text = str(snappedf(final_damage, 0.1))
		if ws.damage_multiplier > 1.0:
			damage_value.text += " (x" + str(snappedf(ws.damage_multiplier, 0.1)) + ")"

	# Attack Speed / Fire Rate
	var fire_rate_label = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/FireRateLabel"
	)
	var fire_rate_value = get_node(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/FireRateValue"
	)
	if fire_rate_label and fire_rate_value:
		var attacks_per_sec = 1.0 / ws.fire_cooldown
		if is_melee:
			fire_rate_label.text = "Attack Speed:"
			fire_rate_value.text = str(snappedf(attacks_per_sec, 0.1)) + " swings/sec"
		else:
			fire_rate_label.text = "Fire Rate:"
			fire_rate_value.text = str(snappedf(attacks_per_sec, 0.1)) + " shots/sec"

	# Multishot (ranged only)
	var multishot_label = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/MultishotLabel"
	)
	var multishot_value = get_node(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/MultishotValue"
	)
	if multishot_label and multishot_value:
		if is_melee:
			multishot_label.visible = false
			multishot_value.visible = false
		else:
			multishot_label.visible = true
			multishot_value.visible = true
			var arrow_text = " arrow" if ws.multishot_count == 1 else " arrows"
			multishot_value.text = str(ws.multishot_count) + arrow_text

	# Pierce (ranged only)
	var pierce_label = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/PierceLabel"
	)
	var pierce_value = get_node(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/PierceValue"
	)
	if pierce_label and pierce_value:
		if is_melee:
			pierce_label.visible = false
			pierce_value.visible = false
		else:
			pierce_label.visible = true
			pierce_value.visible = true
			if ws.pierce_count == 0:
				pierce_value.text = "None"
			else:
				var enemy_text = " enemy" if ws.pierce_count == 1 else " enemies"
				pierce_value.text = str(ws.pierce_count) + enemy_text

	# Crit chance
	var crit_value = get_node(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/CritChanceValue"
	)
	if crit_value:
		crit_value.text = str(snappedf(ws.crit_chance * 100, 1)) + "%"
		if ws.crit_chance > 0:
			crit_value.text += " (x" + str(ws.crit_multiplier) + ")"

	# Attack Range (melee) / Arrow Speed (ranged)
	var speed_label = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/ArrowSpeedLabel"
	)
	var speed_value = get_node(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/ArrowSpeedValue"
	)
	if speed_label and speed_value:
		if is_melee:
			speed_label.text = "Attack Range:"
			# melee_attack_range is always defined in player.gd
			var base_range = player.melee_attack_range
			var range_mult = 1.0
			if "attack_range_mult" in ws:
				range_mult = ws["attack_range_mult"]
			var final_range = base_range * range_mult
			speed_value.text = str(snappedf(final_range, 0.1)) + " pixels"
		else:
			speed_label.text = "Arrow Speed:"
			speed_value.text = str(int(ws.arrow_speed))

	# Explosion chance (ranged only)
	var explosion_label = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/ExplosionLabel"
	)
	var explosion_value = get_node(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/ExplosionValue"
	)
	if explosion_label and explosion_value:
		if is_melee:
			explosion_label.visible = false
			explosion_value.visible = false
		else:
			explosion_label.visible = true
			explosion_value.visible = true
			explosion_value.text = str(snappedf(ws.explosion_chance * 100, 1)) + "%"
			if ws.explosion_chance > 0:
				explosion_value.text += " (radius: " + str(int(ws.explosion_radius)) + ")"

	# Lifesteal
	var lifesteal_value = get_node(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/LifestealValue"
	)
	if lifesteal_value:
		if ws.lifesteal == 0:
			lifesteal_value.text = "None"
		else:
			lifesteal_value.text = str(ws.lifesteal) + " HP per hit"

	# Homing (ranged only)
	var homing_label = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/HomingLabel"
	)
	var homing_value = get_node(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/HomingValue"
	)
	if homing_label and homing_value:
		if is_melee:
			homing_label.visible = false
			homing_value.visible = false
		else:
			homing_label.visible = true
			homing_value.visible = true
			if ws.homing_strength == 0:
				homing_value.text = "None"
			else:
				homing_value.text = str(snappedf(ws.homing_strength * 100, 1)) + "%"
	
	# Combo Info (melee only)
	var combo_label = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/ComboLabel"
	)
	var combo_value = get_node_or_null(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/ComboValue"
	)
	if combo_label and combo_value:
		if is_melee:
			combo_label.visible = true
			combo_value.visible = true
			# combo_cooldown_ready and combo_cooldown_time are always defined in player.gd
			if player.combo_cooldown_ready:
				combo_value.text = "Ready"
			elif player.combo_cooldown_time > 0:
				var cooldown_remaining = snappedf(player.combo_cooldown_time, 0.1)
				combo_value.text = "Cooldown: " + str(cooldown_remaining) + "s"
			else:
				combo_value.text = "Available"
		else:
			combo_label.visible = false
			combo_value.visible = false


func update_upgrades_list() -> void:
	var upgrades_list = get_node(
		"MarginContainer/VBoxContainer/ScrollContainer/Content/ActiveUpgrades/UpgradesList"
	)
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
	sorted_upgrades.sort_custom(
		func(a, b): return player.upgrade_stacks[a] > player.upgrade_stacks[b]
	)

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
