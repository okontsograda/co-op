extends CharacterBody2D

# Movement speeds
const walk_speed: float = 100.0  # Default walking speed
const run_speed: float = 135.0  # Running speed (when holding Shift)
var current_speed: float = walk_speed
var class_speed_modifier: float = 1.0  # Modifier from class selection

# Stamina system
var max_stamina: float = 100.0
var current_stamina: float = 100.0
const stamina_drain_rate: float = 40.0  # Stamina drained per second when running
const stamina_regen_rate: float = 25.0  # Stamina regenerated per second when not running
var is_running: bool = false

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

# Weapon System
var equipped_weapon: String = "bow"  # Default to bow, can be set from lobby
var current_weapon_config: WeaponData.WeaponConfig = null

# Preload weapon scenes for network compatibility
const ARROW_SCENE = preload("res://coop/scenes/arrow.tscn")
const ROCKET_SCENE = preload("res://coop/scenes/rocket.tscn")

# Upgrade System - Weapon Stats
var weapon_stats = {
	"damage": 0.0,  # Additional flat damage (base is attack_damage)
	"damage_multiplier": 1.0,  # Multiplicative damage bonus
	"fire_cooldown": fire_cooldown,  # Cooldown between shots
	"pierce_count": 0,  # Number of enemies arrow can pierce
	"multishot_count": 1,  # Number of arrows fired per shot
	"arrow_speed": 500.0,  # Base arrow speed
	"crit_chance": 0.0,  # Critical hit chance (0.0 to 1.0)
	"crit_multiplier": 2.0,  # Critical hit damage multiplier
	"explosion_chance": 0.0,  # Chance for arrows to explode on hit
	"explosion_radius": 30.0,  # Radius of explosion damage
	"explosion_damage": 0.0,  # Explosion damage (0 = use arrow damage)
	"lifesteal": 0,  # HP gained per enemy hit
	"poison_damage": 0,  # Damage per second from poison
	"poison_duration": 0.0,  # Duration of poison effect in seconds
	"homing_strength": 0.0,  # Strength of homing effect (0.0 to 1.0)
}

# Upgrade tracking - how many times each upgrade has been taken
var upgrade_stacks = {}

# Active abilities (arrow nova, summon archer, shield, etc.)
var active_abilities = []

# Signal emitted when player levels up and is ready for upgrade selection
signal level_up_ready

# Sound effects
var bow_sound_player: AudioStreamPlayer2D = null


func _enter_tree() -> void:
	# Set authority based on the player's name (peer ID)
	# This MUST happen in _enter_tree() for MultiplayerSynchronizers to work
	var peer_id = name.to_int()
	set_multiplayer_authority(peer_id)
	print("Player ", name, " (peer ", peer_id, ") authority set in _enter_tree()")


func _ready() -> void:
	var peer_id = name.to_int()
	print("Player ", name, " (peer ", peer_id, ") has authority: ", is_multiplayer_authority())
	print("Current multiplayer peer: ", multiplayer.get_unique_id())
	print("Is server: ", multiplayer.is_server())
	print("Player position: ", position)
	print("Player visible: ", visible)
	
	# Enable Y-sort for proper depth sorting
	# Characters with higher Y position (lower on screen) will render in front
	y_sort_enabled = true

	# Apply class modifiers if coming from lobby
	var selected_class := ""
	if has_meta("selected_class"):
		selected_class = str(get_meta("selected_class"))
	elif LobbyManager and LobbyManager.players.has(peer_id):
		selected_class = LobbyManager.players[peer_id].get("class", "archer")
	if selected_class != "":
		apply_class_modifiers(selected_class)

	# Apply weapon selection if coming from lobby
	if has_meta("selected_weapon"):
		equipped_weapon = get_meta("selected_weapon")
		print("Player ", name, " equipped weapon from metadata: ", equipped_weapon)
	elif LobbyManager and LobbyManager.players.has(peer_id):
		equipped_weapon = LobbyManager.players[peer_id].get("weapon", "bow")
		print("Player ", name, " equipped weapon from LobbyManager: ", equipped_weapon)
	else:
		print("Player ", name, " using default weapon: ", equipped_weapon)

	# Initialize weapon configuration
	initialize_weapon()

	# Add to players group so it can be found by other players
	add_to_group("players")

	# Initialize health bar, XP display, and stamina bar
	update_health_display()
	update_xp_display()
	update_stamina_display()

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

	# Connect level-up signal to show upgrade overlay
	level_up_ready.connect(_on_level_up_ready)

	# Set up bow release sound
	setup_bow_sound()


