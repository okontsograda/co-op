extends Node2D

## Hub Scene Script - Manages hub scene logic and player interactions

@onready var camera: Camera2D = $Camera2D

# Interactive zone references - now pointing to building Area2D nodes
@onready var character_station: Area2D = $Buildings/CharacterHouse/Area2D
@onready var meta_shop: Area2D = $Buildings/MetaShop/Area2D
@onready var stats_display: Area2D = $Buildings/StatsHouse/Area2D
@onready var skill_tree: Area2D = null  # SkillTree building doesn't exist yet
@onready var teleporter_pad: Area2D = $Buildings/Teleporter/Area2D

# Local player reference
var local_player: Node2D = null

# Currently active UI
var active_ui: String = ""


func _enter_tree():
	# Ensure SceneMultiplayer resolves nodes relative to this scene on every peer
	var tree_mp = get_tree().get_multiplayer()
	if tree_mp:
		tree_mp.root_path = NodePath("/root")


func _ready():
	print("[Hub] Hub scene initialized")

	# Connect interaction zones
	_connect_interaction_zones()

	await NetworkHandler.notify_scene_ready(self, NetworkHandler.SceneType.HUB)


func initialize_host_mode(_data: Dictionary = {}):
	print("[Hub] Initializing host hub mode")
	var peer_id = multiplayer.get_unique_id()
	_prepare_hub_state(true, peer_id, true)

	await get_tree().create_timer(0.1).timeout
	var spawner = get_node_or_null("MultiplayerSpawner")
	if spawner and multiplayer.is_server():
		print("[Hub] Server spawning existing players in lobby")
		for player_peer_id in LobbyManager.players:
			spawner.spawn_player(player_peer_id)

		await get_tree().create_timer(0.5).timeout
		await _find_local_player()

		if not multiplayer.peer_connected.is_connected(_on_peer_connected_to_hub):
			multiplayer.peer_connected.connect(_on_peer_connected_to_hub)
	else:
		push_error("[Hub] MultiplayerSpawner not available for host mode!")


func initialize_client_mode(_data: Dictionary = {}):
	print("[Hub] Initializing client hub mode")
	if multiplayer.is_server():
		push_warning("[Hub] Client mode initialization detected server authority, skipping spawn request")
		return

	print("[Hub] Waiting for client peer ID assignment before requesting spawn")
	var has_peer_id := await NetworkHandler._await_client_peer_id(10.0)
	if not has_peer_id:
		push_error("[Hub] Client never received a non-host peer ID; cannot request spawn")
		return
	var peer_id = multiplayer.get_unique_id()

	_prepare_hub_state(true, peer_id, false)

	await get_tree().create_timer(0.1).timeout

	print("[Hub] Client requesting player spawn from server (peer ID: ", peer_id, ")")
	print("[Hub] Sending RPC to server")
	_request_spawn.rpc_id(1)
	print("[Hub] RPC sent, waiting for player to spawn...")
	await _wait_for_local_player()


func initialize_solo_mode():
	print("[Hub] Initializing solo hub mode")
	var peer_id = multiplayer.get_unique_id()
	_prepare_hub_state(false, peer_id, true)
	_spawn_solo_player()
	await get_tree().create_timer(0.5).timeout
	await _find_local_player()


func _prepare_hub_state(is_multiplayer: bool, peer_id: int, is_host: bool) -> void:
	HubManager.initialize_hub(is_multiplayer)
	HubManager.sync_connected_players(peer_id)

	if peer_id not in LobbyManager.players:
		var loadout = SaveSystem.get_last_loadout()
		LobbyManager.players[peer_id] = {
			"class": loadout.class,
			"weapon": loadout.weapon,
			"ready": false,
			"is_host": is_host,
			"player_name": SaveSystem.get_player_name()
		}
	else:
		LobbyManager.players[peer_id]["is_host"] = is_host


# Server receives spawn request from client
@rpc("any_peer", "reliable")
func _request_spawn():
	var requesting_peer = multiplayer.get_remote_sender_id()
	print("[Hub] Received spawn request from peer: ", requesting_peer)

	if multiplayer.is_server():
		# Give the client a moment to fully initialize their scene
		await get_tree().create_timer(0.2).timeout

		var spawner = get_node_or_null("MultiplayerSpawner")
		if spawner:
			print("[Hub] Server spawning player for peer: ", requesting_peer)
			spawner.spawn_player(requesting_peer)
		else:
			print("[Hub] ERROR: MultiplayerSpawner not found!")
	else:
		print("[Hub] _request_spawn called on non-server (peer ", multiplayer.get_unique_id(), "), ignoring")


