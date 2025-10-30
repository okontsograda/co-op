extends Control


func _on_server_pressed() -> void:
	NetworkHandler.start_server()  # This will now handle player spawning internally
	visible = false


func _on_client_pressed() -> void:
	# Pass the host ID as a parameter
	var host_id = %HostOnlineID.text
	NetworkHandler.start_client(host_id)
	visible = false
