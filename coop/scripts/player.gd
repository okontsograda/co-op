extends CharacterBody2D

const speed: float = 200.0
var max_health: int = 100
var current_health: int = max_health
var attack_damage: int = 15  # Base arrow damage

# XP System
var current_xp: int = 0
var current_level: int = 1
var xp_to_next_level: int = 100
const base_xp_per_level: int = 100
const xp_per_enemy_kill: int = 25

var is_firing: bool = false
var can_fire: bool = true
var rapid_fire_count: int = 0  # Track number of arrows fired in rapid succession
const max_rapid_fire: int = 2  # Maximum arrows that can be fired rapidly
const fire_cooldown: float = .5  # Cooldown time after rapid fire

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
	
	# Initialize health bar and XP display
	update_health_display()
	update_xp_display()
	
	# Set up camera to follow this player if this is the local player
	setup_camera()
	
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
	#if direction != Vector2.ZERO:
		#print("Player ", name, " input detected: ", direction)
	
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
	# Check if player can fire (not on cooldown)
	if not can_fire:
		print("Player ", name, " cannot fire yet - on cooldown")
		return
	
	# Check rapid fire limit
	if rapid_fire_count >= max_rapid_fire:
		print("Player ", name, " rapid fire limit reached, must wait")
		return
	
	# Don't allow firing if already in fire animation and at rapid fire limit
	if is_firing and rapid_fire_count >= max_rapid_fire:
		return
	
	# Trigger the fire animation
	var animated_sprite = get_node("AnimatedSprite2D")
	if animated_sprite:
		print("Player ", name, " firing!")
		
		# Increment rapid fire count
		rapid_fire_count += 1
		
		# Convert mouse position to world coordinates for network sync
		var camera = get_viewport().get_camera_2d()
		if camera:
			var world_target = camera.get_global_mouse_position()
			
			# Turn player to face the shooting direction
			var direction_to_target = (world_target - global_position).normalized()
			if direction_to_target.x > 0:
				animated_sprite.flip_h = false  # Face right
			elif direction_to_target.x < 0:
				animated_sprite.flip_h = true  # Face left
			
			# Play fire animation
			is_firing = true
			animated_sprite.play("fire")
			
			# Wait for animation to play before firing arrow (about halfway through fire animation)
			await get_tree().create_timer(0.5).timeout
			# Spawn arrow locally immediately
			spawn_arrow_for_player(self, world_target)
			# Send RPC to network to spawn arrow on other clients
			rpc("spawn_arrow_network", world_target)
		
		# After remaining animation time, return to normal animation
		await get_tree().create_timer(0.4).timeout
		is_firing = false
		print("Player ", name, " finished firing")
		
		# Allow immediate refire if under rapid fire limit, otherwise wait for cooldown
		if rapid_fire_count < max_rapid_fire:
			# Allow rapid fire - can fire again immediately
			print("Player ", name, " rapid fire available: ", rapid_fire_count, "/", max_rapid_fire)
		else:
			# Rapid fire limit reached, wait for cooldown
			can_fire = false
			await get_tree().create_timer(fire_cooldown).timeout
			can_fire = true
			rapid_fire_count = 0  # Reset rapid fire counter
			print("Player ", name, " can fire again")
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

func setup_camera() -> void:
	# Check if this is the local player
	var peer_id = name.to_int()
	if peer_id == multiplayer.get_unique_id():
		# Find and attach the camera from the scene
		var scene_camera = get_tree().current_scene.get_node_or_null("Camera2D")
		if scene_camera:
			# Move camera to follow this player
			scene_camera.reparent(self)
			scene_camera.position = Vector2.ZERO
			scene_camera.zoom = Vector2(1.15, 1.15)
			print("Attached camera to player ", name)
		else:
			# Create a new camera if none exists
			var camera = Camera2D.new()
			camera.limit_left = -2000
			camera.limit_top = -2000
			camera.limit_right = 2000
			camera.limit_bottom = 2000
			camera.zoom = Vector2(0.5, 0.5)  # Zoom in to 50% (2x closer)
			add_child(camera)
			print("Created camera for player ", name)

