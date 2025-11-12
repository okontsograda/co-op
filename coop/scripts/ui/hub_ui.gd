extends CanvasLayer

## HubUI - Main UI controller for the hub scene

# UI Panels
@onready var interaction_prompt: PanelContainer = $InteractionPrompt
@onready var zone_label: Label = $InteractionPrompt/VBoxContainer/ZoneLabel
@onready var meta_coins_display: PanelContainer = $MetaCoinsDisplay
@onready var meta_coins_amount: Label = $MetaCoinsDisplay/HBoxContainer/Amount
@onready var host_id_display: PanelContainer = $HostIDDisplay
@onready var copy_button: Button = $HostIDDisplay/VBoxContainer/CopyButton
@onready var ready_status: PanelContainer = $ReadyStatus
@onready var ready_status_label: Label = $ReadyStatus/VBoxContainer/StatusLabel
@onready var ready_button: Button = $ReadyStatus/VBoxContainer/ReadyButton

# UI Screens
@onready var character_ui: PanelContainer = $CharacterCustomizationUI
@onready var character_close_btn: Button = $CharacterCustomizationUI/MarginContainer/VBoxContainer/CloseButton
@onready var class_buttons_container: HBoxContainer = $CharacterCustomizationUI/MarginContainer/VBoxContainer/Content/ClassButtons

@onready var meta_shop_ui: PanelContainer = $MetaShopUI
@onready var shop_close_btn: Button = $MetaShopUI/MarginContainer/VBoxContainer/CloseButton
@onready var shop_item_list: VBoxContainer = $MetaShopUI/MarginContainer/VBoxContainer/ShopContent/ItemList

@onready var stats_ui: PanelContainer = $StatsDisplayUI
@onready var stats_close_btn: Button = $StatsDisplayUI/MarginContainer/VBoxContainer/CloseButton
@onready var stats_content: VBoxContainer = $StatsDisplayUI/MarginContainer/VBoxContainer/StatsContent

@onready var mission_ui: PanelContainer = $MissionBoardUI
@onready var mission_close_btn: Button = $MissionBoardUI/MarginContainer/VBoxContainer/CloseButton
@onready var start_mission_btn: Button = $MissionBoardUI/MarginContainer/VBoxContainer/MissionContent/StartMissionButton
@onready var ready_toggle: CheckButton = $MissionBoardUI/MarginContainer/VBoxContainer/MissionContent/ReadyToggle

# Current zone prompts
const ZONE_NAMES = {
	"character": "Character Selection",
	"shop": "Meta Shop",
	"stats": "Statistics",
	"mission": "Mission Board",
	"teleporter": "Mission Teleporter",
	"skill": "Skill Tree (Coming Soon)"
}

var current_zone: String = ""


func _ready():
	# Connect close buttons
	character_close_btn.pressed.connect(_on_close_ui)
	shop_close_btn.pressed.connect(_on_close_ui)
	stats_close_btn.pressed.connect(_on_close_ui)
	mission_close_btn.pressed.connect(_on_close_ui)

	# Connect mission board buttons
	start_mission_btn.pressed.connect(_on_start_mission_pressed)
	ready_toggle.toggled.connect(_on_ready_toggled)
	ready_button.pressed.connect(_on_ready_button_pressed)

	# Connect copy button
	copy_button.pressed.connect(_on_copy_host_id_pressed)

	# Update meta coins display
	_update_meta_coins()

	# Set up multiplayer-specific UI
	if multiplayer.has_multiplayer_peer():
		ready_status.visible = true
		_update_ready_status()
		HubManager.player_ready_changed.connect(_on_player_ready_changed)

		# Show host ID display if server/host
		if multiplayer.is_server():
			host_id_display.visible = true
			_update_host_id()

	# Build class selection buttons
	_build_class_buttons()

	# Build shop items
	_build_shop_items()

	# Build stats display
	_build_stats_display()


func show_interaction_prompt(zone_type: String, show: bool):
	current_zone = zone_type if show else ""
	interaction_prompt.visible = show

	if show and zone_type in ZONE_NAMES:
		zone_label.text = ZONE_NAMES[zone_type]


