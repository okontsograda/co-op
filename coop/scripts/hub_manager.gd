extends Node

## HubManager - Manages the central hub scene state and player coordination
## Autoload singleton that handles hub-specific logic, player spawning, and mission transitions

signal player_ready_changed(peer_id: int, is_ready: bool)
signal all_players_ready()
signal mission_starting()
signal player_list_changed()

## Dictionary tracking hub players: {peer_id: {is_ready: bool, position: Vector2}}
var hub_players: Dictionary = {}

## Current mission selected (for future mission selection system)
var selected_mission: String = "example"

## Track if hub is multiplayer or solo
var is_multiplayer: bool = false

## Players ready count
var ready_count: int = 0


func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


## Initialize hub for a new session
func initialize_hub(multiplayer_mode: bool = false):
	hub_players.clear()
	ready_count = 0
	is_multiplayer = multiplayer_mode
	selected_mission = "example"
	print("[HubManager] Hub initialized (Multiplayer: %s)" % multiplayer_mode)


## Ensure we have entries for all connected peers (host + clients)
func sync_connected_players(local_peer_id: int):
	# Always track the local peer
	register_player(local_peer_id)

	if not is_multiplayer:
		return

	# Register already-connected peers (e.g., when joining an existing session)
	for peer_id in multiplayer.get_peers():
		register_player(peer_id)


## Register a player in the hub
func register_player(peer_id: int):
	if peer_id not in hub_players:
		hub_players[peer_id] = {
			"is_ready": false,
			"position": Vector2.ZERO
		}
		print("[HubManager] Player %d registered in hub" % peer_id)
		player_list_changed.emit()


## Unregister a player from the hub
func unregister_player(peer_id: int):
	if peer_id in hub_players:
		if hub_players[peer_id]["is_ready"]:
			ready_count -= 1
		hub_players.erase(peer_id)
		print("[HubManager] Player %d unregistered from hub" % peer_id)
		player_list_changed.emit()


## Toggle player ready status (host authoritative)
func set_player_ready(peer_id: int, is_ready: bool):
	# Clients ask host to apply; host applies and broadcasts
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_request_set_ready.rpc_id(1, is_ready)
		return

	_apply_ready_state(peer_id, is_ready)

	# Host broadcasts to all clients
	if multiplayer.has_multiplayer_peer():
		_broadcast_ready_state.rpc(peer_id, is_ready)


@rpc("any_peer", "reliable")
func _request_set_ready(is_ready: bool):
	if not multiplayer.is_server():
		return
	var sender_peer := multiplayer.get_remote_sender_id()
	_apply_ready_state(sender_peer, is_ready)
	_broadcast_ready_state.rpc(sender_peer, is_ready)


@rpc("any_peer", "reliable")
func _broadcast_ready_state(peer_id: int, is_ready: bool):
	_apply_ready_state(peer_id, is_ready)


## Check if all players are ready
func are_all_players_ready() -> bool:
	if hub_players.is_empty():
		return false
	return ready_count == hub_players.size()


func _apply_ready_state(peer_id: int, is_ready: bool):
	if peer_id not in hub_players:
		register_player(peer_id)

	var was_ready = hub_players[peer_id]["is_ready"]
	hub_players[peer_id]["is_ready"] = is_ready

	if was_ready == is_ready:
		return

	if is_ready:
		ready_count += 1
	else:
		ready_count -= 1

	player_ready_changed.emit(peer_id, is_ready)
	print("[HubManager] Player %d ready status: %s (%d/%d)" % [peer_id, is_ready, ready_count, hub_players.size()])

	# Check if all players are ready
	if ready_count == hub_players.size() and hub_players.size() > 0:
		all_players_ready.emit()


## Start the mission (host only)
func start_mission():
	if not multiplayer.is_server():
		print("[HubManager] Only host can start mission")
		return

	if not are_all_players_ready():
		print("[HubManager] Not all players are ready")
		return

	print("[HubManager] Starting mission: %s" % selected_mission)
	mission_starting.emit()
	var mission_scene_path = _get_mission_scene_path(selected_mission)
	NetworkHandler.transition_to_scene(mission_scene_path, NetworkHandler.SceneType.MISSION, {"mission_id": selected_mission})


## Return to hub after mission (with rewards)
func return_to_hub(meta_coins_earned: int = 0):
	print("[HubManager] Returning to hub (Earned %d meta coins)" % meta_coins_earned)

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		print("[HubManager] Only host can trigger hub return")
		return

	# Award meta currency
	if meta_coins_earned > 0:
		SaveSystem.add_meta_currency(meta_coins_earned)

	# Clear mission state
	GameDirector.reset_game()

	NetworkHandler.transition_to_scene(NetworkHandler.HUB_SCENE_PATH, NetworkHandler.SceneType.HUB, {"from_mission": true})


func _on_peer_connected(id: int):
	if is_multiplayer:
		print("[HubManager] Peer %d connected to hub" % id)
		register_player(id)


func _on_peer_disconnected(id: int):
	if is_multiplayer:
		print("[HubManager] Peer %d disconnected from hub" % id)
		unregister_player(id)


## Get ready player count as string (for UI)
func get_ready_status_text() -> String:
	var total := hub_players.size()
	if total == 0 and multiplayer.is_server():
		total = 1  # include host when alone
	return "%d / %d Ready" % [ready_count, total]


func _get_mission_scene_path(mission_id: String) -> String:
	match mission_id:
		"example":
			return "res://coop/scenes/example.tscn"
		_:
			return "res://coop/scenes/example.tscn"
