extends Node

const IP_ADDRESS: String = "localhost"
const PORT: int = 42069

var peer = NodeTunnelPeer.new()

# Enemy spawning variables
var enemy_spawn_timer: Timer = null
var max_enemies: int = 10
var current_enemy_count: int = 0
var spawn_interval_min: float = 3.0
var spawn_interval_max: float = 6.0
var enemy_id_counter: int = 0  # Counter for unique enemy IDs

# Wave system variables
var current_wave: int = 1
var enemies_in_wave: int = 5
var enemies_spawned_this_wave: int = 0
var enemies_killed_this_wave: int = 0
var wave_in_progress: bool = false
var wave_start_timer: Timer = null
var max_waves: int = 3
var total_enemies_killed: int = 0  # Track total across all waves

# Boss system variables
var boss_min_health: int = 200
var boss_max_health: int = 500
var boss_spawned_this_wave: bool = false
var boss_names: Array[String] = [
	"Gargantua", "Titan", "Colossus", "Behemoth", "Leviathan",
	"Juggernaut", "Goliath", "Destroyer", "Ravager", "Annihilator",
	"Dreadnought", "Obliterator", "Executioner", "Warlord", "Overlord",
	"Havoc", "Reaper", "Crusher", "Demolisher", "Decimator"
]

# Enemy spawn points
var enemy_spawn_points: Array[Vector2] = []
var next_enemy_spawn_index: int = 0


func _ready() -> void:
	multiplayer.multiplayer_peer = peer
	randomize()
	print("Connecting to relay...")
	# Start relay connection in background without blocking
	connect_to_relay_async()


func connect_to_relay_async() -> void:
	peer.connect_to_relay("relay.nodetunnel.io", 9998)

	print("Waiting for relay connection...")
	await peer.relay_connected
	print("Relay connected in _ready(), online ID: ", peer.online_id)

	# Update OnlineID label if it exists (UI element may not be present in all scenes)
	var online_id_label = get_node_or_null("%OnlineID")
	if online_id_label:
		online_id_label.text = peer.online_id


# Chat system signals
signal chat_message_received(player_name: String, message: String)


func start_server(go_to_lobby: bool = true) -> void:
	# Ensure relay connection is established before hosting
	print("Starting server, checking relay connection...")
	print("Current connection status: ", peer.connection_status)
	print("Relay state: ", peer.connection_state)

	# Only wait for relay if not already connected (connection_state 2 = CONNECTED)
	if peer.connection_state != 2:
		print("Waiting for relay connection...")
		# Wait for either relay connection or a 5 second timeout
		await get_tree().create_timer(5.0).timeout or peer.relay_connected
		print("Relay connection check complete, state: ", peer.connection_state)
		# Check if still connecting after timeout
		if peer.connection_state == 1:
			print("WARNING: Relay still connecting after timeout")
	else:
		print("Relay already connected, proceeding to host...")

	print("Starting host() call...")
	peer.host()
	print("Waiting for hosting signal...")
	await peer.hosting
	print("Hosting successful, online ID: ", peer.online_id)

	DisplayServer.clipboard_set(peer.online_id)

	# Connect to peer_connected signal to sync existing enemies to new clients
	multiplayer.peer_connected.connect(_on_peer_connected_sync)
	# Connect to peer_disconnected signal to remove disconnected players
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# If go_to_lobby is true, enter lobby instead of starting game immediately
	if go_to_lobby:
		# Store online ID and transition to lobby
		print("NetworkHandler: Calling LobbyManager.enter_lobby with online_id: ", peer.online_id)
		LobbyManager.enter_lobby(peer.online_id)
		print("NetworkHandler: LobbyManager.players after enter_lobby: ", LobbyManager.players)
		print("NetworkHandler: Changing scene to lobby.tscn")
		get_tree().change_scene_to_file("res://coop/scenes/lobby.tscn")
	else:
		# Old behavior: spawn player and start game immediately
		await get_tree().create_timer(0.1).timeout
		spawn_server_player()

		# Find enemy spawn points
		find_enemy_spawn_points()

		# Start wave system after server player spawns
		await get_tree().create_timer(0.5).timeout
		start_wave_system()


