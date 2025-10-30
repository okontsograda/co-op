extends Control

# UI References
@onready var player_list_container = $PlayerListPanel/VBoxContainer/ScrollContainer/PlayerList
@onready var class_selection_container = $ClassSelectionPanel/VBoxContainer/ClassGrid
@onready var weapon_selection_container = $WeaponSelectionPanel/VBoxContainer/WeaponGrid
@onready var chat_messages = $ChatPanel/VBoxContainer/MessageContainer/Messages
@onready var chat_input = $ChatPanel/VBoxContainer/ChatInput
@onready var online_id_label = $LobbyInfoPanel/VBoxContainer/OnlineIDLabel
@onready var copy_button = $LobbyInfoPanel/VBoxContainer/HBoxContainer/CopyButton
@onready var player_count_label = $LobbyInfoPanel/VBoxContainer/PlayerCountLabel
@onready var ready_button = $ReadyButton
@onready var start_button = $StartButton

var player_list_items: Dictionary = {}  # {peer_id: Control}
var current_selected_class: String = "archer"
var current_selected_weapon: String = "bow"


func _ready():
	# Connect to LobbyManager signals
	LobbyManager.player_joined.connect(_on_player_joined)
	LobbyManager.player_left.connect(_on_player_left)
	LobbyManager.player_ready_changed.connect(_on_player_ready_changed)
	LobbyManager.player_class_changed.connect(_on_player_class_changed)
	LobbyManager.player_weapon_changed.connect(_on_player_weapon_changed)
	LobbyManager.all_players_ready.connect(_on_all_players_ready)

	print("Lobby UI signals connected")

	# Set up UI
	online_id_label.text = "Lobby ID: " + LobbyManager.online_id
	copy_button.pressed.connect(_on_copy_button_pressed)
	ready_button.pressed.connect(_on_ready_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	chat_input.text_submitted.connect(_on_chat_submitted)
	if NetworkHandler and not NetworkHandler.chat_message_received.is_connected(_on_lobby_chat_message_received):
		NetworkHandler.chat_message_received.connect(_on_lobby_chat_message_received)

	# Set up class selection
	_setup_class_selection()

	# Set up weapon selection
	_setup_weapon_selection()

	# Update start button visibility (only host can see it)
	start_button.visible = LobbyManager.is_local_player_host()
	start_button.disabled = true

	# Update player count
	_update_player_count()

	# Add existing players to list
	print("Adding existing players to lobby UI...")
	print("LobbyManager.players: ", LobbyManager.players)
	for peer_id in LobbyManager.players:
		print("Adding existing player: ", peer_id)
		_on_player_joined(peer_id, LobbyManager.players[peer_id])
	print("Finished adding existing players. Total in UI: ", player_list_items.size())


func _setup_class_selection():
	var classes = PlayerClass.get_all_classes()
	for class_id in classes:
		var class_data = classes[class_id]

		var button = Button.new()
		button.name = "Class_" + class_id
		button.text = class_data["name"]
		button.custom_minimum_size = Vector2(180, 80)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_class_selected.bind(class_id))

		class_selection_container.add_child(button)

		# Highlight selected class
		if class_id == current_selected_class:
			button.modulate = Color(1.2, 1.2, 1.2)


func _on_class_selected(class_id: String):
	current_selected_class = class_id
	LobbyManager.set_player_class(class_id)

	# Update button highlights
	for child in class_selection_container.get_children():
		if child is Button:
			if child.name == "Class_" + class_id:
				child.modulate = Color(1.2, 1.2, 1.2)
			else:
				child.modulate = Color.WHITE


func _setup_weapon_selection():
	var weapons = WeaponData.get_all_weapons()
	for weapon_id in weapons:
		var weapon_config = weapons[weapon_id]

		var button = Button.new()
		button.name = "Weapon_" + weapon_id
		button.text = weapon_config.name
		button.custom_minimum_size = Vector2(180, 80)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_weapon_selected.bind(weapon_id))

		weapon_selection_container.add_child(button)

		# Highlight selected weapon
		if weapon_id == current_selected_weapon:
			button.modulate = Color(1.2, 1.2, 1.2)


func _on_weapon_selected(weapon_id: String):
	current_selected_weapon = weapon_id
	LobbyManager.set_player_weapon(weapon_id)

	# Update button highlights
	for child in weapon_selection_container.get_children():
		if child is Button:
			if child.name == "Weapon_" + weapon_id:
				child.modulate = Color(1.2, 1.2, 1.2)
			else:
				child.modulate = Color.WHITE


func _on_player_joined(peer_id: int, player_data: Dictionary):
	print("Player joined callback: peer_id=", peer_id, " data=", player_data)
	if not player_list_items.has(peer_id):
		var player_item = _create_player_list_item(peer_id, player_data)
		player_list_container.add_child(player_item)
		player_list_items[peer_id] = player_item
		print("Added player ", peer_id, " to list. Total players: ", player_list_items.size())
		_update_player_count()
	else:
		print("Player ", peer_id, " already in list")


