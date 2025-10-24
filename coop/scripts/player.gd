extends CharacterBody2D

const speed: float = 500.0

func _ready() -> void:
	# Set authority based on the player's name (peer ID)
	var peer_id = name.to_int()
	set_multiplayer_authority(peer_id)
	print("Player ", name, " (peer ", peer_id, ") has authority: ", is_multiplayer_authority())
	print("Current multiplayer peer: ", multiplayer.get_unique_id())
	print("Is server: ", multiplayer.is_server())
	print("Player position: ", position)
	print("Player visible: ", visible)
	
	# Add to players group so it can be found by other players
	add_to_group("players")
	
	# Try using the actual multiplayer peer ID instead
	if peer_id == multiplayer.get_unique_id():
		print("This player should have authority!")
	else:
		print("This player should NOT have authority")
	
	# Connect to network handler for receiving chat messages
	if NetworkHandler:
		NetworkHandler.chat_message_received.connect(_on_chat_message_received)

func _input(event: InputEvent) -> void:
	# Handle chat input for the player whose peer ID matches the current multiplayer peer
	if event.is_action_pressed("chat_toggle") and not event.is_echo():
		# Only handle chat if this is the current player (peer ID matches)
		var peer_id = name.to_int()
		if peer_id == multiplayer.get_unique_id():
			print("Player ", name, " (peer ", peer_id, ") handling chat input")
			var chat_ui = get_node("ChatUI")
			if chat_ui:
				# Add a small delay to prevent double processing
				await get_tree().process_frame
				chat_ui.toggle_chat()
			else:
				print("ERROR: ChatUI not found for player ", name)
		else:
			print("Player ", name, " (peer ", peer_id, ") ignoring chat input (not current player)")
		return

func _physics_process(_delta: float) -> void:
	# Only process movement for players with authority
	if !is_multiplayer_authority(): 
		return
	
	# Check if chat is active - if so, don't process movement
	var chat_ui = get_node("ChatUI")
	if chat_ui and chat_ui.is_chat_active:
		# Chat is active, don't process movement
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Use direct key input instead of input actions
	var direction = Vector2()
	
	# Check for WASD keys
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1
	
	# Also try input actions as fallback
	if direction == Vector2.ZERO:
		direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Debug input detection (removed spam)
	if direction != Vector2.ZERO:
		print("Player ", name, " input detected: ", direction)
	
	velocity = direction * speed
	move_and_slide()
func _on_chat_message_received(player_name: String, message: String) -> void:
	print("Player ", name, " received chat message from ", player_name, ": ", message)
	print("Player ", name, " peer ID: ", name.to_int(), ", message from: ", player_name)
	print("Player ", name, " multiplayer unique ID: ", multiplayer.get_unique_id())
	
	# Check if this message is from this specific player
	var is_message_from_this_player = (player_name == name or player_name == str(name.to_int()))
	
	print("DEBUG: player_name = '", player_name, "'")
	print("DEBUG: name = '", name, "'")
	print("DEBUG: str(name.to_int()) = '", str(name.to_int()), "'")
	print("DEBUG: is_message_from_this_player = ", is_message_from_this_player)
	
	if is_message_from_this_player:
		print("This message is from this player, showing chat bubble")
		var chat_bubble = get_node("ChatBubble")
		if chat_bubble:
			print("Chat bubble found, showing message")
			chat_bubble.show_message(message)
		else:
			print("ERROR: Chat bubble not found!")
	else:
		print("Message from another player, finding their player and showing chat bubble")
		# Find the player who sent this message and show it above them
		var sender_player = find_player_by_name(player_name)
		if sender_player:
			var chat_bubble = sender_player.get_node("ChatBubble")
			if chat_bubble:
				print("Chat bubble found on sender player, showing message")
				chat_bubble.show_message(message)
			else:
				print("ERROR: Chat bubble not found on sender player!")
		else:
			print("ERROR: Sender player not found!")

func find_player_by_name(player_name: String) -> Node2D:
	# Find the player with the given name in the scene
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if player.name == player_name or str(player.name.to_int()) == player_name:
			return player
	
	# Fallback: search all nodes in the scene
	var all_nodes = get_tree().get_nodes_in_group("")
	for node in all_nodes:
		if node.name == player_name and node.has_method("get_node"):
			return node
	
	return null
