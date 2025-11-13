extends Node2D

var local_player: Node2D = null


func _ready():
	await NetworkHandler.notify_scene_ready(self, NetworkHandler.SceneType.MISSION)


func initialize_host_mode(data: Dictionary = {}):
	print("[Mission] Host initializing mission scene: ", data)
	await NetworkHandler.start_game_from_lobby()


func initialize_client_mode(_data: Dictionary = {}):
	print("[Mission] Client waiting for mission spawn")
	await _wait_for_local_player()


func initialize_solo_mode(data: Dictionary = {}):
	print("[Mission] Solo mission initialization")
	await NetworkHandler.start_game_from_lobby()


func _wait_for_local_player():
	var peer_id = multiplayer.get_unique_id()
	var attempts := 0
	while attempts < 20:
		var player_node = _get_player_node_by_peer(peer_id)
		if player_node:
			local_player = player_node
			print("[Mission] Local player found: ", peer_id)
			return

		attempts += 1
		await get_tree().create_timer(0.3).timeout

	push_error("[Mission] Failed to find local player for peer %d" % peer_id)


func _get_player_node_by_peer(peer_id: int) -> Node2D:
	var node = get_node_or_null(str(peer_id))
	if node and node is Node2D:
		return node

	for player in get_tree().get_nodes_in_group("players"):
		if str(player.name) == str(peer_id):
			return player
		if player.has_meta("peer_id") and int(player.get_meta("peer_id")) == peer_id:
			return player

	return null
