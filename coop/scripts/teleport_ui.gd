extends CanvasLayer

# Teleport UI - Shows available destinations for teleportation

var current_player: Node = null

@onready var village_button = %VillageButton
@onready var adventure_button = %AdventureButton
@onready var close_button = %CloseButton
@onready var destinations_container = %DestinationsContainer


func _ready() -> void:
	# Add to UI group for blocking detection
	add_to_group("ui")

	# Connect buttons
	if village_button:
		village_button.pressed.connect(_on_village_button_pressed)
	if adventure_button:
		adventure_button.pressed.connect(_on_adventure_button_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

	# Listen for ESC key to close
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # ESC key
		_on_close_button_pressed()
		get_viewport().set_input_as_handled()


func open_teleport_menu(player: Node) -> void:
	current_player = player
	print("Teleport menu opened for player: ", player.name)

	# Show appropriate destinations based on current scene
	update_available_destinations()

	# Show the UI
	visible = true


func update_available_destinations() -> void:
	# Get current scene name
	var current_scene = get_tree().current_scene
	var current_scene_name = current_scene.name if current_scene else ""

	print("Current scene: ", current_scene_name)

	# Hide buttons based on current location
	if current_scene_name == "Village":
		# In village, show adventure option but not village
		village_button.visible = false
		adventure_button.visible = true
		adventure_button.text = "Adventure Zone"
	elif current_scene_name == "Example":  # The game scene
		# In adventure, show village option but not adventure
		village_button.visible = true
		village_button.text = "Return to Village"
		adventure_button.visible = false
	else:
		# Unknown scene, show both
		village_button.visible = true
		adventure_button.visible = true


func _on_village_button_pressed() -> void:
	print("Teleporting to Village...")
	teleport_to_scene("res://coop/scenes/village.tscn")


func _on_adventure_button_pressed() -> void:
	print("Teleporting to Adventure Zone...")
	teleport_to_scene("res://coop/scenes/example.tscn")


func teleport_to_scene(scene_path: String) -> void:
	# Only host/server can initiate scene change in multiplayer
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		print("ERROR: Only host can change scenes!")
		# TODO: Could implement a "request teleport" RPC to ask host
		_on_close_button_pressed()
		return

	# Close the UI first
	_on_close_button_pressed()

	# Wait a frame for UI to close
	await get_tree().process_frame

	# Determine if we're going to or from the game scene
	var current_scene = get_tree().current_scene
	var going_to_game = scene_path.contains("example.tscn")
	var leaving_game = current_scene and current_scene.name == "Example"

	if going_to_game:
		# Transitioning from village to game
		var network_handler = get_node_or_null("/root/NetworkHandler")
		if network_handler and network_handler.has_method("transition_from_village_to_game"):
			network_handler.transition_from_village_to_game()
		else:
			# Fallback - simple scene change
			simple_scene_transition(scene_path)
	elif leaving_game:
		# Transitioning from game back to village
		transition_from_game_to_village()
	else:
		# Other transitions - simple scene change
		simple_scene_transition(scene_path)


func transition_from_game_to_village() -> void:
	print("Transitioning from game to village...")

	# Remove all players from current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		for child in current_scene.get_children():
			if child.name.is_valid_int():  # Player nodes are named by peer_id
				child.queue_free()

	# Change to village scene
	get_tree().change_scene_to_file("res://coop/scenes/village.tscn")

	# Wait for scene to load
	await get_tree().create_timer(0.3).timeout

	# Spawn players in village
	var network_handler = get_node_or_null("/root/NetworkHandler")
	if network_handler:
		if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
			network_handler.spawn_players_in_village()

	print("Transition to village complete!")


func simple_scene_transition(scene_path: String) -> void:
	print("Simple scene transition to: ", scene_path)

	# Remove players from current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		for child in current_scene.get_children():
			if child.name.is_valid_int():  # Player nodes
				child.queue_free()

	# Change scene
	get_tree().change_scene_to_file(scene_path)

	# Wait for scene to load
	await get_tree().create_timer(0.3).timeout

	# Respawn players
	var network_handler = get_node_or_null("/root/NetworkHandler")
	if network_handler:
		if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
			# Check if it's village scene
			if scene_path.contains("village"):
				network_handler.spawn_players_in_village()
			else:
				# For other scenes, use regular spawning
				network_handler.spawn_players_with_classes()


func _on_close_button_pressed() -> void:
	print("Closing teleport UI")
	queue_free()


func is_ui_blocking() -> bool:
	return visible