# Called when a peer connects (server only)
func _on_peer_connected_to_hub(peer_id: int):
	print("[Hub] Peer %d connected to hub, waiting for their spawn request..." % peer_id)


func _wait_for_local_player():
	# Check multiple times with increasing intervals for clients
	var local_peer_id = multiplayer.get_unique_id()
	var max_attempts = 20
	var attempt = 0

	while attempt < max_attempts:
		var player_node = _get_player_node_by_peer(local_peer_id)
		if player_node:
			local_player = player_node
			print("[Hub] Local player found: %d (attempt %d)" % [local_peer_id, attempt + 1])

			# Make camera follow local player
			if camera:
				camera.reparent(local_player)
				camera.position = Vector2.ZERO

			# Disable combat abilities for hub
			_disable_player_combat(local_player)
			return

		attempt += 1
		var wait_time = 0.2 if attempt < 5 else 0.5

		# Debug: list all children to see what nodes exist
		if attempt % 5 == 0:  # Log every 5 attempts
			print("[Hub] Available children in scene:")
			for child in get_children():
				print("  - ", child.name, " (", child.get_class(), ")")

		print("[Hub] Waiting for player node '%s' (attempt %d/%d)" % [str(local_peer_id), attempt, max_attempts])
		await get_tree().create_timer(wait_time).timeout

	print("[Hub] ERROR: Failed to find local player '%s' after %d attempts" % [str(local_peer_id), max_attempts])
	print("[Hub] Final scene children:")
	for child in get_children():
		print("  - ", child.name, " (", child.get_class(), ")")


func _connect_interaction_zones():
	character_station.body_entered.connect(_on_zone_entered.bind("character"))
	character_station.body_exited.connect(_on_zone_exited.bind("character"))

	meta_shop.body_entered.connect(_on_zone_entered.bind("shop"))
	meta_shop.body_exited.connect(_on_zone_exited.bind("shop"))

	stats_display.body_entered.connect(_on_zone_entered.bind("stats"))
	stats_display.body_exited.connect(_on_zone_exited.bind("stats"))

	if skill_tree:
		skill_tree.body_entered.connect(_on_zone_entered.bind("skill"))
		skill_tree.body_exited.connect(_on_zone_exited.bind("skill"))

	teleporter_pad.body_entered.connect(_on_zone_entered.bind("teleporter"))
	teleporter_pad.body_exited.connect(_on_zone_exited.bind("teleporter"))


func _spawn_solo_player():
	print("[Hub] Spawning solo player")
	_spawn_player_internal(multiplayer.get_unique_id())


func _spawn_server_player():
	print("[Hub] Spawning server player")
	_spawn_player_internal(multiplayer.get_unique_id())


