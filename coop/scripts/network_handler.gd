extends Node

const IP_ADDRESS: String = "localhost"
const PORT: int = 42069

var peer = NodeTunnelPeer.new()

func _ready() -> void:
	multiplayer.multiplayer_peer = peer
	peer.connect_to_relay("relay.nodetunnel.io", 9998)
	
	await peer.relay_connected
	
	if %OnlineID:
		%OnlineID.text = peer.online_id	

# Chat system signals
signal chat_message_received(player_name: String, message: String)

func start_server() -> void:
	peer.host()
	
	await peer.hosting
	
	DisplayServer.clipboard_set(peer.online_id)

	multiplayer.multiplayer_peer = peer
	
	# Spawn the server player after the server is fully established
	await get_tree().create_timer(0.1).timeout
	spawn_server_player()

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

# Client will join existing game
# Client will join existing game
func start_client(host_id: String = "") -> void:
	if host_id:
		peer.join(host_id)
	else:
		print("No host ID provided")
		return

	await peer.joined
	
	multiplayer.multiplayer_peer = peer

	print("Client connecting to ", host_id)
	
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
