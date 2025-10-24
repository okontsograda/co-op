extends Control

@onready var chat_input: LineEdit = $ChatInput

var is_chat_active: bool = false
var toggle_cooldown: float = 0.1
var last_toggle_time: float = 0.0

func get_player() -> Node2D:
	# Get the player node (parent of this ChatUI)
	return get_parent()

func _ready() -> void:
	chat_input.text_submitted.connect(_on_text_submitted)
	chat_input.focus_entered.connect(_on_focus_entered)
	chat_input.focus_exited.connect(_on_focus_exited)
	
	# Connect to network handler for receiving messages
	if NetworkHandler:
		NetworkHandler.chat_message_received.connect(_on_chat_message_received)

# Input handling moved to player script

func toggle_chat() -> void:
	var current_time = Time.get_time_dict_from_system()["second"] + Time.get_time_dict_from_system()["minute"] * 60.0
	if current_time - last_toggle_time < toggle_cooldown:
		print("ChatUI: Toggle cooldown active, ignoring")
		return
	
	last_toggle_time = current_time
	print("ChatUI: toggle_chat called, current state: ", is_chat_active)
	if is_chat_active:
		close_chat()
	else:
		open_chat()

func open_chat() -> void:
	print("ChatUI: Opening chat input")
	is_chat_active = true
	chat_input.visible = true
	chat_input.grab_focus()
	chat_input.text = ""
	print("ChatUI: Chat input opened, visible = ", chat_input.visible)

func close_chat() -> void:
	print("ChatUI: Closing chat input")
	is_chat_active = false
	chat_input.visible = false
	chat_input.release_focus()
	chat_input.text = ""
	print("ChatUI: Chat input closed, visible = ", chat_input.visible)

func _on_text_submitted(text: String) -> void:
	print("ChatUI: Text submitted: ", text)
	if text.strip_edges() == "":
		print("ChatUI: Empty message, closing chat")
		close_chat()
		return
	
	# Show our own message above our player immediately
	show_own_message(text.strip_edges())
	
	# Send message through network handler
	if NetworkHandler:
		print("ChatUI: Sending message through NetworkHandler")
		NetworkHandler.send_chat_message(text.strip_edges())
	else:
		print("ERROR: NetworkHandler not found!")
	
	# Add a small delay before closing to ensure message is sent
	await get_tree().process_frame
	print("ChatUI: Closing chat after sending message")
	close_chat()

func show_own_message(message: String) -> void:
	# Show our own message above our player immediately
	var player = get_player()
	if player:
		var chat_bubble = player.get_node("ChatBubble")
		if chat_bubble:
			print("ChatUI: Showing own message above player: ", message)
			chat_bubble.show_message(message)
		else:
			print("ERROR: ChatBubble not found on player!")
	else:
		print("ERROR: Player not found!")

func _on_focus_entered() -> void:
	# Disable player movement when typing
	get_viewport().set_input_as_handled()

func _on_focus_exited() -> void:
	# Re-enable player movement
	pass

func _on_chat_message_received(player_name: String, message: String) -> void:
	print("ChatUI: Received chat message from ", player_name, ": ", message)
	# Chat bubbles above players handle the display, no need for chat log

# Chat log functionality removed - only chat bubbles above players are used