func _input(event: InputEvent) -> void:
	# Only handle input for the local player
	var peer_id = name.to_int()
	if peer_id != multiplayer.get_unique_id():
		return

	# Handle stats screen toggle
	if event.is_action_pressed("stats_toggle") and not event.is_echo():
		toggle_stats_screen()
		return

	# Handle chat input for the player whose peer ID matches the current multiplayer peer
	if event.is_action_pressed("chat_toggle") and not event.is_echo():
		print("Player ", name, " (peer ", peer_id, ") handling chat input")
		var chat_ui = get_node("ChatUI")
		if chat_ui:
			# Add a small delay to prevent double processing
			await get_tree().process_frame
			chat_ui.toggle_chat()
		else:
			print("ERROR: ChatUI not found for player ", name)
		return

	# Handle fire animation on left mouse click
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			# Already checked peer_id at top of function
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

	# Check for Shift key (running)
	var wants_to_run = Input.is_key_pressed(KEY_SHIFT)

	# Determine if player can run (has stamina and is trying to run)
	if wants_to_run and direction != Vector2.ZERO and current_stamina > 0:
		is_running = true
		current_speed = run_speed * class_speed_modifier
		# Drain stamina while running
		current_stamina -= stamina_drain_rate * _delta
		if current_stamina < 0:
			current_stamina = 0
	else:
		is_running = false
		current_speed = walk_speed * class_speed_modifier
		# Regenerate stamina when not running
		if current_stamina < max_stamina:
			current_stamina += stamina_regen_rate * _delta
			if current_stamina > max_stamina:
				current_stamina = max_stamina

	# Update stamina display
	update_stamina_display()

	# Debug input detection (removed spam)
	#if direction != Vector2.ZERO:
	#print("Player ", name, " input detected: ", direction)

	velocity = direction * current_speed
	move_and_slide()
	
	# Update z_index based on Y position for proper depth sorting
	z_index = int(global_position.y)

	# Update animation based on movement
	update_animation(direction)


func _on_chat_message_received(player_name: String, message: String) -> void:
	print("Player ", name, " received chat message from ", player_name, ": ", message)

	# Check if this message is from this specific player
	var is_message_from_this_player = player_name == name or player_name == str(name.to_int())

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

			# Play bow release sound immediately when firing starts
			play_bow_sound(self)

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
			# Rapid fire limit reached, wait for cooldown (use upgraded fire_cooldown)
			can_fire = false
			await get_tree().create_timer(weapon_stats.fire_cooldown).timeout
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
	print("Network spawn request from peer: ", shooter_peer_id)

	# Find the shooter player
	var shooter = null
	for player in get_tree().get_nodes_in_group("players"):
		if player.name.to_int() == shooter_peer_id:
			shooter = player
			break

	if shooter:
		print("Found shooter player: ", shooter.name, " with weapon: ", shooter.equipped_weapon)
		# Play weapon sound for remote clients when projectile spawns
		play_weapon_sound(shooter)
		spawn_arrow_for_player(shooter, target_pos)
	else:
		print("ERROR: Could not find shooter player with peer_id: ", shooter_peer_id)


func spawn_arrow_for_player(shooter: Node2D, target_pos: Vector2) -> void:
	# Calculate direction from shooter to target
	var animated_sprite = shooter.get_node("AnimatedSprite2D")
	var sprite_position = (
		animated_sprite.global_position if animated_sprite else shooter.global_position
	)
	var direction_to_target = (target_pos - sprite_position).normalized()

	# Use the new spawn_arrow function which handles multishot and weapon_stats
	shooter.spawn_arrow(direction_to_target)


func update_animation(direction: Vector2) -> void:
	if not is_multiplayer_authority():
		return

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


func update_stamina_display() -> void:
	# Update the stamina bar display
	var stamina_bar = get_node_or_null("StaminaBar")
	if stamina_bar:
		stamina_bar.update_stamina(current_stamina, max_stamina)


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


