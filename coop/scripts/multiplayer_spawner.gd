extends MultiplayerSpawner

@export var network_player: PackedScene

var spawn_points: Array[Marker2D] = []
var next_spawn_index: int = 0

func _ready() -> void:
	multiplayer.peer_connected.connect(spawn_player)
	spawned.connect(_on_player_spawned)
	
	# Add to group so it can be found by the initial UI
	add_to_group("multiplayer_spawner")
	
	# Find all spawn points in the scene
	find_spawn_points()
	
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

func find_spawn_points() -> void:
	# Find all Marker2D nodes that are children of SpawnPoints
	var spawn_points_node = get_node("../SpawnPoints")
	if spawn_points_node:
		for child in spawn_points_node.get_children():
			if child is Marker2D:
				spawn_points.append(child)
		print("Found ", spawn_points.size(), " spawn points")
	else:
		print("Warning: No SpawnPoints node found, players will spawn at origin")

func get_next_spawn_position() -> Vector2:
	if spawn_points.is_empty():
		print("No spawn points available, using origin")
		return Vector2.ZERO
	
	var spawn_point = spawn_points[next_spawn_index]
	next_spawn_index = (next_spawn_index + 1) % spawn_points.size()
	return spawn_point.position

func spawn_player(peer_id: int) -> void:
	if !multiplayer.is_server(): return

	print("Spawning player for peer: ", peer_id)
	var player: Node = network_player.instantiate()
	player.name = str(peer_id)
	
	# Set spawn position
	player.position = get_next_spawn_position()
	
	get_node(spawn_path).call_deferred("add_child", player)
	print("Player spawned for peer: ", peer_id, " with name: ", player.name, " at position: ", player.position)
