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
	
	# Spawn the server player after the server is fully established
	await get_tree().create_timer(0.1).timeout
	spawn_server_player()
	
	# Spawn enemies after server player spawns
	await get_tree().create_timer(0.5).timeout
	spawn_enemies()

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

func spawn_enemies() -> void:
	# Only spawn enemies on server
	if not multiplayer.is_server():
		return
	
	# Initial spawn of 3 enemies
	for i in range(3):
		spawn_single_enemy()
		await get_tree().create_timer(0.3).timeout
	
	# Set up continuous spawning
	setup_continuous_spawning()

func setup_continuous_spawning() -> void:
	# Create a timer for continuous enemy spawning
	enemy_spawn_timer = Timer.new()
	enemy_spawn_timer.wait_time = randf_range(spawn_interval_min, spawn_interval_max)
	enemy_spawn_timer.timeout.connect(func(): _on_enemy_spawn_timer_timeout())
	enemy_spawn_timer.one_shot = false
	enemy_spawn_timer.autostart = true
	add_child(enemy_spawn_timer)
	
	print("Continuous enemy spawning enabled. Interval: ", enemy_spawn_timer.wait_time, " seconds")

func _on_enemy_spawn_timer_timeout() -> void:
	if not multiplayer.is_server():
		return
	
	# Get current enemy count
	current_enemy_count = get_tree().get_nodes_in_group("enemies").size()
	
	# Only spawn if under max enemies
	if current_enemy_count < max_enemies:
		spawn_single_enemy()
	
	# Update timer for next spawn (random interval)
	enemy_spawn_timer.wait_time = randf_range(spawn_interval_min, spawn_interval_max)
	print("Next enemy will spawn in ", enemy_spawn_timer.wait_time, " seconds")

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