# Heal player (used by lifesteal and other effects)
func heal(amount: int) -> void:
	# Cap health at maximum
	current_health = min(current_health + amount, max_health)
	print("Player ", name, " healed ", amount, " HP. Health: ", current_health, "/", max_health)

	# Broadcast health update to all clients
	rpc("sync_player_health", current_health)

	# Update health bar
	update_health_display()


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
	print(
		"gain_xp_rpc called for player ",
		name,
		", is_multiplayer_authority: ",
		is_multiplayer_authority()
	)
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

	# Level up bonuses (baseline automatic increases)
	max_health += 10
	current_health = max_health  # Full heal on level up
	attack_damage += 5  # Increase attack damage by 5 per level

	print("Player ", name, " leveled up to level ", current_level, "!")
	print("New max health: ", max_health)
	print("New attack damage: ", attack_damage)

	# Update health bar
	update_health_display()

	# Emit signal for upgrade system (only for local player)
	if is_multiplayer_authority():
		level_up_ready.emit()

	# Sync level up to all clients
	rpc("sync_level_up", current_level, max_health, current_xp, xp_to_next_level, attack_damage)


@rpc("any_peer", "reliable", "call_local")
func sync_xp(xp: int, level: int, xp_needed: int) -> void:
	print("sync_xp RPC received for player ", name, ": ", xp, "/", xp_needed, " level ", level)
	current_xp = xp
	current_level = level
	xp_to_next_level = xp_needed
	update_xp_display()
	print(
		"Synced XP for player ",
		name,
		": ",
		current_xp,
		"/",
		xp_to_next_level,
		" (Level ",
		current_level,
		")"
	)


@rpc("any_peer", "reliable", "call_local")
func sync_level_up(
	level: int, new_max_health: int, xp: int, xp_needed: int, new_attack_damage: int
) -> void:
	current_level = level
	max_health = new_max_health
	current_health = max_health
	current_xp = xp
	xp_to_next_level = xp_needed
	attack_damage = new_attack_damage
	update_health_display()
	update_xp_display()
	print(
		"Synced level up for player ",
		name,
		": Level ",
		current_level,
		", Health: ",
		max_health,
		", Attack Damage: ",
		attack_damage
	)


# Apply upgrade when selected from upgrade menu
func apply_upgrade(upgrade_id: String) -> void:
	# Increment stack count
	if not upgrade_stacks.has(upgrade_id):
		upgrade_stacks[upgrade_id] = 0
	upgrade_stacks[upgrade_id] += 1

	var stack_count = upgrade_stacks[upgrade_id]
	print("Applying upgrade: ", upgrade_id, " (stack ", stack_count, ")")

	# Apply upgrade effects
	match upgrade_id:
		"fire_rate":
			# 15% faster fire rate (multiplicative)
			weapon_stats.fire_cooldown *= 0.85
			print("Fire cooldown: ", weapon_stats.fire_cooldown)

		"damage_boost":
			# +20% damage (multiplicative stacking)
			weapon_stats.damage_multiplier += 0.2
			print("Damage multiplier: ", weapon_stats.damage_multiplier)

		"pierce":
			# +1 pierce per stack
			weapon_stats.pierce_count += 1
			print("Pierce count: ", weapon_stats.pierce_count)

		"multishot":
			# +1 arrow per shot
			weapon_stats.multishot_count += 1
			print("Multishot count: ", weapon_stats.multishot_count)

		"crit_chance":
			# +15% crit chance per stack (cap at 95%)
			weapon_stats.crit_chance = min(0.95, weapon_stats.crit_chance + 0.15)
			print("Crit chance: ", weapon_stats.crit_chance * 100, "%")

		"explosive_arrows":
			# +10% explosion chance per stack (cap at 100%)
			weapon_stats.explosion_chance = min(1.0, weapon_stats.explosion_chance + 0.1)
			weapon_stats.explosion_damage = attack_damage * 0.75  # 75% of arrow damage
			print("Explosion chance: ", weapon_stats.explosion_chance * 100, "%")

		"arrow_speed":
			# +25% arrow speed (multiplicative)
			weapon_stats.arrow_speed *= 1.25
			print("Arrow speed: ", weapon_stats.arrow_speed)

		"lifesteal":
			# +2 HP per enemy hit
			weapon_stats.lifesteal += 2
			print("Lifesteal: ", weapon_stats.lifesteal, " HP")

		"rapid_fire_capacity":
			# Modify max_rapid_fire constant through instance variable
			# Note: We'll need to track this separately since max_rapid_fire is const
			print("Rapid fire capacity increased")
			# TODO: Implement once we refactor rapid fire system

		"poison_arrows":
			# Enable poison effect
			weapon_stats.poison_damage = 3
			weapon_stats.poison_duration = 3.0
			print("Poison arrows enabled: ", weapon_stats.poison_damage, " damage/sec")

		"homing":
			# +0.1 homing strength per stack (0.0 to 0.5 reasonable range)
			weapon_stats.homing_strength = min(0.5, weapon_stats.homing_strength + 0.1)
			print("Homing strength: ", weapon_stats.homing_strength)

		"arrow_nova":
			# Add arrow nova ability
			if not "arrow_nova" in active_abilities:
				active_abilities.append("arrow_nova")
				setup_arrow_nova()
				print("Arrow Nova ability unlocked!")

		"summon_archer":
			# Add summon archer ability
			if not "summon_archer" in active_abilities:
				active_abilities.append("summon_archer")
				print("Summon Archer ability unlocked!")
				# TODO: Implement archer summoning

		"damage_shield":
			# Add damage shield ability
			if not "damage_shield" in active_abilities:
				active_abilities.append("damage_shield")
				print("Damage Shield ability unlocked! Press E to activate.")
				# TODO: Implement shield ability

		"xp_magnet":
			# Increase XP collection and gain
			# TODO: Implement XP magnet area increase
			# TODO: Implement XP multiplier
			print("XP Magnet upgraded!")

		_:
			print("Unknown upgrade: ", upgrade_id)

	# TODO: Play upgrade select sound effect
	# TODO: Spawn visual effect