func _spawn_player_internal(peer_id: int):
	# Load player scene
	var player_scene = preload("res://coop/scenes/Characters/player.tscn")
	var player = player_scene.instantiate()

	# Set player name to peer ID
	player.name = str(peer_id)

	# Get spawn position
	var spawn_points_node = get_node("SpawnPoints")
	if spawn_points_node and spawn_points_node.get_child_count() > 0:
		var spawn_point = spawn_points_node.get_child(0)
		player.position = spawn_point.position
		print("[Hub] Spawning player %d at position: %s" % [peer_id, player.position])
	else:
		player.position = Vector2(550, 400)
		print("[Hub] No spawn points found, using default position")

	# Add metadata for class/weapon
	# PRIORITY: SaveSystem > LobbyManager (SaveSystem has the persistent saved class)
	var selected_class = ""
	var selected_weapon = "bow"
	
	# Wait for SaveSystem to load if needed
	if not SaveSystem.is_loaded:
		await SaveSystem.data_loaded
	
	# First, try to load from SaveSystem (this is the persistent saved class)
	var saved_class = SaveSystem.get_selected_class()
	if saved_class != "":
		# Convert capitalized SaveSystem format to lowercase for PlayerClass
		selected_class = saved_class.to_lower()
		print("[Hub] Loaded saved class from SaveSystem: %s" % selected_class)
		
		# Get saved weapon from loadout
		var loadout = SaveSystem.get_last_loadout()
		if loadout.has("weapon") and loadout["weapon"] != "":
			selected_weapon = loadout["weapon"].to_lower()
			print("[Hub] Loaded saved weapon from loadout: %s" % selected_weapon)
	
	# Fallback to LobbyManager if SaveSystem doesn't have a class
	if selected_class == "" and peer_id in LobbyManager.players:
		selected_class = LobbyManager.players[peer_id].get("class", "")
		selected_weapon = LobbyManager.players[peer_id].get("weapon", "bow")
		print("[Hub] Loaded class from LobbyManager: %s" % selected_class)
	
	# Set metadata for player BEFORE adding to scene (so _ready() can access it)
	if selected_class != "":
		player.set_meta("selected_class", selected_class)
		player.set_meta("selected_weapon", selected_weapon)
		print("[Hub] Set metadata for player %d: class=%s, weapon=%s" % [peer_id, selected_class, selected_weapon])
	else:
		print("[Hub] WARNING: No class found for player %d, will default to archer" % peer_id)
	
	# Ensure LobbyManager has this data for consistency
	if peer_id in LobbyManager.players:
		if selected_class != "":
			LobbyManager.players[peer_id]["class"] = selected_class
		if selected_weapon != "":
			LobbyManager.players[peer_id]["weapon"] = selected_weapon
	else:
		# If player not in LobbyManager yet, add them
		LobbyManager.register_player(peer_id, peer_id == multiplayer.get_unique_id() and multiplayer.is_server())
		if selected_class != "":
			LobbyManager.players[peer_id]["class"] = selected_class
		if selected_weapon != "":
			LobbyManager.players[peer_id]["weapon"] = selected_weapon

	# Add player to scene (this triggers _ready() which will read the metadata)
	add_child(player)
	print("[Hub] Player %d added to scene tree" % peer_id)


func _find_local_player():
	# Find the player node that belongs to this peer
	var peer_id = multiplayer.get_unique_id()
	var player_node = _get_player_node_by_peer(peer_id)

	if player_node:
		local_player = player_node
		print("[Hub] Local player found: %d" % peer_id)

		# Make camera follow local player
		if camera:
			camera.reparent(local_player)
			camera.position = Vector2.ZERO

		# Disable combat abilities for hub
		_disable_player_combat(local_player)
	else:
		print("[Hub] Warning: Local player not found. Retrying...")
		await get_tree().create_timer(0.5).timeout
		_find_local_player()


func _get_player_node_by_peer(peer_id: int) -> Node2D:
	var node = get_node_or_null(str(peer_id))
	if node and node is Node2D:
		return node

	for player in get_tree().get_nodes_in_group("players"):
		if str(player.name) == str(peer_id):
			return player
		if player.has_meta("peer_id") and int(player.get_meta("peer_id")) == peer_id:
			return player

	return null




func _disable_player_combat(player: Node2D):
	# Disable shooting/combat in hub
	if player.has_method("set_combat_enabled"):
		player.set_combat_enabled(false)
	else:
		# If method doesn't exist, set a metadata flag
		player.set_meta("hub_mode", true)


func _on_zone_entered(body: Node2D, zone_type: String):
	if body != local_player:
		return

	print("[Hub] Entered %s zone" % zone_type)
	# Disabled bottom interaction prompt - using building labels instead
	# _show_interaction_prompt(zone_type, true)


func _on_zone_exited(body: Node2D, zone_type: String):
	if body != local_player:
		return

	print("[Hub] Exited %s zone" % zone_type)
	# Disabled bottom interaction prompt - using building labels instead
	# _show_interaction_prompt(zone_type, false)


func _show_interaction_prompt(zone_type: String, show: bool):
	# This will be handled by HubUI
	if has_node("HubUI"):
		var hub_ui = get_node("HubUI")
		if hub_ui.has_method("show_interaction_prompt"):
			hub_ui.show_interaction_prompt(zone_type, show)


func _process(_delta):
	# Handle interaction input
	if Input.is_action_just_pressed("ui_accept"):  # E or Enter key
		_try_interact()

	# Handle UI closing
	if Input.is_action_just_pressed("ui_cancel"):  # ESC key
		if active_ui != "":
			close_active_ui()


