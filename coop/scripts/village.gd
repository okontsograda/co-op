extends Node2D

# References to optional UI elements (may not exist in scene)
@onready var start_adventure_button = get_node_or_null("%StartAdventureButton")
@onready var upgrades_button = get_node_or_null("%UpgradesButton")
@onready var class_selection_button = get_node_or_null("%ClassSelectionButton")
@onready var players_container = get_node_or_null("%PlayersContainer")

var is_host: bool = false
var adventure_started: bool = false

func _ready() -> void:
	# Check if we're the host
	is_host = multiplayer.is_server()

	# Setup UI based on role (if UI elements exist)
	setup_ui()

	# Connect signals
	if start_adventure_button:
		start_adventure_button.pressed.connect(_on_start_adventure_pressed)

	# Setup multiplayer signals
	if multiplayer.has_multiplayer_peer():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Update players list (if UI exists)
	update_players_list()

	# Call NetworkHandler to spawn players
	call_deferred("spawn_village_players")

func setup_ui() -> void:
	# Only update UI if button exists
	if not start_adventure_button:
		return

	# Only host can start adventure in multiplayer
	if multiplayer.has_multiplayer_peer() and not is_host:
		start_adventure_button.text = "Waiting for Host..."
		start_adventure_button.disabled = true
	else:
		start_adventure_button.disabled = false

func spawn_village_players() -> void:
	# Let NetworkHandler handle the spawning
	var network_handler = get_node_or_null("/root/NetworkHandler")
	if network_handler:
		if is_host or not multiplayer.has_multiplayer_peer():
			# We're host or in local mode, spawn all players
			network_handler.spawn_players_in_village()

func _on_start_adventure_pressed() -> void:
	if adventure_started:
		return

	adventure_started = true

	if multiplayer.has_multiplayer_peer():
		# Multiplayer mode - tell everyone to start
		if is_host:
			start_adventure_for_all.rpc()
	else:
		# Local mode - just transition
		transition_to_game()

@rpc("call_local", "any_peer", "reliable")
func start_adventure_for_all() -> void:
	transition_to_game()

func transition_to_game() -> void:
	# Transition to the game scene
	var network_handler = get_node_or_null("/root/NetworkHandler")
	if network_handler:
		network_handler.transition_from_village_to_game()
	else:
		# Fallback
		get_tree().change_scene_to_file("res://coop/scenes/example.tscn")

func update_players_list() -> void:
	# Only update if players container exists
	if not players_container:
		return

	# Clear existing player labels
	for child in players_container.get_children():
		child.queue_free()

	# Get lobby manager to check connected players
	var lobby_manager = get_node_or_null("/root/LobbyManager")
	if lobby_manager and lobby_manager.players.size() > 0:
		for peer_id in lobby_manager.players:
			var player_data = lobby_manager.players[peer_id]
			var player_label = Label.new()
			var player_name = player_data.get("player_name", "Player")
			var player_class = player_data.get("class", "archer").capitalize()
			player_label.text = "%s (%s)" % [player_name, player_class]
			players_container.add_child(player_label)
	else:
		# Local mode or no lobby data yet
		var player_label = Label.new()
		player_label.text = "You"
		players_container.add_child(player_label)

func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected to village: ", peer_id)
	update_players_list()

	# If we're the host, tell NetworkHandler to spawn the new peer
	if is_host:
		var network_handler = get_node_or_null("/root/NetworkHandler")
		if network_handler:
			network_handler.spawn_peer_in_village(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected from village: ", peer_id)
	update_players_list()