# Setup arrow nova timer
func setup_arrow_nova() -> void:
	var nova_timer = Timer.new()
	nova_timer.name = "ArrowNovaTimer"
	nova_timer.wait_time = 10.0  # Fire every 10 seconds
	nova_timer.timeout.connect(_on_arrow_nova_timeout)
	add_child(nova_timer)
	nova_timer.start()


func _on_arrow_nova_timeout() -> void:
	# Fire 8 arrows in all directions
	print("Arrow Nova activated!")
	for i in range(8):
		var angle = (PI * 2 / 8) * i
		var direction = Vector2(cos(angle), sin(angle))
		spawn_arrow(direction)


# Called when player levels up and is ready for upgrade selection
func _on_level_up_ready() -> void:
	print("Player ", name, " ready for upgrade selection!")

	# Load and instantiate upgrade overlay
	var overlay_scene = load("res://coop/scenes/upgrade_overlay.tscn")
	if not overlay_scene:
		print("ERROR: Could not load upgrade overlay scene!")
		return

	var overlay = overlay_scene.instantiate()

	# Add to scene tree (as child of root, not player, so it doesn't move)
	get_tree().root.add_child(overlay)

	# Show upgrades for this player
	overlay.show_upgrades(self)

	print("Upgrade overlay shown for player ", name)


# Toggle stats screen display
func toggle_stats_screen() -> void:
	# Check if stats screen is already open
	var existing_stats = get_tree().root.get_node_or_null("StatsScreen")
	if existing_stats:
		# Already open, close it
		existing_stats.close_stats()
		return

	# Load and instantiate stats screen
	var stats_scene = load("res://coop/scenes/stats_screen.tscn")
	if not stats_scene:
		print("ERROR: Could not load stats screen scene!")
		return

	var stats_screen = stats_scene.instantiate()
	stats_screen.name = "StatsScreen"

	# Add to scene tree
	get_tree().root.add_child(stats_screen)

	# Show stats for this player
	stats_screen.show_stats(self)

	print("Stats screen shown for player ", name)