func open_ui(zone_type: String):
	match zone_type:
		"character":
			character_ui.visible = true
		"shop":
			meta_shop_ui.visible = true
			_update_meta_coins()  # Refresh coins when opening shop
		"stats":
			stats_ui.visible = true
			_build_stats_display()  # Refresh stats
		"mission", "teleporter":
			mission_ui.visible = true
			_update_mission_ui()
		"skill":
			# Placeholder for future skill tree
			print("[HubUI] Skill tree coming soon!")


func close_ui():
	character_ui.visible = false
	meta_shop_ui.visible = false
	stats_ui.visible = false
	mission_ui.visible = false


func _on_close_ui():
	close_ui()


func _update_meta_coins():
	meta_coins_amount.text = str(SaveSystem.get_meta_coins())


func _build_class_buttons():
	# Clear existing buttons
	for child in class_buttons_container.get_children():
		child.queue_free()

	# Get unlocked classes
	var unlocked_classes = SaveSystem.get_unlocked_classes()
	var all_classes = ["Archer", "Knight", "Mage", "Tank"]

	for p_class in all_classes:
		var btn = Button.new()
		btn.text = p_class
		btn.disabled = not (p_class in unlocked_classes)

		if p_class in unlocked_classes:
			btn.pressed.connect(_on_class_selected.bind(p_class))
		else:
			btn.tooltip_text = "Locked - Purchase in Meta Shop"

		class_buttons_container.add_child(btn)


func _on_class_selected(p_class_name: String):
	print("[HubUI] Class selected: %s" % p_class_name)

	# Update local player data
	var peer_id = multiplayer.get_unique_id()
	if peer_id in LobbyManager.players:
		LobbyManager.players[peer_id]["class"] = p_class_name

		# Determine weapon based on class
		var weapon = "bow"
		if p_class_name == "Knight":
			weapon = "sword"

		LobbyManager.players[peer_id]["weapon"] = weapon

		# Save loadout
		SaveSystem.save_loadout(p_class_name, weapon)

		print("[HubUI] Loadout saved: %s with %s" % [p_class_name, weapon])


func _build_shop_items():
	# Clear existing items
	for child in shop_item_list.get_children():
		child.queue_free()

	# Add shop items (placeholder data)
	var shop_items = [
		{"name": "Unlock Knight Class", "cost": 500, "type": "class", "unlock": "Knight"},
		{"name": "Unlock Mage Class", "cost": 1000, "type": "class", "unlock": "Mage"},
		{"name": "Unlock Tank Class", "cost": 1000, "type": "class", "unlock": "Tank"},
		{"name": "Unlock Rocket Weapon", "cost": 750, "type": "weapon", "unlock": "rocket"},
	]

	for item_data in shop_items:
		var item_panel = PanelContainer.new()
		var hbox = HBoxContainer.new()

		var name_label = Label.new()
		name_label.text = item_data.name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var cost_label = Label.new()
		cost_label.text = str(item_data.cost) + " MC"

		var buy_button = Button.new()
		buy_button.text = "Buy"

		# Check if already unlocked
		var is_unlocked = false
		if item_data.type == "class":
			is_unlocked = SaveSystem.is_class_unlocked(item_data.unlock)
		elif item_data.type == "weapon":
			is_unlocked = SaveSystem.is_weapon_unlocked(item_data.unlock)

		if is_unlocked:
			buy_button.text = "Owned"
			buy_button.disabled = true
		else:
			buy_button.pressed.connect(_on_shop_item_purchased.bind(item_data))

		hbox.add_child(name_label)
		hbox.add_child(cost_label)
		hbox.add_child(buy_button)
		item_panel.add_child(hbox)
		shop_item_list.add_child(item_panel)


func _on_shop_item_purchased(item_data: Dictionary):
	if SaveSystem.spend_meta_currency(item_data.cost):
		# Unlock the item
		if item_data.type == "class":
			SaveSystem.unlock_class(item_data.unlock)
		elif item_data.type == "weapon":
			SaveSystem.unlock_weapon(item_data.unlock)

		print("[HubUI] Purchased: %s" % item_data.name)

		# Refresh UI
		_update_meta_coins()
		_build_shop_items()
		_build_class_buttons()
	else:
		print("[HubUI] Not enough meta coins!")