func _try_interact():
	if not local_player:
		return

	# Check which zone the player is in
	var zones: Dictionary = {
		"character": character_station,
		"shop": meta_shop,
		"stats": stats_display,
		"skill": skill_tree,
		"teleporter": teleporter_pad
	}

	for zone_name in zones.keys():
		var zone: Area2D = zones[zone_name]
		if zone == null:
			continue
		if zone.overlaps_body(local_player):
			_open_zone_ui(zone_name)
			return


func _open_zone_ui(zone_type: String):
	print("[Hub] Opening %s UI" % zone_type)

	match zone_type:
		"character":
			_open_character_selection_ui()
		"shop", "stats":
			_open_meta_progression_ui(zone_type)
		_:
			# Use the existing hub UI for other zones (teleporter handles missions)
			if has_node("HubUI"):
				var hub_ui = get_node("HubUI")
				if hub_ui.has_method("open_ui"):
					hub_ui.open_ui(zone_type)
					active_ui = zone_type


func _open_character_selection_ui():
	# Check if character selection UI exists
	var char_ui = get_node_or_null("CharacterSelectionUI")

	if not char_ui:
		# Load and instantiate the character selection UI
		var char_ui_scene = preload("res://coop/scenes/ui/character_selection_ui.tscn")
		char_ui = char_ui_scene.instantiate()
		char_ui.name = "CharacterSelectionUI"
		add_child(char_ui)

		# Connect signals
		char_ui.closed.connect(_on_character_ui_closed)
		char_ui.selection_confirmed.connect(_on_character_selection_confirmed)

	# Open the UI
	char_ui.open()
	active_ui = "character_selection"


func _open_meta_progression_ui(tab: String):
	# Check if meta progression UI instance exists
	var meta_ui = get_node_or_null("MetaProgressionUI")

	if not meta_ui:
		# Load and instantiate the meta progression UI
		var meta_ui_scene = preload("res://coop/scenes/ui/meta_progression/meta_progression_ui.tscn")
		meta_ui = meta_ui_scene.instantiate()
		meta_ui.name = "MetaProgressionUI"
		add_child(meta_ui)

		# Connect signals
		meta_ui.closed.connect(_on_meta_ui_closed)
		meta_ui.item_purchased.connect(_on_item_purchased)

	# Open the UI with the requested tab
	meta_ui.open(tab)
	active_ui = "meta_progression"


func close_active_ui():
	match active_ui:
		"character_selection":
			var char_ui = get_node_or_null("CharacterSelectionUI")
			if char_ui:
				char_ui.close()
		"meta_progression":
			var meta_ui = get_node_or_null("MetaProgressionUI")
			if meta_ui:
				meta_ui.close()
		_:
			if has_node("HubUI"):
				var hub_ui = get_node("HubUI")
				if hub_ui.has_method("close_ui"):
					hub_ui.close_ui()
	active_ui = ""


func _on_meta_ui_closed():
	active_ui = ""
	print("[Hub] Meta progression UI closed")


func _on_item_purchased(item_data: Dictionary):
	print("[Hub] Item purchased: %s" % item_data.name)

	# Play purchase sound effect if available
	# AudioManager.play_sfx("purchase")

	# Show purchase notification if available
	# NotificationManager.show_notification("Purchased: " + item_data.name)


func _on_character_ui_closed():
	active_ui = ""
	print("[Hub] Character selection UI closed")


func _on_character_selection_confirmed(selected_class: String, selected_weapon: String):
	print("[Hub] Character selection confirmed: %s with %s" % [selected_class, selected_weapon])

	# Update player model immediately with new class
	if local_player:
		# Update LobbyManager data for this player
		var peer_id = multiplayer.get_unique_id()
		if peer_id in LobbyManager.players:
			LobbyManager.players[peer_id]["class"] = selected_class
			LobbyManager.players[peer_id]["weapon"] = selected_weapon
		
		# Apply class modifiers to update sprite, stats, and appearance
		if local_player.has_method("apply_class_modifiers"):
			local_player.apply_class_modifiers(selected_class)
			print("[Hub] Applied class modifiers to player model")
		
		# Update weapon if player has the method
		if local_player.has_method("initialize_weapon"):
			local_player.initialize_weapon()
			print("[Hub] Reinitialized weapon for player")