# Spawn projectile(s) in given direction with current weapon_stats
func spawn_projectile(direction: Vector2) -> void:
	# Ensure weapon is initialized (safety check for multiplayer)
	if not current_weapon_config:
		print("WARNING: Weapon not initialized for player ", name, ", initializing now...")
		initialize_weapon()

	if not current_weapon_config:
		print("ERROR: Failed to initialize weapon for player ", name, "! equipped_weapon=", equipped_weapon)
		return

	# Use preloaded scenes for network compatibility
	var projectile_scene = null
	match equipped_weapon:
		"bow":
			projectile_scene = ARROW_SCENE
		"rocket":
			projectile_scene = ROCKET_SCENE
		_:
			print("ERROR: Unknown weapon type: ", equipped_weapon)
			return

	if not projectile_scene:
		print("ERROR: Failed to get projectile scene for weapon: ", equipped_weapon)
		return

	print("Spawning projectile for weapon: ", equipped_weapon, " (player: ", name, ")")

	# Get spawn position (slightly ahead of player)
	var animated_sprite = get_node("AnimatedSprite2D")
	var sprite_position = animated_sprite.global_position if animated_sprite else global_position
	var spawn_offset = direction.normalized() * 30.0  # 30 pixels ahead
	var base_spawn_position = sprite_position + spawn_offset

	# Calculate final damage (base + flat + multiplier)
	var final_damage = (attack_damage + weapon_stats.damage) * weapon_stats.damage_multiplier
	print("=== PROJECTILE SPAWN DEBUG ===")
	print("Weapon: ", current_weapon_config.name)
	print("Player attack_damage: ", attack_damage)
	print("weapon_stats.damage: ", weapon_stats.damage)
	print("weapon_stats.damage_multiplier: ", weapon_stats.damage_multiplier)
	print("CALCULATED final_damage: ", final_damage)
	print("==============================")

	# Spawn projectiles based on multishot count
	var projectiles_to_spawn = weapon_stats.multishot_count
	var spread_angle_deg = 15.0  # degrees between projectiles

	for i in range(projectiles_to_spawn):
		var projectile = projectile_scene.instantiate()

		# Calculate spread for multishot (center projectile has 0 offset)
		var angle_offset_deg = (i - (projectiles_to_spawn - 1) / 2.0) * spread_angle_deg
		var angle_offset_rad = deg_to_rad(angle_offset_deg)
		var projectile_direction = direction.rotated(angle_offset_rad)

		# Calculate target position far away in the projectile direction
		var target_position = base_spawn_position + projectile_direction * 1000.0

		# Initialize projectile with stats
		projectile.damage = final_damage
		projectile.speed = weapon_stats.arrow_speed
		projectile.pierce_remaining = weapon_stats.pierce_count
		projectile.crit_chance = weapon_stats.crit_chance
		projectile.crit_multiplier = weapon_stats.crit_multiplier
		projectile.explosion_chance = weapon_stats.explosion_chance
		projectile.explosion_radius = weapon_stats.explosion_radius
		projectile.explosion_damage = (
			weapon_stats.explosion_damage
			if weapon_stats.explosion_damage > 0
			else final_damage * 0.75
		)
		projectile.lifesteal = weapon_stats.lifesteal
		projectile.poison_damage = weapon_stats.poison_damage
		projectile.poison_duration = weapon_stats.poison_duration
		projectile.homing_strength = weapon_stats.homing_strength
		projectile.direction = projectile_direction

		# Initialize with old method for compatibility
		projectile.initialize(self, base_spawn_position, target_position)

		# Set shooter metadata
		projectile.set_meta("shooter", self)

		# Add to scene
		get_tree().current_scene.add_child(projectile)


# Legacy function for backwards compatibility
func spawn_arrow(direction: Vector2) -> void:
	spawn_projectile(direction)


func get_attack_damage() -> int:
	return attack_damage


func initialize_weapon() -> void:
	print("Initializing weapon for player ", name, ": ", equipped_weapon)

	# Get weapon configuration
	current_weapon_config = WeaponData.get_weapon(equipped_weapon)

	if not current_weapon_config:
		print("ERROR: Failed to get weapon config for: ", equipped_weapon)
		return

	# Update base attack damage based on weapon
	attack_damage = int(current_weapon_config.base_damage)

	# Update weapon_stats with weapon-specific defaults
	weapon_stats.fire_cooldown = current_weapon_config.fire_cooldown
	weapon_stats.arrow_speed = current_weapon_config.projectile_speed
	weapon_stats.explosion_chance = current_weapon_config.base_explosion_chance
	weapon_stats.explosion_radius = current_weapon_config.base_explosion_radius
	weapon_stats.explosion_damage = current_weapon_config.base_explosion_damage

	print("Initialized weapon: ", current_weapon_config.name)
	print("  - Base damage: ", current_weapon_config.base_damage)
	print("  - Fire cooldown: ", current_weapon_config.fire_cooldown)
	print("  - Projectile speed: ", current_weapon_config.projectile_speed)

	# Setup weapon sound
	setup_weapon_sound()


