extends MultiplayerSpawner

@export var network_player: PackedScene

func _ready() -> void:
	multiplayer.peer_connected.connect(spawn_player)
	spawned.connect(_on_player_spawned)
	
	# Add to group so it can be found by the initial UI
	add_to_group("multiplayer_spawner")
	
	# Only spawn server player when we actually start hosting
	# This prevents spawning before the server is created

func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected: ", peer_id)
	# The MultiplayerSpawner will handle spawning automatically

func _on_player_spawned(node: Node) -> void:
	print("Player spawned via MultiplayerSpawner: ", node.name)
	print("Player position: ", node.position)
	print("Player visible: ", node.visible)

# Server player spawning is now handled by initial_ui.gd when hosting starts

func spawn_player(peer_id: int) -> void:
	if !multiplayer.is_server(): return

	print("Spawning player for peer: ", peer_id)
	var player: Node = network_player.instantiate()
	player.name = str(peer_id)
	
	get_node(spawn_path).call_deferred("add_child", player)
	print("Player spawned for peer: ", peer_id, " with name: ", player.name)
