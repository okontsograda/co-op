extends Control

# UI References
@onready var player_list_container = $PlayerListPanel/MarginContainer/VBoxContainer/ScrollContainer/PlayerList
@onready var class_selection_container = $ClassSelectionPanel/MarginContainer/VBoxContainer/ClassGrid
@onready var chat_messages = $ChatPanel/MarginContainer/VBoxContainer/MessageContainer/Messages
@onready var chat_input = $ChatPanel/MarginContainer/VBoxContainer/ChatInput
@onready var online_id_label = $LobbyInfoPanel/MarginContainer/VBoxContainer/InfoHBox/OnlineIDLabel
@onready var copy_button = $LobbyInfoPanel/MarginContainer/VBoxContainer/InfoHBox/CopyButton
@onready var player_count_label = $LobbyInfoPanel/MarginContainer/VBoxContainer/InfoHBox/PlayerCountLabel
@onready var ready_button = $ReadyButton
@onready var start_button = $StartButton

var player_list_items: Dictionary = {}  # {peer_id: Control}
var current_selected_class: String = "archer"


func _ready():
	# Connect to LobbyManager signals
	LobbyManager.player_joined.connect(_on_player_joined)
	LobbyManager.player_left.connect(_on_player_left)
	LobbyManager.player_ready_changed.connect(_on_player_ready_changed)
	LobbyManager.player_class_changed.connect(_on_player_class_changed)
	LobbyManager.player_name_changed.connect(_on_player_name_changed)
	LobbyManager.all_players_ready.connect(_on_all_players_ready)

	# Set up UI
	online_id_label.text = "🔑 Lobby ID: " + LobbyManager.online_id
	copy_button.pressed.connect(_on_copy_button_pressed)
	ready_button.pressed.connect(_on_ready_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	chat_input.text_submitted.connect(_on_chat_submitted)
	if NetworkHandler and not NetworkHandler.chat_message_received.is_connected(_on_lobby_chat_message_received):
		NetworkHandler.chat_message_received.connect(_on_lobby_chat_message_received)

	# Set up class selection
	_setup_class_selection()

	# Update start button visibility (only host can see it)
	start_button.visible = LobbyManager.is_local_player_host()
	start_button.disabled = true

	# Update player count
	_update_player_count()

	# Add existing players to list
	for peer_id in LobbyManager.players:
		_on_player_joined(peer_id, LobbyManager.players[peer_id])
	
	# Set the local player's name from SaveSystem
	_set_local_player_name()


func _setup_class_selection():
	var classes = PlayerClass.get_all_classes()
	for class_id in classes:
		# Skip mage and tank classes
		if class_id == "mage" or class_id == "tank":
			continue
		
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


func _on_player_joined(peer_id: int, player_data: Dictionary):
	if not player_list_items.has(peer_id):
		var player_item = _create_player_list_item(peer_id, player_data)
		player_list_container.add_child(player_item)
		player_list_items[peer_id] = player_item
		_update_player_count()


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

	# Player name label (flex to take remaining space)
	var name_label = Label.new()
	name_label.name = "NameLabel"
	var display_name = player_data.get("player_name", "Player " + str(peer_id))
	name_label.text = display_name
	if player_data["is_host"]:
		name_label.text += " 👑"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size.x = 120
	name_label.clip_text = true
	hbox.add_child(name_label)

	# Class label
	var class_label = Label.new()
	var class_data = PlayerClass.get_class_by_name(player_data["class"])
	class_label.text = class_data["name"]
	class_label.custom_minimum_size.x = 80
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_label.name = "ClassLabel"
	hbox.add_child(class_label)

	# Ready status
	var ready_label = Label.new()
	ready_label.text = "⏳ Not Ready"
	ready_label.name = "ReadyLabel"
	ready_label.custom_minimum_size.x = 90
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_label.modulate = Color(0.8, 0.8, 0.8)
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
	if player_list_items.has(peer_id):
		var panel = player_list_items[peer_id]
		var ready_label = panel.get_node_or_null("MarginContainer/HBoxContainer/ReadyLabel")
		if ready_label:
			ready_label.text = "✅ Ready" if is_ready else "⏳ Not Ready"
			ready_label.modulate = Color(0.4, 1.0, 0.4) if is_ready else Color(0.8, 0.8, 0.8)

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


func _on_player_name_changed(peer_id: int, player_name: String):
	if player_list_items.has(peer_id):
		var panel = player_list_items[peer_id]
		var name_label = panel.get_node_or_null("MarginContainer/HBoxContainer/NameLabel")
		if name_label:
			var is_host = LobbyManager.players[peer_id].get("is_host", false)
			name_label.text = player_name
			if is_host:
				name_label.text += " 👑"
			print("[LobbyUI] Updated display name for peer ", peer_id, " to: ", player_name)


func _set_local_player_name():
	# Wait for SaveSystem to load if needed
	if not SaveSystem.is_loaded:
		await SaveSystem.data_loaded
	
	# Get saved name and send to lobby
	var saved_name = SaveSystem.get_player_name()
	LobbyManager.set_player_name(saved_name)
	print("[LobbyUI] Set local player name in lobby: ", saved_name)


func _on_all_players_ready():
	if LobbyManager.is_local_player_host():
		start_button.disabled = false


func _on_ready_button_pressed():
	var local_id = multiplayer.get_unique_id()
	var is_ready = false
	if LobbyManager.players.has(local_id):
		is_ready = not LobbyManager.players[local_id]["ready"]

	LobbyManager.set_ready(is_ready)
	ready_button.text = "❌ Unready" if is_ready else "✓ Ready"
	ready_button.modulate = Color(0.4, 1.0, 0.4) if is_ready else Color.WHITE


func _on_start_button_pressed():
	LobbyManager.start_game()


func _on_copy_button_pressed():
	DisplayServer.clipboard_set(LobbyManager.online_id)
	copy_button.text = "✅ Copied!"
	await get_tree().create_timer(2.0).timeout
	copy_button.text = "📋 Copy ID"


func _on_kick_player(peer_id: int):
	LobbyManager.kick_player(peer_id)


func _update_player_count():
	player_count_label.text = "👥 Players: " + str(LobbyManager.get_player_count())


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
	var sender_peer_id = int(sender_id)
	var sender_name = LobbyManager.get_player_name(sender_peer_id)
	label.text = sender_name + ": " + message
	chat_messages.add_child(label)

	# Auto-scroll to bottom
	await _scroll_chat_to_bottom()


func _scroll_chat_to_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll := $ChatPanel/MarginContainer/VBoxContainer/MessageContainer
	if scroll is ScrollContainer:
		var v_bar: VScrollBar = scroll.get_v_scroll_bar()
		if v_bar:
			v_bar.value = v_bar.max_value
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value