func setup_weapon_sound() -> void:
	# Load the weapon sound based on current weapon
	if not current_weapon_config:
		return

	var weapon_sound = load(current_weapon_config.sound_path)
	if weapon_sound:
		# Create AudioStreamPlayer2D as a child of this player
		bow_sound_player = AudioStreamPlayer2D.new()
		bow_sound_player.name = "WeaponSoundPlayer"
		bow_sound_player.stream = weapon_sound
		add_child(bow_sound_player)
	else:
		print("ERROR: Failed to load weapon sound from ", current_weapon_config.sound_path)


func setup_bow_sound() -> void:
	# Deprecated: Use setup_weapon_sound() instead
	# Load the bow release sound
	var bow_sound = load("res://assets/Sounds/SFX/bow_release.mp3")
	if bow_sound:
		# Create AudioStreamPlayer2D as a child of this player
		bow_sound_player = AudioStreamPlayer2D.new()
		bow_sound_player.name = "BowSoundPlayer"
		bow_sound_player.stream = bow_sound
		add_child(bow_sound_player)
	else:
		print(
			"ERROR: Failed to load bow release sound from res://assets/Sounds/SFX/bow_release.mp3"
		)


func play_weapon_sound(shooter: Node2D) -> void:
	# Always create a new sound instance to allow overlapping sounds for rapid fire
	var temp_sound = AudioStreamPlayer2D.new()
	var weapon_sound = null

	# Try to use the cached sound from weapon sound player if available
	var shooter_sound = shooter.get_node_or_null("WeaponSoundPlayer")
	if not shooter_sound:
		# Fallback to legacy bow sound player
		shooter_sound = shooter.get_node_or_null("BowSoundPlayer")

	if shooter_sound and shooter_sound.stream:
		weapon_sound = shooter_sound.stream
	else:
		# Fallback: Load bow sound if not cached (for backwards compatibility)
		weapon_sound = load("res://assets/Sounds/SFX/bow_release.mp3")

	if weapon_sound:
		temp_sound.stream = weapon_sound
		temp_sound.position = shooter.global_position
		# Add to scene tree and play
		get_tree().current_scene.add_child(temp_sound)
		temp_sound.play()
		# Clean up after sound finishes
		temp_sound.finished.connect(func(): temp_sound.queue_free())
	else:
		print("ERROR: Failed to load weapon sound for player ", shooter.name)


# Legacy function for backwards compatibility
func play_bow_sound(shooter: Node2D) -> void:
	play_weapon_sound(shooter)


# Apply class modifiers from lobby selection
func apply_class_modifiers(selected_class: String) -> void:
	var class_data = PlayerClass.get_class_by_name(selected_class)

	print("Applying class modifiers for ", class_data["name"])

	# Apply health modifier
	max_health = int(max_health * class_data["health_modifier"])
	current_health = max_health

	# Apply damage modifier
	attack_damage = int(attack_damage * class_data["damage_modifier"])

	# Apply speed modifiers
	class_speed_modifier = class_data["speed_modifier"]

	# Apply attack speed modifier to fire cooldown
	weapon_stats.fire_cooldown = fire_cooldown * (1.0 / class_data["attack_speed_modifier"])

	# Load and apply character sprite frames
	var animated_sprite = get_node_or_null("AnimatedSprite2D")
	if animated_sprite and class_data.has("sprite_frames_path"):
		var sprite_frames = load(class_data["sprite_frames_path"])
		if sprite_frames:
			animated_sprite.sprite_frames = sprite_frames
			print("  Loaded sprite frames from: ", class_data["sprite_frames_path"])
			# Restart current animation with new sprite frames
			if animated_sprite.is_playing():
				var current_anim = animated_sprite.animation
				animated_sprite.play(current_anim)
		else:
			print("  ERROR: Failed to load sprite frames from: ", class_data["sprite_frames_path"])
	
	# Apply color tint to sprite (if you want to tint on top of the sprite)
	if animated_sprite:
		animated_sprite.modulate = class_data["color_tint"]

	print("Class modifiers applied:")
	print("  Health: ", max_health)
	print("  Damage: ", attack_damage)
	print("  Speed modifier: ", class_data["speed_modifier"])
	print("  Fire cooldown: ", weapon_stats.fire_cooldown)

	# Update displays
	update_health_display()
	update_xp_display()
