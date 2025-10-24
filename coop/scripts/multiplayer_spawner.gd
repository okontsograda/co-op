extends MultiplayerSpawner

@export var network_player: PackedScene

func _ready() -> void:
	multiplayer.peer_connected.connect(spawn_player)
	spawned.connect(_on_player_spawned)
	
	# If we're the server, spawn our own player
	if multiplayer.is_server():
		call_deferred("_spawn_server_player")

func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected: ", peer_id)
	# The MultiplayerSpawner will handle spawning automatically

func _on_player_spawned(node: Node) -> void:
	print("Player spawned via MultiplayerSpawner: ", node.name)

func _spawn_server_player() -> void:
	print("Spawning server player")
	var player: Node = network_player.instantiate()
	player.name = "1"  # Server is always peer 1
	get_node(spawn_path).call_deferred("add_child", player)
	print("Server player spawned with name: ", player.name)

func spawn_player(peer_id: int) -> void:
	if !multiplayer.is_server(): return

	print("Spawning player for peer: ", peer_id)
	var player: Node = network_player.instantiate()
	player.name = str(peer_id)
	
	get_node(spawn_path).call_deferred("add_child", player)
	print("Player spawned for peer: ", peer_id, " with name: ", player.name)
