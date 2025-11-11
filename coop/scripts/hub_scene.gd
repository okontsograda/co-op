extends Node2D

## Hub Scene Script - Manages hub scene logic and player interactions

@onready var camera: Camera2D = $Camera2D
@onready var interactive_zones: Node2D = $InteractiveZones

# Interactive zone references
@onready var character_station: Area2D = $InteractiveZones/CharacterStation
@onready var meta_shop: Area2D = $InteractiveZones/MetaShop
@onready var stats_display: Area2D = $InteractiveZones/StatsDisplay
@onready var mission_board: Area2D = $InteractiveZones/MissionBoard
@onready var skill_tree: Area2D = $InteractiveZones/SkillTree

# Local player reference
var local_player: Node2D = null

# Currently active UI
var active_ui: String = ""


func _ready():
	print("[Hub] Hub scene initialized")

	# Initialize HubManager
	var is_multiplayer = multiplayer.has_multiplayer_peer()
	HubManager.initialize_hub(is_multiplayer)

	# Register local player in hub
	var peer_id = multiplayer.get_unique_id()
	HubManager.register_player(peer_id)

	# Set up LobbyManager player data if not exists
	if peer_id not in LobbyManager.players:
		var loadout = SaveSystem.get_last_loadout()
		LobbyManager.players[peer_id] = {
			"class": loadout.class,
			"weapon": loadout.weapon,
			"ready": false,
			"is_host": multiplayer.is_server(),
			"player_name": SaveSystem.get_player_name()
		}

	# Connect interaction zones
	_connect_interaction_zones()

	# Spawn player
	if not is_multiplayer:
		# Solo mode - spawn local player
		_spawn_solo_player()
	elif multiplayer.is_server():
		# Multiplayer mode - spawn server player
		_spawn_server_player()
	# Clients will be spawned by MultiplayerSpawner automatically

	# Wait for player to spawn
	await get_tree().create_timer(0.5).timeout
	_find_local_player()


func _connect_interaction_zones():
	character_station.body_entered.connect(_on_zone_entered.bind("character"))
	character_station.body_exited.connect(_on_zone_exited.bind("character"))

	meta_shop.body_entered.connect(_on_zone_entered.bind("shop"))
	meta_shop.body_exited.connect(_on_zone_exited.bind("shop"))

	stats_display.body_entered.connect(_on_zone_entered.bind("stats"))
	stats_display.body_exited.connect(_on_zone_exited.bind("stats"))

	mission_board.body_entered.connect(_on_zone_entered.bind("mission"))
	mission_board.body_exited.connect(_on_zone_exited.bind("mission"))

	skill_tree.body_entered.connect(_on_zone_entered.bind("skill"))
	skill_tree.body_exited.connect(_on_zone_exited.bind("skill"))


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
	if peer_id in LobbyManager.players:
		player.set_meta("selected_class", LobbyManager.players[peer_id]["class"])
		player.set_meta("selected_weapon", LobbyManager.players[peer_id]["weapon"])

	# Add player to scene
	add_child(player)
	print("[Hub] Player spawned: %d" % peer_id)


func _find_local_player():
	# Find the player node that belongs to this peer
	var peer_id = multiplayer.get_unique_id()
	var player_node = get_node_or_null(str(peer_id))

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
	# Show interaction prompt
	_show_interaction_prompt(zone_type, true)


func _on_zone_exited(body: Node2D, zone_type: String):
	if body != local_player:
		return

	print("[Hub] Exited %s zone" % zone_type)
	_show_interaction_prompt(zone_type, false)


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


func _try_interact():
	if not local_player:
		return

	# Check which zone the player is in
	var zones = {
		"character": character_station,
		"shop": meta_shop,
		"stats": stats_display,
		"mission": mission_board,
		"skill": skill_tree
	}

	for zone_name in zones:
		var zone = zones[zone_name]
		if zone.overlaps_body(local_player):
			_open_zone_ui(zone_name)
			return


func _open_zone_ui(zone_type: String):
	print("[Hub] Opening %s UI" % zone_type)

	if has_node("HubUI"):
		var hub_ui = get_node("HubUI")
		if hub_ui.has_method("open_ui"):
			hub_ui.open_ui(zone_type)
			active_ui = zone_type


func close_active_ui():
	if has_node("HubUI"):
		var hub_ui = get_node("HubUI")
		if hub_ui.has_method("close_ui"):
			hub_ui.close_ui()
			active_ui = ""
