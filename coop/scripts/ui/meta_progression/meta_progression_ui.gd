extends CanvasLayer

signal closed
signal class_selected(selected_class: String)
signal item_purchased(item_data: Dictionary)

# UI References
@onready var coins_label: Label = $Control/MainContainer/VBoxContainer/Header/MetaCoinsDisplay/HBoxContainer/CoinsLabel
@onready var tab_container: TabContainer = $Control/MainContainer/VBoxContainer/TabContainer

# Character Tab
@onready var class_grid: GridContainer = $Control/MainContainer/VBoxContainer/TabContainer/Character/VBoxContainer/ClassGrid
@onready var selected_class_name: Label = $Control/MainContainer/VBoxContainer/TabContainer/Character/VBoxContainer/SelectedClassInfo/VBoxContainer/ClassName
@onready var selected_class_desc: Label = $Control/MainContainer/VBoxContainer/TabContainer/Character/VBoxContainer/SelectedClassInfo/VBoxContainer/ClassDescription

# Shop Tab
@onready var shop_item_list: VBoxContainer = $Control/MainContainer/VBoxContainer/TabContainer/Shop/VBoxContainer/ScrollContainer/ShopItemList
@onready var filter_buttons: HBoxContainer = $Control/MainContainer/VBoxContainer/TabContainer/Shop/VBoxContainer/ShopHeader/FilterButtons

# Stats Tab
@onready var general_stats_list: VBoxContainer = $Control/MainContainer/VBoxContainer/TabContainer/Stats/VBoxContainer/StatsGrid/GeneralStats/VBoxContainer/StatsList
@onready var combat_stats_list: VBoxContainer = $Control/MainContainer/VBoxContainer/TabContainer/Stats/VBoxContainer/StatsGrid/CombatStats/VBoxContainer/StatsList

# Achievements Tab
@onready var achievements_list: VBoxContainer = $Control/MainContainer/VBoxContainer/TabContainer/Achievements/VBoxContainer/ScrollContainer/AchievementsList

# Preload prefabs
var shop_item_scene = preload("res://coop/scenes/ui/meta_progression/shop_item.tscn")
var stat_display_scene = preload("res://coop/scenes/ui/meta_progression/stat_display.tscn")
var class_button_scene = preload("res://coop/scenes/ui/meta_progression/class_button.tscn")

# Current state
var current_filter: String = "all"
var selected_class: String = ""

# Shop data (this would normally come from a data file or database)
var shop_items = [
	{"name": "Knight Class", "description": "A tanky melee fighter with high defense", "cost": 500, "type": "class", "unlock": "Knight", "icon": "🛡️"},
	{"name": "Mage Class", "description": "A powerful spellcaster with elemental abilities", "cost": 750, "type": "class", "unlock": "Mage", "icon": "🔮"},
	{"name": "Tank Class", "description": "The ultimate defender with crowd control", "cost": 1000, "type": "class", "unlock": "Tank", "icon": "🏰"},
	{"name": "Sword", "description": "A reliable melee weapon", "cost": 300, "type": "weapon", "unlock": "sword", "icon": "⚔️"},
	{"name": "Staff", "description": "Increases magic damage", "cost": 400, "type": "weapon", "unlock": "staff", "icon": "🪄"},
	{"name": "Shield", "description": "Provides extra defense", "cost": 350, "type": "weapon", "unlock": "shield", "icon": "🛡️"},
	{"name": "Golden Armor", "description": "Shiny cosmetic armor skin", "cost": 200, "type": "cosmetic", "unlock": "golden_armor", "icon": "✨"},
	{"name": "Shadow Cloak", "description": "Dark mysterious cloak cosmetic", "cost": 250, "type": "cosmetic", "unlock": "shadow_cloak", "icon": "🌑"},
]

# Class data
var class_data = {
	"Archer": {"description": "A ranged damage dealer with high mobility and precision.", "icon": "🏹"},
	"Knight": {"description": "A tanky melee fighter with high defense and sword mastery.", "icon": "⚔️"},
	"Mage": {"description": "A powerful spellcaster with elemental abilities and area damage.", "icon": "🔮"},
	"Tank": {"description": "The ultimate defender with crowd control and damage mitigation.", "icon": "🛡️"}
}

func _ready():
	visible = false
	_setup_ui()

func _setup_ui():
	# Set up filter button group
	var button_group = ButtonGroup.new()
	for button in filter_buttons.get_children():
		button.button_group = button_group

func open(tab: String = ""):
	visible = true
	_update_meta_coins()

	# Switch to requested tab
	match tab:
		"character":
			tab_container.current_tab = 0
			_populate_classes()
		"shop":
			tab_container.current_tab = 1
			_populate_shop()
		"stats":
			tab_container.current_tab = 2
			_populate_stats()
		"achievements":
			tab_container.current_tab = 3
			_populate_achievements()
		_:
			# Default to character tab
			tab_container.current_tab = 0
			_populate_classes()

	# Populate all tabs
	_populate_classes()
	_populate_shop()
	_populate_stats()
	_populate_achievements()

func close():
	visible = false
	closed.emit()