func _create_player_list_item(peer_id: int, player_data: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.name = "Player_" + str(peer_id)

	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.name = "HBoxContainer"
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	# Player ID label (flex to take remaining space)
	var id_label = Label.new()
	id_label.text = "Player " + str(peer_id)
	if player_data["is_host"]:
		id_label.text += " (Host)"
	id_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_label.custom_minimum_size.x = 120
	id_label.clip_text = true
	hbox.add_child(id_label)

	# Class label
	var class_label = Label.new()
	var class_data = PlayerClass.get_class_by_name(player_data["class"])
	class_label.text = class_data["name"]
	class_label.custom_minimum_size.x = 80
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_label.name = "ClassLabel"
	hbox.add_child(class_label)

	# Weapon label
	var weapon_label = Label.new()
	var weapon_config = WeaponData.get_weapon(player_data["weapon"])
	weapon_label.text = weapon_config.name
	weapon_label.custom_minimum_size.x = 100
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_label.name = "WeaponLabel"
	hbox.add_child(weapon_label)

	# Ready status
	var ready_label = Label.new()
	ready_label.text = "Not Ready"
	ready_label.name = "ReadyLabel"
	ready_label.custom_minimum_size.x = 80
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(ready_label)

	# Kick button (only visible to host for other players)
	if LobbyManager.is_local_player_host() and not player_data["is_host"]:
		var kick_btn = Button.new()
		kick_btn.text = "Kick"
		kick_btn.custom_minimum_size.x = 60
		kick_btn.pressed.connect(_on_kick_player.bind(peer_id))
		hbox.add_child(kick_btn)

	return panel


func _on_player_left(peer_id: int):
	if player_list_items.has(peer_id):
		player_list_items[peer_id].queue_free()
		player_list_items.erase(peer_id)
		_update_player_count()


func _on_player_ready_changed(peer_id: int, is_ready: bool):
	print("Player ready changed callback: peer_id=", peer_id, " is_ready=", is_ready)
	print("Player list items keys: ", player_list_items.keys())

	if player_list_items.has(peer_id):
		var panel = player_list_items[peer_id]
		print("Found panel for peer ", peer_id)
		var ready_label = panel.get_node_or_null("MarginContainer/HBoxContainer/ReadyLabel")
		if ready_label:
			print("Updating ready label for peer ", peer_id)
			ready_label.text = "Ready!" if is_ready else "Not Ready"
			ready_label.modulate = Color.GREEN if is_ready else Color.WHITE
		else:
			print("ERROR: Could not find ReadyLabel at path MarginContainer/HBoxContainer/ReadyLabel")
			print("Panel children: ", panel.get_children())
	else:
		print("ERROR: Player ", peer_id, " not found in player_list_items")

	# Update start button state
	if LobbyManager.is_local_player_host():
		start_button.disabled = not LobbyManager.are_all_players_ready()


func _on_player_class_changed(peer_id: int, selected_class: String):
	if player_list_items.has(peer_id):
		var panel = player_list_items[peer_id]
		var class_label = panel.get_node_or_null("MarginContainer/HBoxContainer/ClassLabel")
		if class_label:
			var class_data = PlayerClass.get_class_by_name(selected_class)
			class_label.text = class_data["name"]
		else:
			print("ERROR: Could not find ClassLabel for peer ", peer_id)


func _on_player_weapon_changed(peer_id: int, selected_weapon: String):
	if player_list_items.has(peer_id):
		var panel = player_list_items[peer_id]
		var weapon_label = panel.get_node_or_null("MarginContainer/HBoxContainer/WeaponLabel")
		if weapon_label:
			var weapon_config = WeaponData.get_weapon(selected_weapon)
			weapon_label.text = weapon_config.name
		else:
			print("ERROR: Could not find WeaponLabel for peer ", peer_id)


func _on_all_players_ready():
	if LobbyManager.is_local_player_host():
		start_button.disabled = false


func _on_ready_button_pressed():
	var local_id = multiplayer.get_unique_id()
	var is_ready = false
	if LobbyManager.players.has(local_id):
		is_ready = not LobbyManager.players[local_id]["ready"]

	print("Ready button pressed, setting ready to: ", is_ready)
	LobbyManager.set_ready(is_ready)
	ready_button.text = "Unready" if is_ready else "Ready"
	ready_button.modulate = Color.GREEN if is_ready else Color.WHITE


func _on_start_button_pressed():
	LobbyManager.start_game()


func _on_copy_button_pressed():
	DisplayServer.clipboard_set(LobbyManager.online_id)
	copy_button.text = "Copied!"
	await get_tree().create_timer(2.0).timeout
	copy_button.text = "Copy ID"


func _on_kick_player(peer_id: int):
	LobbyManager.kick_player(peer_id)


func _update_player_count():
	player_count_label.text = "Players: " + str(LobbyManager.get_player_count())


func _on_chat_submitted(text: String):
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		chat_input.text = ""
		chat_input.grab_focus()
		return

	NetworkHandler.send_chat_message(trimmed)
	chat_input.text = ""
	chat_input.release_focus()


func _on_lobby_chat_message_received(sender_id: String, message: String) -> void:
	add_chat_message(sender_id, message)


# Called from NetworkHandler when chat message received
func add_chat_message(sender_id: String, message: String):
	var label = Label.new()
	label.text = "Player " + str(sender_id) + ": " + message
	chat_messages.add_child(label)

	# Auto-scroll to bottom
	await _scroll_chat_to_bottom()


func _scroll_chat_to_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll := $ChatPanel/VBoxContainer/MessageContainer
	if scroll is ScrollContainer:
		var v_bar: VScrollBar = scroll.get_v_scroll_bar()
		if v_bar:
			v_bar.value = v_bar.max_value
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value
