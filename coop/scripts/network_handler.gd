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
var boss_spawned: bool = false

func _ready() -> void:
	multiplayer.multiplayer_peer = peer
	print("Connecting to relay...")
	# Start relay connection in background without blocking
	connect_to_relay_async()

func connect_to_relay_async() -> void:
	peer.connect_to_relay("relay.nodetunnel.io", 9998)
	
	print("Waiting for relay connection...")
	await peer.relay_connected
	print("Relay connected in _ready(), online ID: ", peer.online_id)
	
	if %OnlineID:
		%OnlineID.text = peer.online_id	

# Chat system signals
signal chat_message_received(player_name: String, message: String)

func start_server() -> void:
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
	
	# Spawn the server player after the server is fully established
	await get_tree().create_timer(0.1).timeout
	spawn_server_player()
	
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
			print("Syncing enemy at global_position ", enemy.global_position, " with name ", enemy.name, " to peer ", peer_id)
			# Send an immediate position update to ensure it's set correctly
			await get_tree().process_frame
			rpc_id(peer_id, "update_enemy_position", enemy.name, enemy.global_position)
	
	await get_tree().create_timer(0.1).timeout
	print("Finished syncing ", enemies.size(), " enemies to peer ", peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	# When a peer disconnects, remove their player from the game
	print("Peer ", peer_id, " disconnected, removing their player")
	
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

func spawn_server_player() -> void:
	# Get the player scene directly (same as what the spawner would use)
	var player_scene = preload("res://coop/scenes/player.tscn")
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

func start_wave_system() -> void:
	# Only start waves on server
	if not multiplayer.is_server():
		return
	
	print("Starting wave system - Wave ", current_wave, " with ", enemies_in_wave, " enemies")
	wave_in_progress = true
	enemies_spawned_this_wave = 0
	enemies_killed_this_wave = 0
	
	# Start spawning enemies for this wave
	spawn_wave_enemies()

func spawn_wave_enemies() -> void:
	# Spawn enemies for the current wave
	for i in range(enemies_in_wave):
		spawn_single_enemy()
		enemies_spawned_this_wave += 1
		await get_tree().create_timer(0.5).timeout  # Small delay between spawns
	
	print("Wave ", current_wave, " spawning complete. ", enemies_spawned_this_wave, " enemies spawned")

func check_wave_completion() -> void:
	# Check if all enemies in the current wave are dead
	var current_enemies = get_tree().get_nodes_in_group("enemies").size()
	print("Current enemies: ", current_enemies, ", enemies_spawned_this_wave: ", enemies_spawned_this_wave)
	
	if current_enemies == 0 and enemies_spawned_this_wave > 0:
		# Wave completed
		print("Wave ", current_wave, " completed!")
		wave_in_progress = false
		
		# Show wave completion message
		rpc("show_wave_completion", current_wave)
		
		# Check if this was the last wave
		if current_wave >= max_waves:
			# All waves complete, spawn boss
			print("All waves complete! Spawning boss...")
			rpc("show_boss_announcement")
			await get_tree().create_timer(3.0).timeout
			spawn_boss()
		else:
			# Start countdown to next wave
			start_wave_countdown()
	else:
		print("Wave not complete yet")

func start_next_wave() -> void:
	current_wave += 1
	enemies_in_wave += 3  # Increase enemy count by 3 each wave
	print("Starting Wave ", current_wave, " with ", enemies_in_wave, " enemies")
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
	print("=== WAVE ", wave_number, " COMPLETED! ===")
	# TODO: Add UI display for wave completion

@rpc("any_peer", "reliable", "call_local")
func show_countdown(seconds: int) -> void:
	print("=== NEXT WAVE IN ", seconds, " SECONDS ===")
	# TODO: Add UI display for countdown

@rpc("any_peer", "reliable", "call_local")
func show_wave_start(wave_number: int) -> void:
	print("=== WAVE ", wave_number, " STARTING! ===")
	# TODO: Add UI display for wave start

@rpc("any_peer", "reliable", "call_local")
func show_boss_announcement() -> void:
	print("=== BOSS APPROACHING! ===")
	# TODO: Add UI display for boss announcement

func spawn_boss() -> void:
	# Only spawn boss on server
	if not multiplayer.is_server():
		return
	
	if boss_spawned:
		return
	
	boss_spawned = true
	
	# Get players to spawn boss away from them
	var players = get_tree().get_nodes_in_group("players")
	var spawn_position = Vector2.ZERO
	
	if not players.is_empty():
		# Spawn boss at a distance from players
		var base_player = players[0]
		var angle = randf() * TAU
		var distance = randf_range(200, 400)  # Further away than regular enemies
		spawn_position = base_player.global_position + Vector2(cos(angle), sin(angle)) * distance
		
		# Clamp spawn position to visible area
		spawn_position.x = clamp(spawn_position.x, -1800, 1800)
		spawn_position.y = clamp(spawn_position.y, -1600, 1600)
	else:
		# No players, use random position
		spawn_position = Vector2(randf_range(-1800, 1800), randf_range(-1600, 1600))
	
	# Spawn boss with unique ID
	enemy_id_counter += 1
	var boss_id = "Boss_" + str(enemy_id_counter)
	rpc("spawn_boss_rpc", spawn_position, boss_id)
	print("Boss spawned at position: ", spawn_position)

@rpc("any_peer", "reliable", "call_local")
func spawn_boss_rpc(spawn_position: Vector2, boss_id: String) -> void:
	var boss_scene = preload("res://coop/scenes/boss.tscn")
	var boss = boss_scene.instantiate()
	
	boss.global_position = spawn_position
	boss.name = boss_id
	
	# Add boss to scene
	get_tree().current_scene.add_child(boss)
	
	print("Boss spawned at global_position: ", spawn_position, " with name ", boss_id)

func on_enemy_died() -> void:
	# Called when an enemy dies to check wave completion
	if not multiplayer.is_server():
		return
	
	enemies_killed_this_wave += 1
	print("Enemy killed. Wave progress: ", enemies_killed_this_wave, "/", enemies_spawned_this_wave)
	
	# Wait a frame for the enemy to be removed from the scene tree
	await get_tree().process_frame
	
	# Check if wave is complete
	print("Checking wave completion...")
	check_wave_completion()

func on_boss_died() -> void:
	# Called when the boss dies
	if not multiplayer.is_server():
		return
	
	print("Boss defeated! Game complete!")
	rpc("show_game_complete")

@rpc("any_peer", "reliable", "call_local")
func show_game_complete() -> void:
	print("=== GAME COMPLETE! BOSS DEFEATED! ===")
	# TODO: Add UI display for game completion

func spawn_single_enemy() -> void:
	# Get players to spawn away from them
	var players = get_tree().get_nodes_in_group("players")
	var spawn_position = Vector2.ZERO
	
	if not players.is_empty():
		# Spawn at a random distance from players (150-300 pixels away, within camera view)
		var base_player = players[0]
		var angle = randf() * TAU  # Random angle in radians
		var distance = randf_range(150, 300)
		spawn_position = base_player.global_position + Vector2(cos(angle), sin(angle)) * distance
		
		# Clamp spawn position to visible area (camera limits)
		spawn_position.x = clamp(spawn_position.x, -1800, 1800)
		spawn_position.y = clamp(spawn_position.y, -1600, 1600)
	else:
		# No players, use random position within visible bounds
		spawn_position = Vector2(randf_range(-1800, 1800), randf_range(-1600, 1600))
	
	# Use RPC to spawn enemy on all clients with unique ID
	enemy_id_counter += 1
	var enemy_id = "Enemy_" + str(enemy_id_counter)
	rpc("spawn_enemy_rpc", spawn_position, enemy_id)

@rpc("any_peer", "reliable", "call_local")
func spawn_enemy_rpc(spawn_position: Vector2, enemy_id: String) -> void:
	var enemy_scene = preload("res://coop/scenes/enemy.tscn")
	var enemy = enemy_scene.instantiate()
	
	enemy.global_position = spawn_position
	enemy.name = enemy_id  # Give consistent name across all clients
	
	# Add enemy to scene
	get_tree().current_scene.add_child(enemy)
	
	current_enemy_count += 1
	print("Enemy spawned at global_position: ", enemy.global_position, " with name ", enemy.name, " (total enemies: ", current_enemy_count, ") on ", "server" if multiplayer.is_server() else "client")

# Client will join existing game
func start_client(host_id: String = "") -> void:
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
	
# Chat system functions
func send_chat_message(message: String) -> void:
	var peer_id = str(multiplayer.get_unique_id())
	print("NetworkHandler: Sending chat message: ", message, " from peer ", peer_id)
	if multiplayer.multiplayer_peer == null:
		print("ERROR: No multiplayer peer!")
		return
	
	# Send to all peers including self
	rpc("receive_chat_message", peer_id, message)
	print("NetworkHandler: RPC sent with peer_id: ", peer_id)

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
		print("WARNING: Enemy ", enemy_name, " not found for position update on client. Total enemies: ", get_tree().get_nodes_in_group("enemies").size())
