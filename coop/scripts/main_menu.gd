extends Control


func _ready():
	# Connect button signals
	$VBoxContainer/StartGameButton.pressed.connect(_on_start_game_pressed)
	$VBoxContainer/ExitButton.pressed.connect(_on_exit_pressed)

	# Connect name input signals
	%NameInput.text_changed.connect(_on_name_changed)
	%NameInput.text_submitted.connect(_on_name_submitted)

	# Load saved player name
	_load_player_name()


func _load_player_name() -> void:
	# Wait for SaveSystem to load if it hasn't yet
	if not SaveSystem.is_loaded:
		await SaveSystem.data_loaded
	
	var saved_name = SaveSystem.get_player_name()
	%NameInput.text = saved_name
	print("[MainMenu] Loaded player name: ", saved_name)


func _on_name_changed(new_text: String) -> void:
	# Sanitize input (remove leading/trailing whitespace)
	var sanitized = new_text.strip_edges()
	
	# Don't allow empty names
	if sanitized.is_empty():
		return
	
	# Save the name as they type (with a slight delay handled by the LineEdit)
	SaveSystem.set_player_name(sanitized)
	print("[MainMenu] Player name updated to: ", sanitized)


func _on_name_submitted(new_text: String) -> void:
	# When user presses Enter, save and release focus
	var sanitized = new_text.strip_edges()
	
	if not sanitized.is_empty():
		SaveSystem.set_player_name(sanitized)
		%NameInput.release_focus()
		print("[MainMenu] Player name saved: ", sanitized)


func _on_start_game_pressed() -> void:
	print("Start Game button pressed")
	# Start local game in village with knight class
	NetworkHandler.start_local_game_with_class("knight")


func _on_exit_pressed() -> void:
	print("Exit button pressed")
	get_tree().quit()
