extends Node

# Signals for lobby events
signal player_joined(peer_id: int, player_data: Dictionary)
signal player_left(peer_id: int)
signal player_ready_changed(peer_id: int, is_ready: bool)
signal player_class_changed(peer_id: int, selected_class: String)
signal player_weapon_changed(peer_id: int, selected_weapon: String)
signal player_name_changed(peer_id: int, player_name: String)
signal all_players_ready
signal game_starting

# Lobby state
var is_in_lobby: bool = false
var players: Dictionary = {}  # {peer_id: {class: "archer", ready: false, is_host: bool}}
var online_id: String = ""


func _ready():
	# Connect to multiplayer signals
	if multiplayer.has_multiplayer_peer():
		_setup_multiplayer_signals()


func _setup_multiplayer_signals():
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func enter_lobby(host_online_id: String = ""):
	print("=== ENTERING LOBBY ===")
	is_in_lobby = true
	online_id = host_online_id
	players.clear()
	print("Cleared players dict")

	# Register the local player
	var local_id = multiplayer.get_unique_id()
	print("Local peer ID: ", local_id)
	print("Is server: ", multiplayer.is_server())
	register_player(local_id, local_id == 1)
	print("After register_player, players dict: ", players)

	# If we're the server, set up multiplayer signals
	if multiplayer.is_server():
		_setup_multiplayer_signals()


func leave_lobby():
	is_in_lobby = false
	players.clear()


# Called when a new peer connects (server only)
func _on_peer_connected(peer_id: int):
	if is_in_lobby and multiplayer.is_server():
		if not players.has(peer_id):
			register_player(peer_id, false)
		# Send current lobby state to new player
		_send_lobby_state_to_peer.rpc_id(peer_id, players)


# Called when a peer disconnects
func _on_peer_disconnected(peer_id: int):
	if is_in_lobby and players.has(peer_id):
		players.erase(peer_id)
		player_left.emit(peer_id)


func register_player(peer_id: int, is_host: bool = false):
	print("register_player called: peer_id=", peer_id, " is_host=", is_host)
	if not players.has(peer_id):
		players[peer_id] = {
			"class": "archer", 
			"weapon": "bow", 
			"ready": false, 
			"is_host": is_host,
			"player_name": "Player " + str(peer_id)  # Default name
		}
		print("Added player ", peer_id, " to players dict: ", players[peer_id])
		print("Emitting player_joined signal for peer ", peer_id)
		player_joined.emit(peer_id, players[peer_id])

		# Broadcast to all clients if we're the server
		if multiplayer.is_server() and peer_id != multiplayer.get_unique_id():
			print("Broadcasting player joined to other clients")
			_broadcast_player_joined.rpc(peer_id, players[peer_id])
	else:
		print("Player ", peer_id, " already registered")


@rpc("any_peer", "reliable")
func _broadcast_player_joined(peer_id: int, player_data: Dictionary):
	if not players.has(peer_id):
		players[peer_id] = player_data
		player_joined.emit(peer_id, player_data)


@rpc("any_peer", "reliable")
func _send_lobby_state_to_peer(lobby_state: Dictionary):
	# Receive full lobby state from server
	for peer_id in lobby_state:
		if not players.has(peer_id):
			players[peer_id] = lobby_state[peer_id]
			player_joined.emit(peer_id, lobby_state[peer_id])


# Set player's selected class
func set_player_class(selected_class: String):
	var local_id = multiplayer.get_unique_id()
	if players.has(local_id):
		players[local_id]["class"] = selected_class
		player_class_changed.emit(local_id, selected_class)

		# Broadcast to all clients
		_broadcast_class_change.rpc(local_id, selected_class)


@rpc("any_peer", "reliable")
func _broadcast_class_change(peer_id: int, selected_class: String):
	if players.has(peer_id):
		players[peer_id]["class"] = selected_class
		player_class_changed.emit(peer_id, selected_class)


# Set player's selected weapon
func set_player_weapon(selected_weapon: String):
	var local_id = multiplayer.get_unique_id()
	if players.has(local_id):
		players[local_id]["weapon"] = selected_weapon
		player_weapon_changed.emit(local_id, selected_weapon)

		# Broadcast to all clients
		_broadcast_weapon_change.rpc(local_id, selected_weapon)