func _update_meta_coins():
	var coins = SaveSystem.get_meta_coins()
	coins_label.text = str(coins) + " MC"

func _populate_classes():
	# Clear existing buttons
	for child in class_grid.get_children():
		child.queue_free()

	var unlocked_classes = SaveSystem.get_unlocked_classes()
	var current_class = SaveSystem.get_selected_class()

	for p_class_name in class_data.keys():
		var class_button = class_button_scene.instantiate()

		# Add to scene tree FIRST
		class_grid.add_child(class_button)

		# THEN setup and configure
		class_button.setup(p_class_name, class_data[p_class_name], p_class_name in unlocked_classes)
		class_button.class_selected.connect(_on_class_selected)

		# Highlight if currently selected
		if p_class_name == current_class:
			class_button.set_selected(true)
			selected_class = p_class_name
			_update_selected_class_info(p_class_name)

func _populate_shop():
	# Clear existing items
	for child in shop_item_list.get_children():
		child.queue_free()

	# Filter items based on current filter
	var filtered_items = []
	for item in shop_items:
		if current_filter == "all" or item.type == current_filter:
			filtered_items.append(item)

	# Create shop item instances
	for item_data in filtered_items:
		var shop_item = shop_item_scene.instantiate()
		shop_item_list.add_child(shop_item)  # Add to tree FIRST
		shop_item.setup(item_data)  # THEN setup
		shop_item.purchase_requested.connect(_on_purchase_requested)

func _populate_stats():
	# Clear existing stats
	for child in general_stats_list.get_children():
		child.queue_free()
	for child in combat_stats_list.get_children():
		child.queue_free()

	# General stats
	var general_stats = [
		{"label": "Player Name", "value": SaveSystem.get_player_name()},
		{"label": "Games Played", "value": str(SaveSystem.get_games_played())},
		{"label": "Playtime", "value": _format_time(SaveSystem.get_total_playtime())},
		{"label": "Meta Coins", "value": str(SaveSystem.get_meta_coins())},
		{"label": "Total Coins Earned", "value": str(SaveSystem.get_total_coins_earned())},
	]

	for stat in general_stats:
		var stat_display = stat_display_scene.instantiate()
		general_stats_list.add_child(stat_display)  # Add to tree FIRST
		stat_display.setup(stat.label, stat.value)  # THEN setup

	# Combat stats
	var combat_stats = [
		{"label": "Total Kills", "value": str(SaveSystem.get_total_kills())},
		{"label": "Highest Wave", "value": str(SaveSystem.get_highest_wave())},
		{"label": "Boss Kills", "value": str(SaveSystem.get_boss_kills())},
		{"label": "Deaths", "value": str(SaveSystem.get_deaths())},
		{"label": "Damage Dealt", "value": str(SaveSystem.get_damage_dealt())},
	]

	for stat in combat_stats:
		var stat_display = stat_display_scene.instantiate()
		combat_stats_list.add_child(stat_display)  # Add to tree FIRST
		stat_display.setup(stat.label, stat.value)  # THEN setup

func _populate_achievements():
	# Placeholder for achievements system
	var placeholder_label = Label.new()
	placeholder_label.text = "Achievements coming soon!"
	placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	achievements_list.add_child(placeholder_label)

func _on_class_selected(p_class_name: String):
	selected_class = p_class_name
	SaveSystem.set_selected_class(p_class_name)
	_update_selected_class_info(p_class_name)

	# Update all class buttons to reflect selection
	for button in class_grid.get_children():
		button.set_selected(button.player_class == p_class_name)

	class_selected.emit(p_class_name)

func _update_selected_class_info(p_class_name: String):
	if p_class_name in class_data:
		selected_class_name.text = p_class_name
		selected_class_desc.text = class_data[p_class_name].description

func _on_purchase_requested(item_data: Dictionary):
	var cost = item_data.cost

	if SaveSystem.get_meta_coins() >= cost:
		# Process purchase
		SaveSystem.spend_meta_currency(cost)

		# Unlock the item
		match item_data.type:
			"class":
				SaveSystem.unlock_class(item_data.unlock)
				_populate_classes()  # Refresh class buttons
			"weapon":
				SaveSystem.unlock_weapon(item_data.unlock)
			"cosmetic":
				SaveSystem.unlock_cosmetic(item_data.unlock)

		# Update UI
		_update_meta_coins()
		_populate_shop()  # Refresh shop to show owned items

		# Emit signal
		item_purchased.emit(item_data)

		print("[MetaProgression] Purchased: %s for %d MC" % [item_data.name, cost])
	else:
		print("[MetaProgression] Insufficient funds for: %s (need %d MC, have %d MC)" %
			[item_data.name, cost, SaveSystem.get_meta_coins()])

func _on_filter_button_pressed(filter_type: String):
	current_filter = filter_type
	_populate_shop()

func _on_close_button_pressed():
	close()

func _format_time(seconds: int) -> String:
	var hours = seconds / 3600
	var minutes = (seconds % 3600) / 60
	var secs = seconds % 60

	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	elif minutes > 0:
		return "%dm %ds" % [minutes, secs]
	else:
		return "%ds" % secs