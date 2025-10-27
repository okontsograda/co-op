extends CharacterBody2D

const speed: float = 200.0
const max_health: int = 100
var current_health: int = max_health

var is_firing: bool = false

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
	
	# Initialize health bar
	update_health_display()
	
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
	
	# Handle fire animation on left mouse click
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			# Only handle if this is the current player
			var peer_id = name.to_int()
			if peer_id == multiplayer.get_unique_id():
				handle_fire_action(mouse_event.position)

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
	
	# Update animation based on movement
	update_animation(direction)
func _on_chat_message_received(player_name: String, message: String) -> void:
	print("Player ", name, " received chat message from ", player_name, ": ", message)
	
	# Check if this message is from this specific player
	var is_message_from_this_player = (player_name == name or player_name == str(name.to_int()))
	
	if is_message_from_this_player:
		print("This is our own message, ignoring (already shown locally)")
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

func handle_fire_action(_mouse_position: Vector2) -> void:
	# Trigger the fire animation
	var animated_sprite = get_node("AnimatedSprite2D")
	if animated_sprite:
		print("Player ", name, " firing!")
		is_firing = true
		animated_sprite.play("fire")
		
		# Wait for animation to play before firing arrow (about halfway through fire animation)
		await get_tree().create_timer(0.4).timeout
		
		# Convert mouse position to world coordinates for network sync
		var camera = get_viewport().get_camera_2d()
		if camera:
			var world_target = camera.get_global_mouse_position()
			# Spawn arrow locally immediately
			spawn_arrow_for_player(self, world_target)
			# Send RPC to network to spawn arrow on other clients
			rpc("spawn_arrow_network", world_target)
		
		# After remaining animation time, return to normal animation
		await get_tree().create_timer(0.4).timeout
		is_firing = false
		print("Player ", name, " finished firing")
	else:
		print("ERROR: AnimatedSprite2D not found!")
	
@rpc("any_peer", "reliable")
func spawn_arrow_network(target_pos: Vector2) -> void:
	# This function is called on all clients to spawn the arrow
	# Get the player who sent this RPC
	var shooter_peer_id = multiplayer.get_remote_sender_id()
	
	# Find the shooter player
	var shooter = null
	for player in get_tree().get_nodes_in_group("players"):
		if player.name.to_int() == shooter_peer_id:
			shooter = player
			break
	
	if shooter:
		spawn_arrow_for_player(shooter, target_pos)

func spawn_arrow_for_player(shooter: Node2D, target_pos: Vector2) -> void:
	# Load the arrow scene
	var arrow_scene = preload("res://coop/scenes/arrow.tscn")
	var arrow = arrow_scene.instantiate()
	
	# Target position should already be in world coordinates
	var world_target = target_pos
	
	# Get the animated sprite to use its position as reference
	var animated_sprite = shooter.get_node("AnimatedSprite2D")
	var sprite_position = animated_sprite.global_position if animated_sprite else shooter.global_position
	
	# Spawn arrow slightly ahead of the player sprite (to avoid clipping)
	var direction_to_target = (world_target - sprite_position).normalized()
	var spawn_offset = direction_to_target * 30.0  # 30 pixels ahead of sprite
	var spawn_position = sprite_position + spawn_offset
	
	# Initialize the arrow
	arrow.initialize(self, spawn_position, world_target)
	
	# Add arrow to the scene tree
	get_tree().current_scene.add_child(arrow)
	
	print("Player ", name, " spawned arrow at ", spawn_position, " targeting ", world_target)

func update_animation(direction: Vector2) -> void:
	# Don't update animation if we're firing
	if is_firing:
		return
	
	# Get the AnimatedSprite2D node
	var animated_sprite = get_node("AnimatedSprite2D")
	if not animated_sprite:
		return
	
	# Determine which animation to play based on movement
	if direction != Vector2.ZERO:
		# Player is moving - play walk animation
		if animated_sprite.animation != "walk":
			animated_sprite.play("walk")
			
		# Flip sprite based on horizontal direction
		if direction.x < 0:
			animated_sprite.flip_h = true
		elif direction.x > 0:
			animated_sprite.flip_h = false
	else:
		# Player is stationary - play idle animation
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")

func update_health_display() -> void:
	# Update the health bar display
	var health_bar = get_node_or_null("HealthBar")
	if health_bar:
		health_bar.update_health(current_health, max_health)

func take_damage(amount: int, attacker: Node2D) -> void:
	# Apply damage locally
	
	# Reduce health
	current_health -= amount
	print("Player ", name, " took ", amount, " damage. Health: ", current_health, "/", max_health)
	
	# Update health bar
	update_health_display()
	
	# Check if player died
	if current_health <= 0:
		current_health = 0
		handle_death()
		rpc("on_player_died", str(attacker.name) if attacker else "unknown")

@rpc("any_peer", "reliable")
func on_player_died(_killer: String) -> void:
	# Handle death (e.g., respawn, show death message, etc.)
	print("Player ", name, " died!")
	# You can add death effects here

func handle_death() -> void:
	# Handle death on authority/server
	print("Player ", name, " has died!")
	# Reset health
	current_health = max_health
	# Update health bar
	update_health_display()
	# You can add respawn logic here

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
