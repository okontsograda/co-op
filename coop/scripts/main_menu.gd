extends Control


func _ready():
	# Connect button signals
	$VBoxContainer/HostButton.pressed.connect(_on_host_pressed)
	$VBoxContainer/JoinButton.pressed.connect(_on_join_pressed)
	$VBoxContainer/ExitButton.pressed.connect(_on_exit_pressed)


func _on_host_pressed() -> void:
	print("Host button pressed")
	# Start server which will transition to lobby
	NetworkHandler.start_server()


func _on_join_pressed() -> void:
	var host_id = $VBoxContainer/HostIDInput.text.strip_edges()

	if host_id.is_empty():
		print("ERROR: No host ID provided")
		# TODO: Show error message to user
		return

	print("Join button pressed with host ID: ", host_id)
	# Join server which will transition to lobby
	NetworkHandler.start_client(host_id)


func _on_exit_pressed() -> void:
	print("Exit button pressed")
	get_tree().quit()