func _build_stats_display():
	# Clear existing stats
	for child in stats_content.get_children():
		child.queue_free()

	# Add stat labels
	var stats = [
		{"label": "Player Name:", "value": SaveSystem.get_player_name()},
		{"label": "Games Played:", "value": str(SaveSystem.get_games_played())},
		{"label": "Total Kills:", "value": str(SaveSystem.get_total_kills())},
		{"label": "Highest Wave:", "value": str(SaveSystem.get_highest_wave())},
		{"label": "Coins Earned:", "value": str(SaveSystem.get_total_coins_earned())},
		{"label": "Meta Coins:", "value": str(SaveSystem.get_meta_coins())},
		{"label": "Playtime:", "value": _format_time(SaveSystem.get_total_playtime())},
	]

	for stat in stats:
		var hbox = HBoxContainer.new()

		var label_left = Label.new()
		label_left.text = stat.label
		label_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label_right = Label.new()
		label_right.text = str(stat.value)
		label_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		hbox.add_child(label_left)
		hbox.add_child(label_right)
		stats_content.add_child(hbox)


func _format_time(seconds: float) -> String:
	var hours = int(seconds / 3600)
	var minutes = int((seconds - hours * 3600) / 60)
	return "%dh %dm" % [hours, minutes]


func _update_mission_ui():
	# Update ready toggle state
	var peer_id = multiplayer.get_unique_id()
	if peer_id in HubManager.hub_players:
		ready_toggle.button_pressed = HubManager.hub_players[peer_id]["is_ready"]

	# Only host can start mission
	start_mission_btn.disabled = not multiplayer.is_server() or not HubManager.are_all_players_ready()


func _on_ready_toggled(button_pressed: bool):
	var peer_id = multiplayer.get_unique_id()
	HubManager.set_player_ready(peer_id, button_pressed)
	_update_mission_ui()


func _on_ready_button_pressed():
	var peer_id = multiplayer.get_unique_id()
	var current_ready = HubManager.hub_players.get(peer_id, {}).get("is_ready", false)
	HubManager.set_player_ready(peer_id, not current_ready)


func _on_start_mission_pressed():
	if multiplayer.is_server():
		HubManager.start_mission()


func _update_ready_status():
	ready_status_label.text = HubManager.get_ready_status_text()

	# Update button text
	var peer_id = multiplayer.get_unique_id()
	if peer_id in HubManager.hub_players:
		if HubManager.hub_players[peer_id]["is_ready"]:
			ready_button.text = "Not Ready"
		else:
			ready_button.text = "Ready"


func _on_player_ready_changed(_peer_id: int, _is_ready: bool):
	_update_ready_status()
	if mission_ui.visible:
		_update_mission_ui()


func _update_host_id():
	# Wait a moment for NetworkHandler to establish connection
	await get_tree().create_timer(0.5).timeout
	
	# Get the online ID from NetworkHandler
	if NetworkHandler and NetworkHandler.peer:
		var online_id = NetworkHandler.peer.online_id
		if online_id and not online_id.is_empty():
			%OnlineID.text = online_id
			print("[HubUI] Host ID displayed: %s" % online_id)
		else:
			%OnlineID.text = "Connecting..."
			# Try again after a delay
			await get_tree().create_timer(1.0).timeout
			_update_host_id()
	else:
		%OnlineID.text = "Error: No peer connection"


func _on_copy_host_id_pressed():
	if NetworkHandler and NetworkHandler.peer:
		var online_id = NetworkHandler.peer.online_id
		if online_id and not online_id.is_empty():
			DisplayServer.clipboard_set(online_id)
			print("[HubUI] Host ID copied to clipboard: %s" % online_id)
			# Show brief feedback
			copy_button.text = "Copied!"
			await get_tree().create_timer(1.0).timeout
			copy_button.text = "Copy to Clipboard"