@rpc("any_peer", "reliable")
func _broadcast_weapon_change(peer_id: int, selected_weapon: String):
	if players.has(peer_id):
		players[peer_id]["weapon"] = selected_weapon
		player_weapon_changed.emit(peer_id, selected_weapon)


# Set player's name
func set_player_name(player_name: String):
	var local_id = multiplayer.get_unique_id()
	if players.has(local_id):
		players[local_id]["player_name"] = player_name
		player_name_changed.emit(local_id, player_name)
		print("[LobbyManager] Set local player name to: ", player_name)

		# Broadcast to all clients
		_broadcast_name_change.rpc(local_id, player_name)


@rpc("any_peer", "reliable")
func _broadcast_name_change(peer_id: int, player_name: String):
	if players.has(peer_id):
		players[peer_id]["player_name"] = player_name
		player_name_changed.emit(peer_id, player_name)
		print("[LobbyManager] Updated player ", peer_id, " name to: ", player_name)


# Get player's name
func get_player_name(peer_id: int) -> String:
	if players.has(peer_id):
		return players[peer_id]["player_name"]
	return "Player " + str(peer_id)


# Toggle ready status
func set_ready(is_ready: bool):
	var local_id = multiplayer.get_unique_id()
	print("LobbyManager.set_ready called: local_id=", local_id, " is_ready=", is_ready)
	if players.has(local_id):
		players[local_id]["ready"] = is_ready
		print("Updated player ", local_id, " ready state to ", is_ready)
		print("Emitting player_ready_changed signal")
		player_ready_changed.emit(local_id, is_ready)

		# Broadcast to all clients
		print("Broadcasting ready change via RPC")
		_broadcast_ready_change.rpc(local_id, is_ready)

		# Check if all players are ready (server only)
		if multiplayer.is_server():
			check_all_ready()
	else:
		print("ERROR: Player ", local_id, " not found in players dict!")


@rpc("any_peer", "reliable")
func _broadcast_ready_change(peer_id: int, is_ready: bool):
	if players.has(peer_id):
		players[peer_id]["ready"] = is_ready
		player_ready_changed.emit(peer_id, is_ready)


func check_all_ready() -> bool:
	if players.size() == 0:
		return false

	for peer_id in players:
		if not players[peer_id]["ready"]:
			return false

	all_players_ready.emit()
	return true


func are_all_players_ready() -> bool:
	if players.size() == 0:
		return false

	for peer_id in players:
		if not players[peer_id]["ready"]:
			return false
	return true


func is_local_player_host() -> bool:
	var local_id = multiplayer.get_unique_id()
	return players.has(local_id) and players[local_id]["is_host"]


func get_player_count() -> int:
	return players.size()


func get_player_class(peer_id: int) -> String:
	if players.has(peer_id):
		return players[peer_id]["class"]
	return "archer"


# Host kicks a player
func kick_player(peer_id: int):
	if is_local_player_host() and multiplayer.is_server():
		# Remove from lobby
		if players.has(peer_id):
			players.erase(peer_id)
			player_left.emit(peer_id)

		# Disconnect the peer
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)

		# Broadcast kick to all clients
		_broadcast_player_kicked.rpc(peer_id)


@rpc("any_peer", "reliable")
func _broadcast_player_kicked(peer_id: int):
	if players.has(peer_id):
		players.erase(peer_id)
		player_left.emit(peer_id)


# Start the game (host only)
func start_game():
	if is_local_player_host() and are_all_players_ready():
		game_starting.emit()
		_start_game_for_all.rpc()


@rpc("any_peer", "call_local", "reliable")
func _start_game_for_all():
	is_in_lobby = false
	# Change to village scene first
	get_tree().change_scene_to_file("res://coop/scenes/village.tscn")

	# Wait for scene to load, then spawn players in village
	await get_tree().create_timer(0.2).timeout
	NetworkHandler._fade_in_scene(1.2)

	# Spawn players in village (server only)
	if multiplayer.is_server():
		NetworkHandler.spawn_players_in_village()