func update_health_display() -> void:
	# Update the health bar display
	var health_bar = get_node_or_null("HealthBar")
	if health_bar:
		health_bar.update_health(current_health, max_health)

func update_xp_display() -> void:
	# Update the XP bar
	var xp_bar = get_node_or_null("XPBar")
	if xp_bar:
		xp_bar.update_xp(current_xp, xp_to_next_level)
	
	# Update the level label
	var level_label = get_node_or_null("LevelLabel")
	if level_label:
		level_label.text = "Lv." + str(current_level)

func take_damage(amount: int, attacker: Node2D) -> void:
	# Apply damage locally
	
	# Reduce health
	current_health -= amount
	print("Player ", name, " took ", amount, " damage. Health: ", current_health, "/", max_health)
	
	# Broadcast health update to all clients
	rpc("sync_player_health", current_health)
	
	# Update health bar
	update_health_display()
	
	# Check if player died
	if current_health <= 0:
		current_health = 0
		handle_death()
		rpc("on_player_died", str(attacker.name) if attacker else "unknown")

@rpc("any_peer", "reliable", "call_local")
func sync_player_health(health: int) -> void:
	# Update health on all clients (including the local player)
	current_health = health
	update_health_display()
	print("Synced health for player ", name, ": ", current_health, "/", max_health)

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

# XP System Functions
func gain_xp(amount: int) -> void:
	# Always call via RPC so it processes on the correct player instance
	rpc("gain_xp_rpc", amount)

@rpc("any_peer", "reliable", "call_local")
func gain_xp_rpc(amount: int) -> void:
	print("gain_xp_rpc called for player ", name, ", is_multiplayer_authority: ", is_multiplayer_authority())
	# Only process on the player who has authority
	if not is_multiplayer_authority():
		print("Player ", name, " not authority, returning")
		return
	
	current_xp += amount
	print("Player ", name, " gained ", amount, " XP. Total: ", current_xp)
	
	# Check for level up
	while current_xp >= xp_to_next_level:
		level_up()
	
	# Update XP display locally
	update_xp_display()
	
	# Sync XP to all clients (including self via call_local)
	rpc("sync_xp", current_xp, current_level, xp_to_next_level)
	print("Sent sync_xp RPC: ", current_xp, "/", xp_to_next_level, " level ", current_level)

func level_up() -> void:
	current_xp -= xp_to_next_level
	current_level += 1
	
	# Increase XP requirement for next level (scaling)
	xp_to_next_level = base_xp_per_level * current_level
	
	# Level up bonuses
	max_health += 10
	current_health = max_health  # Full heal on level up
	attack_damage += 5  # Increase attack damage by 5 per level
	
	print("Player ", name, " leveled up to level ", current_level, "!")
	print("New max health: ", max_health)
	print("New attack damage: ", attack_damage)
	
	# Update health bar
	update_health_display()
	
	# Sync level up to all clients
	rpc("sync_level_up", current_level, max_health, current_xp, xp_to_next_level, attack_damage)

@rpc("any_peer", "reliable", "call_local")
func sync_xp(xp: int, level: int, xp_needed: int) -> void:
	print("sync_xp RPC received for player ", name, ": ", xp, "/", xp_needed, " level ", level)
	current_xp = xp
	current_level = level
	xp_to_next_level = xp_needed
	update_xp_display()
	print("Synced XP for player ", name, ": ", current_xp, "/", xp_to_next_level, " (Level ", current_level, ")")

@rpc("any_peer", "reliable", "call_local")
func sync_level_up(level: int, new_max_health: int, xp: int, xp_needed: int, new_attack_damage: int) -> void:
	current_level = level
	max_health = new_max_health
	current_health = max_health
	current_xp = xp
	xp_to_next_level = xp_needed
	attack_damage = new_attack_damage
	update_health_display()
	update_xp_display()
	print("Synced level up for player ", name, ": Level ", current_level, ", Health: ", max_health, ", Attack Damage: ", attack_damage)

func get_attack_damage() -> int:
	return attack_damage