func _on_peer_connected_sync(peer_id: int) -> void:
	# When a new peer connects, send them all existing enemies
	print("New peer ", peer_id, " connected, syncing existing enemies")

	# Wait a moment for the peer to be fully ready
	await get_tree().create_timer(0.5).timeout

	# Get all existing enemies and spawn them on the new client
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.is_inside_tree():
			# Use global_position and spawn on the new peer with the enemy's current name
			rpc_id(peer_id, "spawn_enemy_rpc", enemy.global_position, enemy.name)
			print(
				"Syncing enemy at global_position ",
				enemy.global_position,
				" with name ",
				enemy.name,
				" to peer ",
				peer_id
			)
			# Send an immediate position update to ensure it's set correctly
			await get_tree().process_frame
			rpc_id(peer_id, "update_enemy_position", enemy.name, enemy.global_position)

	await get_tree().create_timer(0.1).timeout
	print("Finished syncing ", enemies.size(), " enemies to peer ", peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	# When a peer disconnects, remove their player from the game
	print("Peer ", peer_id, " disconnected, removing their player")

	# Unregister player from GameDirector
	GameDirector.unregister_player(peer_id)

	# Find and remove the player node with this peer ID
	var player_node_name = str(peer_id)
	var player = get_tree().current_scene.get_node_or_null(player_node_name)

	if player:
		print("Removing player node: ", player_node_name)
		player.queue_free()
	else:
		# Also search in the players group as backup
		var players = get_tree().get_nodes_in_group("players")
		for p in players:
			if p.name == player_node_name or p.name.to_int() == peer_id:
				print("Removing player node from group: ", p.name)
				p.queue_free()
				break

	# Update player count in GameDirector
	# Count remaining players in LobbyManager
	var remaining_player_count = LobbyManager.players.size() - 1
	if remaining_player_count >= 0:
		GameDirector.update_player_count(remaining_player_count)
		print("GameDirector: Updated player count to ", remaining_player_count)


func spawn_server_player() -> void:
	# Get the player scene directly (same as what the spawner would use)
	var player_scene = preload("res://coop/scenes/Characters/player.tscn")
	var player = player_scene.instantiate()

	# Set the player name to the server peer ID
	var server_peer_id = multiplayer.get_unique_id()
	player.name = str(server_peer_id)

	# Set spawn position using the same system as multiplayer spawner
	player.position = get_spawn_position()

	# Add the player to the scene tree
	get_tree().current_scene.add_child(player)

	print("Server player spawned with peer ID: ", server_peer_id)
	print("Player position: ", player.position)


func get_spawn_position() -> Vector2:
	# Find spawn points the same way as the multiplayer spawner
	var spawn_points_node = get_tree().current_scene.get_node("SpawnPoints")
	if spawn_points_node:
		var spawn_points = []
		for child in spawn_points_node.get_children():
			if child is Marker2D:
				spawn_points.append(child)

		if not spawn_points.is_empty():
			# Use the first spawn point for the server player
			return spawn_points[0].position

	print("No spawn points found, using origin")
	return Vector2.ZERO


func find_enemy_spawn_points() -> void:
	# Find enemy spawn points in the scene
	# First try to find a dedicated EnemySpawnPoints node
	var enemy_spawn_node = get_tree().current_scene.get_node_or_null("EnemySpawnPoints")

	if enemy_spawn_node:
		for child in enemy_spawn_node.get_children():
			if child is Marker2D:
				enemy_spawn_points.append(child.global_position)
		print("Found ", enemy_spawn_points.size(), " enemy spawn points")
	else:
		print("No EnemySpawnPoints node found, using default positions")
		# Create some default spawn positions around the map
		enemy_spawn_points = [
			Vector2(800, 200),
			Vector2(-800, 200),
			Vector2(800, -200),
			Vector2(-800, -200),
			Vector2(0, 600),
			Vector2(0, -600),
			Vector2(1200, 0),
			Vector2(-1200, 0)
		]
		print("Using ", enemy_spawn_points.size(), " default enemy spawn points")


func get_next_enemy_spawn_position() -> Vector2:
	if enemy_spawn_points.is_empty():
		print("No enemy spawn points available, using origin")
		return Vector2.ZERO

	var spawn_pos = enemy_spawn_points[next_enemy_spawn_index]
	next_enemy_spawn_index = (next_enemy_spawn_index + 1) % enemy_spawn_points.size()
	return spawn_pos


func start_wave_system() -> void:
	# Only start waves on server
	if not multiplayer.is_server():
		return

	wave_in_progress = true
	enemies_spawned_this_wave = 0
	enemies_killed_this_wave = 0
	boss_spawned_this_wave = false  # Reset boss flag for new wave

	# Initialize GameDirector with current wave
	GameDirector.start_wave(current_wave)

	# Track wave in GameStats
	if GameStats:
		GameStats.record_wave_reached(current_wave)

	# Update wave display on all clients
	rpc("update_wave_display", current_wave)

	# Start spawning enemies for this wave
	spawn_wave_enemies()


func spawn_wave_enemies() -> void:
	# Get enemy count from GameDirector (handles player scaling)
	enemies_in_wave = GameDirector.enemies_to_spawn_this_wave

	# Determine random position for boss spawn (between 20-80% of wave progression)
	var boss_spawn_at = randi_range(int(enemies_in_wave * 0.2), int(enemies_in_wave * 0.8))

	# Bosses only spawn after wave 3
	var should_spawn_boss = current_wave > 3

	# Spawn enemies for the current wave
	for i in range(enemies_in_wave):
		# Check if GameDirector allows more spawns
		if not GameDirector.should_spawn_enemy():
			break

		# Spawn boss at the random position (only if wave > 3)
		if i == boss_spawn_at and not boss_spawned_this_wave and should_spawn_boss:
			spawn_boss()
			boss_spawned_this_wave = true
		else:
			spawn_single_enemy()

		enemies_spawned_this_wave += 1

		# Use dynamic spawn delay from GameDirector
		var spawn_delay = GameDirector.get_spawn_delay()
		await get_tree().create_timer(spawn_delay).timeout


func check_wave_completion() -> void:
	# Check if all enemies in the current wave are dead
	var current_enemies = get_tree().get_nodes_in_group("enemies").size()

	if current_enemies == 0 and enemies_spawned_this_wave > 0:
		# Wave completed
		wave_in_progress = false

		# Notify GameDirector of wave completion
		GameDirector.on_wave_complete()

		# Show wave completion message
		rpc("show_wave_completion", current_wave)

		# Start countdown to next wave (waves are unlimited)
		start_wave_countdown()


func start_next_wave() -> void:
	current_wave += 1

	# Track wave progression in GameStats
	if GameStats:
		GameStats.record_wave_reached(current_wave)

	# Enemy count is now managed by GameDirector
	# GameDirector handles scaling based on wave number and player count

	start_wave_system()


func start_wave_countdown() -> void:
	# Show countdown from 5 to 1
	for i in range(5, 0, -1):
		rpc("show_countdown", i)
		await get_tree().create_timer(1.0).timeout

	# Show wave start message
	rpc("show_wave_start", current_wave + 1)

	# Start next wave
	start_next_wave()


@rpc("any_peer", "reliable", "call_local")
func show_wave_completion(wave_number: int) -> void:
	pass  # TODO: Add UI display for wave completion


@rpc("any_peer", "reliable", "call_local")
func show_countdown(seconds: int) -> void:
	pass  # TODO: Add UI display for countdown


@rpc("any_peer", "reliable", "call_local")
func show_wave_start(wave_number: int) -> void:
	pass  # TODO: Add UI display for wave start


@rpc("any_peer", "reliable", "call_local")
func update_wave_display(wave_number: int) -> void:
	# Update wave display on all players
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		# Only update the local player's wave display
		if player.name.to_int() == multiplayer.get_unique_id():
			var wave_display = player.get_node_or_null("WaveDisplay")
			if wave_display and wave_display.has_method("update_wave"):
				wave_display.update_wave(wave_number)
			break




func on_enemy_died(is_boss: bool = false) -> void:
	# Called when an enemy dies to check wave completion
	if not multiplayer.is_server():
		return

	enemies_killed_this_wave += 1
	total_enemies_killed += 1
	
	# Track in GameStats
	if GameStats:
		GameStats.record_enemy_kill(is_boss)

	# Wait a frame for the enemy to be removed from the scene tree
	await get_tree().process_frame

	# Check if wave is complete
	check_wave_completion()




func get_random_enemy_size() -> int:
	# Delegate to GameDirector for enemy size calculation
	# GameDirector handles wave-based distribution and special events
	return GameDirector.get_next_enemy_size()


func spawn_single_enemy() -> void:
	# Use predetermined spawn position from enemy spawn points
	var spawn_position = get_next_enemy_spawn_position()

	# Get enemy size from GameDirector (handles special events and wave scaling)
	var enemy_size = get_random_enemy_size()

	# Use RPC to spawn enemy on all clients with unique ID
	enemy_id_counter += 1
	var enemy_id = "Enemy_" + str(enemy_id_counter)
	rpc("spawn_enemy_rpc", spawn_position, enemy_id, enemy_size)

	# Notify GameDirector that an enemy was spawned
	GameDirector.on_enemy_spawned()


func spawn_boss() -> void:
	# Spawn a unique boss enemy with random name and health
	var spawn_position = get_next_enemy_spawn_position()

	# Bosses are always HUGE size for visual impact
	var boss_size = 3  # EnemySize.HUGE

	# Generate random boss health within configured range
	var boss_health = randi_range(boss_min_health, boss_max_health)

	# Pick a random boss name
	var boss_name = boss_names[randi() % boss_names.size()]

	# Generate unique boss ID
	enemy_id_counter += 1
	var boss_id = "Boss_" + str(enemy_id_counter)

	# Use RPC to spawn boss on all clients
	rpc("spawn_boss_rpc", spawn_position, boss_id, boss_size, boss_health, boss_name)

	# Notify GameDirector that an enemy was spawned
	GameDirector.on_enemy_spawned()


@rpc("any_peer", "reliable", "call_local")
func spawn_enemy_rpc(spawn_position: Vector2, enemy_id: String, enemy_size: int) -> void:
	var enemy_scene = preload("res://coop/scenes/enemy.tscn")
	var enemy = enemy_scene.instantiate()

	enemy.global_position = spawn_position
	enemy.name = enemy_id  # Give consistent name across all clients
	
	# Set enemy size before adding to scene
	enemy.set_enemy_size(enemy_size)
	
	# Progressive stat scaling: enemies get slightly stronger each wave
	# +5% health and +2% damage per wave (capped at reasonable amounts)
	if current_wave > 1:
		var health_multiplier = 1.0 + ((current_wave - 1) * 0.05)  # +5% per wave
		var damage_multiplier = 1.0 + ((current_wave - 1) * 0.02)  # +2% per wave
		
		# Cap multipliers to prevent extreme scaling
		health_multiplier = min(health_multiplier, 3.0)  # Max 3x health
		damage_multiplier = min(damage_multiplier, 2.0)  # Max 2x damage
		
		# Apply wave scaling to enemy stats
		if enemy.has_method("apply_wave_scaling"):
			enemy.apply_wave_scaling(health_multiplier, damage_multiplier)

	# Add enemy to scene
	get_tree().current_scene.add_child(enemy)

	current_enemy_count += 1


@rpc("any_peer", "reliable", "call_local")
func spawn_boss_rpc(spawn_position: Vector2, boss_id: String, boss_size: int, boss_health: int, boss_name: String) -> void:
	var enemy_scene = preload("res://coop/scenes/enemy.tscn")
	var boss = enemy_scene.instantiate()

	boss.global_position = spawn_position
	boss.name = boss_id  # Give consistent name across all clients
	
	# Set boss size
	boss.set_enemy_size(boss_size)
	
	# Add boss to scene first (so _ready() is called)
	get_tree().current_scene.add_child(boss)
	
	# Convert this enemy into a boss with custom name and health
	if boss.has_method("make_boss"):
		boss.make_boss(boss_name, boss_health)

	current_enemy_count += 1


# Client will join existing game
func start_client(host_id: String = "", go_to_lobby: bool = true) -> void:
	# Validate host ID
	if not host_id or host_id.is_empty():
		print("No host ID provided")
		return

	# Ensure relay connection is established before joining
	print("Starting client, checking relay connection...")
	print("Current connection status: ", peer.connection_status)
	print("Relay state: ", peer.connection_state)

	# Only wait for relay if not already connected (connection_state 2 = CONNECTED)
	if peer.connection_state != 2:
		print("Waiting for relay connection...")
		await peer.relay_connected
		print("Relay connected, attempting to join host: ", host_id)
	else:
		print("Relay already connected, proceeding to join...")

	print("Starting join() call with host ID: ", host_id)
	peer.join(host_id)
	print("Waiting for joined signal...")
	await peer.joined

	print("Client successfully connected to ", host_id)

	# If go_to_lobby is true, enter lobby
	if go_to_lobby:
		print("NetworkHandler: Calling LobbyManager.enter_lobby with host_id: ", host_id)
		LobbyManager.enter_lobby(host_id)
		print("NetworkHandler: LobbyManager.players after enter_lobby: ", LobbyManager.players)
		print("NetworkHandler: Changing scene to lobby.tscn")
		get_tree().change_scene_to_file("res://coop/scenes/lobby.tscn")


# Chat system functions
func send_chat_message(message: String) -> void:
	var peer_id = str(multiplayer.get_unique_id())
	print("NetworkHandler: Sending chat message: ", message, " from peer ", peer_id)
	if multiplayer.multiplayer_peer == null:
		print("ERROR: No multiplayer peer!")
		return

	if multiplayer.is_server():
		print("NetworkHandler: Host broadcasting chat message locally and to clients")
		receive_chat_message(peer_id, message)
		rpc("receive_chat_message", peer_id, message)
	else:
		print("NetworkHandler: Forwarding chat message to server for broadcast")
		_send_chat_message_to_server.rpc_id(1, message)


@rpc("any_peer", "reliable")
func _send_chat_message_to_server(message: String) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	var peer_id := str(sender_id if sender_id != 0 else multiplayer.get_unique_id())
	print("NetworkHandler: Server received chat submission from peer ", peer_id)
	receive_chat_message(peer_id, message)
	rpc("receive_chat_message", peer_id, message)


@rpc("any_peer", "reliable")
func receive_chat_message(player_name: String, message: String) -> void:
	print("NetworkHandler: Received chat message from ", player_name, ": ", message)
	# Emit signal to update UI
	chat_message_received.emit(player_name, message)
	print("NetworkHandler: Signal emitted")


# Enemy synchronization functions
func sync_enemy_position(enemy_name: String, position: Vector2) -> void:
	# Only server sends position updates
	if not multiplayer.is_server():
		return

	# Broadcast position to all clients
	rpc("update_enemy_position", enemy_name, position)


@rpc("any_peer", "unreliable", "call_local")
func update_enemy_position(enemy_name: String, position: Vector2) -> void:
	# Find enemy by name and update position (only on clients)
	# Server already has correct position
	if multiplayer.is_server():
		return

	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.name == enemy_name:
			enemy.global_position = position
			# Debug output
			if Engine.get_process_frames() % 60 == 0:  # Every second
				print("Updated enemy ", enemy_name, " position to ", position, " on client")
			return

	# If we get here, enemy wasn't found
	if Engine.get_process_frames() % 60 == 0:
		print(
			"WARNING: Enemy ",
			enemy_name,
			" not found for position update on client. Total enemies: ",
			get_tree().get_nodes_in_group("enemies").size()
		)


# Called when game starts from lobby
func start_game_from_lobby() -> void:
	print("Starting game from lobby...")

	# Spawn players with their selected classes
	spawn_players_with_classes()

	# Find enemy spawn points
	find_enemy_spawn_points()

	# Start wave system after players spawn (server only)
	if multiplayer.is_server():
		await get_tree().create_timer(0.5).timeout
		start_wave_system()


func spawn_players_with_classes() -> void:
	# Only the server should instantiate player scenes.
	if not multiplayer.is_server():
		return

	# Spawn all players from the lobby with their selected classes
	var player_scene = preload("res://coop/scenes/Characters/player.tscn")
	var spawn_index = 0
	var current_scene := get_tree().current_scene
	if current_scene == null:
		print("ERROR: No current scene available for spawning players")
		return

	var player_count = 0
	for peer_id in LobbyManager.players:
		# Avoid spawning duplicates if this function is called more than once.
		if current_scene.get_node_or_null(str(peer_id)):
			continue

		var player = player_scene.instantiate()
		player.name = str(peer_id)

		# Set spawn position
		player.position = get_spawn_position_at_index(spawn_index)
		spawn_index += 1

		# Store the player's selected class so player.gd can read it
		player.set_meta("selected_class", LobbyManager.players[peer_id]["class"])

		# Store the player's selected weapon so player.gd can read it
		player.set_meta("selected_weapon", LobbyManager.players[peer_id]["weapon"])

		# Add player to scene
		current_scene.add_child(player)

		# Register player with GameDirector for performance tracking
		GameDirector.register_player(peer_id)
		player_count += 1

		print("Spawned player ", peer_id, " with class ", LobbyManager.players[peer_id]["class"], " and weapon ", LobbyManager.players[peer_id]["weapon"])

	# Update GameDirector with total player count
	GameDirector.update_player_count(player_count)
	print("GameDirector: Updated player count to ", player_count)


func get_spawn_position_at_index(index: int) -> Vector2:
	# Get spawn position from spawn points
	var spawn_points_node = get_tree().current_scene.get_node_or_null("SpawnPoints")
	if spawn_points_node:
		var spawn_points = []
		for child in spawn_points_node.get_children():
			if child is Marker2D:
				spawn_points.append(child)

		if not spawn_points.is_empty():
			# Cycle through spawn points
			var spawn_point = spawn_points[index % spawn_points.size()]
			return spawn_point.position

	print("No spawn points found, using origin")
	return Vector2.ZERO
