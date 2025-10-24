extends Control


func _on_server_pressed() -> void:
	NetworkHandler.start_server()
	# Spawn the server player after starting the server
	await get_tree().create_timer(0.1).timeout
	spawn_server_player()
	visible = false

func spawn_server_player() -> void:
	# Find the multiplayer spawner and spawn the server player
	var spawner = get_tree().get_first_node_in_group("multiplayer_spawner")
	if spawner:
		spawner.spawn_player(1)  # Server is always peer 1
		print("Server player spawned after hosting started")


func _on_client_pressed() -> void:
	NetworkHandler.start_client()
	visible = false
