extends CanvasLayer

# Invite UI - Allows players to host games or join others from the village

var current_player: Node = null
var is_hosting: bool = false

@onready var host_button = %HostButton
@onready var host_id_label = %HostIDLabel
@onready var host_id_display = %HostIDDisplay
@onready var copy_button = %CopyButton
@onready var join_container = %JoinContainer
@onready var host_id_input = %HostIDInput
@onready var join_button = %JoinButton
@onready var close_button = %CloseButton
@onready var status_label = %StatusLabel


func _ready() -> void:
	# Add to UI group for blocking detection
	add_to_group("ui")

	# Wait one frame to ensure all nodes are loaded
	await get_tree().process_frame

	# Connect buttons with null checks
	if host_button:
		host_button.pressed.connect(_on_host_button_pressed)
	else:
		print("ERROR: HostButton not found")

	if copy_button:
		copy_button.pressed.connect(_on_copy_button_pressed)
	else:
		print("ERROR: CopyButton not found")

	if join_button:
		join_button.pressed.connect(_on_join_button_pressed)
	else:
		print("ERROR: JoinButton not found")

	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	else:
		print("ERROR: CloseButton not found")

	# Listen for ESC key to close
	set_process_input(true)

	# Initial state
	update_ui_state()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # ESC key
		_on_close_button_pressed()
		get_viewport().set_input_as_handled()


func open_invite_menu(player: Node) -> void:
	current_player = player
	print("Invite menu opened for player: ", player.name)

	# Check if already hosting
	check_hosting_status()

	# Show the UI
	visible = true


func check_hosting_status() -> void:
	# Check if we're already hosting with actual network peers (not just offline peer)
	var network_handler = get_node_or_null("/root/NetworkHandler")
	if network_handler:
		# Check if we're hosting AND have a network peer with an actual online_id
		var has_network_peer = multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
		var has_online_id = network_handler.peer.online_id != null and not network_handler.peer.online_id.is_empty()

		is_hosting = multiplayer.is_server() and has_network_peer and has_online_id

		if is_hosting:
			# Already hosting, show the host ID
			var host_id = network_handler.peer.online_id
			display_host_id(host_id)
		else:
			update_ui_state()
	else:
		update_ui_state()


func update_ui_state() -> void:
	if is_hosting:
		# Hosting mode - show host ID, hide join options
		if host_button:
			host_button.visible = false
		if host_id_label:
			host_id_label.visible = true
		if host_id_display:
			host_id_display.visible = true
		if copy_button:
			copy_button.visible = true
		if join_container:
			join_container.visible = false
		if status_label:
			status_label.text = "You are hosting! Share your ID:"
	else:
		# Not hosting - show host and join options
		if host_button:
			host_button.visible = true
		if host_id_label:
			host_id_label.visible = false
		if host_id_display:
			host_id_display.visible = false
		if copy_button:
			copy_button.visible = false
		if join_container:
			join_container.visible = true
		if status_label:
			status_label.text = "Invite others to your village"


func _on_host_button_pressed() -> void:
	print("Host button pressed")
	if status_label:
		status_label.text = "Starting host..."
	if host_button:
		host_button.disabled = true

	var network_handler = get_node_or_null("/root/NetworkHandler")
	if not network_handler:
		print("ERROR: NetworkHandler not found!")
		if status_label:
			status_label.text = "Error: Could not start hosting"
		if host_button:
			host_button.disabled = false
		return

	# Start hosting
	var host_id = await network_handler.start_hosting_in_village()

	if host_id and not host_id.is_empty():
		print("Hosting started with ID: ", host_id)
		is_hosting = true
		display_host_id(host_id)
	else:
		print("ERROR: Failed to start hosting")
		if status_label:
			status_label.text = "Error: Failed to start hosting"
		if host_button:
			host_button.disabled = false


func display_host_id(host_id: String) -> void:
	if host_id_display:
		host_id_display.text = host_id
	if status_label:
		status_label.text = "Hosting! Share your ID:"
	update_ui_state()
	print("Displaying host ID: ", host_id)


func _on_copy_button_pressed() -> void:
	if not host_id_display:
		return

	var host_id = host_id_display.text
	DisplayServer.clipboard_set(host_id)
	print("Copied host ID to clipboard: ", host_id)

	if status_label:
		status_label.text = "ID copied to clipboard!"

	# Reset status after a moment
	await get_tree().create_timer(2.0).timeout
	if is_hosting and status_label:
		status_label.text = "Hosting! Share your ID:"


func _on_join_button_pressed() -> void:
	if not host_id_input:
		print("ERROR: host_id_input is null")
		return

	var host_id = host_id_input.text.strip_edges()

	if host_id.is_empty():
		if status_label:
			status_label.text = "Please enter a Host ID"
		print("ERROR: No host ID provided")
		return

	print("Join button pressed with host ID: ", host_id)
	if status_label:
		status_label.text = "Joining..."
	if join_button:
		join_button.disabled = true

	var network_handler = get_node_or_null("/root/NetworkHandler")
	if not network_handler:
		print("ERROR: NetworkHandler not found!")
		if status_label:
			status_label.text = "Error: Could not join"
		if join_button:
			join_button.disabled = false
		return

	# Close this UI
	queue_free()

	# Join the host
	network_handler.join_village_host(host_id)


func _on_close_button_pressed() -> void:
	print("Closing invite UI")
	queue_free()


func is_ui_blocking() -> bool:
	return visible
