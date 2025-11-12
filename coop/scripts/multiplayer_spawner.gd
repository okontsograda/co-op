extends MultiplayerSpawner

@export var network_player: PackedScene

var spawn_points: Array[Marker2D] = []
var next_spawn_index: int = 0


func _ready() -> void:
	# Don't auto-spawn on peer_connected - let hub_scene.gd control spawning
	# multiplayer.peer_connected.connect(spawn_player)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	spawned.connect(_on_player_spawned)
	if spawn_function.is_null():
		spawn_function = Callable(self, "_custom_spawn")

	# Add to group so it can be found by the initial UI
	add_to_group("multiplayer_spawner")

	# Find all spawn points in the scene
	find_spawn_points()

	print("[MultiplayerSpawner] Ready in scene: ", get_tree().current_scene.name if get_tree().current_scene else "unknown")


func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected: ", peer_id)
	# The MultiplayerSpawner will handle spawning automatically


func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected: ", peer_id)
	# Find and remove the player node with this peer ID
	var player_node_name = str(peer_id)
	var spawn_path_node = get_node(spawn_path) if has_node(spawn_path) else null
	if spawn_path_node:
		var player = spawn_path_node.get_node_or_null(player_node_name)
		if player:
			print("MultiplayerSpawner: Removing player node: ", player_node_name)
			player.queue_free()
		else:
			# Search in players group as backup
			var players = get_tree().get_nodes_in_group("players")
			for p in players:
				if p.name == player_node_name or p.name.to_int() == peer_id:
					print("MultiplayerSpawner: Removing player node from group: ", p.name)
					p.queue_free()
					break


func _on_player_spawned(node: Node) -> void:
	print("Player spawned via MultiplayerSpawner: ", node.name)
	print("Player position: ", node.position)
	print("Player visible: ", node.visible)


func _custom_spawn(data: Dictionary) -> Node:
	var player_scene: PackedScene = network_player
	if player_scene == null:
		if _spawnable_scenes.is_empty():
			push_error("[MultiplayerSpawner] No player scene configured for spawning")
			return null
		player_scene = ResourceLoader.load(_spawnable_scenes[0])

	var player = player_scene.instantiate()
	_configure_spawned_player(player, data)
	return player


func _configure_spawned_player(player: Node, data: Dictionary) -> void:
	var peer_id: int = data.get("peer_id", 0)
	player.name = str(peer_id)
	player.set_meta("peer_id", peer_id)

	if player is Node2D:
		var spawn_pos: Vector2 = data.get("position", Vector2.ZERO)
		player.position = spawn_pos

	if data.has("class"):
		player.set_meta("selected_class", data["class"])
	if data.has("weapon"):
		player.set_meta("selected_weapon", data["weapon"])


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
	if !multiplayer.is_server():
		print("[MultiplayerSpawner] Not server, skipping spawn for peer: ", peer_id)
		return

	print("[MultiplayerSpawner] Spawning player for peer: ", peer_id)

	# Check if player already exists
	var existing_player = get_node(spawn_path).get_node_or_null(str(peer_id))
	if existing_player:
		print("[MultiplayerSpawner] Player ", peer_id, " already exists, skipping spawn")
		return

	var spawn_pos = get_next_spawn_position()

	var selected_class := "archer"
	var selected_weapon := "bow"
	if LobbyManager and LobbyManager.players.has(peer_id):
		var player_data: Dictionary = LobbyManager.players[peer_id]
		selected_class = player_data.get("class", selected_class)
		selected_weapon = player_data.get("weapon", selected_weapon)
	else:
		print("[MultiplayerSpawner] Warning: No LobbyManager data for peer ", peer_id)

	var spawn_data = {
		"peer_id": peer_id,
		"position": spawn_pos,
		"class": selected_class,
		"weapon": selected_weapon
	}

	var player = spawn(spawn_data)
	if player:
		print("[MultiplayerSpawner] Player spawned for peer: ", peer_id, " with name: ", player.name, " at position: ", player.position)
		player.set_meta("peer_id", peer_id)
		player.set_meta("selected_class", selected_class)
		player.set_meta("selected_weapon", selected_weapon)
	else:
		push_error("[MultiplayerSpawner] spawn() returned null for peer " + str(peer_id))
