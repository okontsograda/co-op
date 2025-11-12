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
@export var attack_damage: int  # Base arrow damage (editable in Inspector)

# Player state
var is_alive: bool = true  # Track if player is alive for enemy targeting
var is_downed: bool = false  # Track if player is downed (can be revived)
var player_name: String = "Player"  # Player's name loaded from save system
var combat_enabled: bool = true  # Can be disabled in hub or safe zones

# Revive system
const REVIVE_RADIUS: float = 80.0  # Distance required to revive
const REVIVE_TIME: float = 5.0  # Time in seconds to revive
const REVIVE_HP_PERCENT: float = 0.25  # HP restored when revived (25%)
var revive_timer: float = 0.0  # Time remaining before permanent death
var revive_progress: float = 0.0  # Current revive progress (0.0 to REVIVE_TIME)
var reviving_player: Node2D = null  # Player currently reviving this player
var revive_request_cooldowns: Dictionary = {}  # Cooldown per downed player to prevent spam RPC calls
const REVIVE_REQUEST_COOLDOWN_TIME: float = 0.5  # Only send revive request every 0.5 seconds
var revive_timer_sync_cooldown: float = 0.0  # Cooldown for syncing timer to reduce network traffic
const REVIVE_TIMER_SYNC_INTERVAL: float = 0.2  # Sync timer every 0.2 seconds

# Currency System
var coins: int = 0  # Currency collected by the player

# Consumables System
var consumable_slots: Dictionary = {
	1: {"item_id": "", "quantity": 0},  # Slot 1 (key "1")
	2: {"item_id": "", "quantity": 0}   # Slot 2 (key "2")
}
var consumable_cooldown: float = 0.0  # Cooldown to prevent spam
const CONSUMABLE_COOLDOWN_DURATION: float = 0.5  # 0.5 second cooldown between uses

var is_firing: bool = false
var can_fire: bool = true
var is_fire_button_held: bool = false  # Track if fire button is held
var fire_timer: float = 0.0  # Timer for automatic fire when holding
const fire_cooldown: float = 1.0  # Cooldown time between shots (1 shot per second max)

# Dodge/Evade System
var is_dodging: bool = false  # Currently performing a dodge roll
var dodge_invincible: bool = false  # Invincibility frames during dodge
var can_dodge: bool = true  # Dodge cooldown
var dodge_direction: Vector2 = Vector2.ZERO  # Direction of dodge roll
const dodge_duration: float = 0.25  # How long the dodge roll lasts
const dodge_distance: float = 120.0  # How far the dodge roll travels
const dodge_cooldown: float = 1.8  # Cooldown between dodges
const dodge_iframe_duration: float = 0.25  # Duration of invincibility frames (only during roll)
const dodge_stamina_cost: float = 35.0  # Stamina cost to perform a dodge

# Weapon System
var equipped_weapon: String = "bow"  # Default to bow, can be set from lobby
var current_weapon_config: WeaponData.WeaponConfig = null

# Combat System
var combat_type: String = "ranged"  # "ranged" or "melee"
var melee_attack_range: float = 60.0  # Range for melee attacks

# Combo System (for melee knight)
var last_attack_time: float = 0.0  # When the last attack was initiated
var combo_count: int = 0  # Current combo count (0, 1, 2...)
const combo_window: float = 0.8  # Time window to continue combo (seconds)
var is_performing_combo: bool = false  # Currently performing combo dash
const combo_dash_distance: float = 150.0  # How far to dash during combo
const combo_dash_duration: float = 1.0  # Duration of combo dash (increased for visibility)
var combo_cooldown_ready: bool = true  # Whether combo attack is off cooldown
var combo_cooldown_time: float = 0.0  # Current cooldown remaining
const combo_cooldown_duration: float = 5.0  # Cooldown time for combo attack

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

# RPC Security - Rate limiting and validation
var rpc_rate_limits: Dictionary = {}  # Track RPC calls per peer: {peer_id: {rpc_name: last_call_time}}
const RPC_MIN_INTERVAL: float = 0.05  # Minimum 50ms between same RPC from same peer
const ATTACK_RPC_MIN_INTERVAL: float = 0.1  # Minimum 100ms between attack RPCs (anti-spam)
var last_melee_attack_time: float = 0.0  # Track last melee attack for validation
var last_dash_strike_time: float = 0.0  # Track last dash strike for validation
var last_projectile_spawn_time: float = 0.0  # Track last projectile spawn for validation

# Multiplayer synchronization (configured in scene file player.tscn)
# No additional variables needed - MultiplayerSynchronizer handles everything

# Upgrade tracking - how many times each upgrade has been taken
var upgrade_stacks = {}

# Active abilities (arrow nova, summon archer, shield, etc.)
var active_abilities = []

# Sound effects
var bow_sound_player: AudioStreamPlayer2D = null
var owning_peer_id: int = 0


func _determine_peer_id() -> int:
	if has_meta("peer_id"):
		return int(get_meta("peer_id"))

	var node_name := str(name)
	if node_name.is_valid_int():
		return node_name.to_int()

	return multiplayer.get_unique_id()


func _enter_tree() -> void:
	# Set authority based on the owning peer ID (provided by MultiplayerSpawner)
	owning_peer_id = _determine_peer_id()
	set_multiplayer_authority(owning_peer_id)
	set_meta("peer_id", owning_peer_id)
	print("Player ", name, " (peer ", owning_peer_id, ") authority set in _enter_tree()")
	print("  - Local peer ID: ", multiplayer.get_unique_id())
	print("  - Is authority after set: ", is_multiplayer_authority())


func _ready() -> void:
	var peer_id = owning_peer_id if owning_peer_id != 0 else _determine_peer_id()

	# Load player name from save system (only for local player)
	if is_multiplayer_authority():
		_load_player_name()

	# Enable Y-sort for proper depth sorting
	# Characters with higher Y position (lower on screen) will render in front
	y_sort_enabled = true

	# Apply weapon selection if coming from lobby (do this BEFORE class modifiers)
	if has_meta("selected_weapon"):
		equipped_weapon = get_meta("selected_weapon")
	elif LobbyManager and LobbyManager.players.has(peer_id):
		equipped_weapon = LobbyManager.players[peer_id].get("weapon", "bow")

	# Apply class modifiers if coming from lobby (this will override weapon for melee classes)
	var selected_class := ""
	if has_meta("selected_class"):
		selected_class = str(get_meta("selected_class"))
	elif LobbyManager and LobbyManager.players.has(peer_id):
		selected_class = LobbyManager.players[peer_id].get("class", "archer")
	if selected_class != "":
		apply_class_modifiers(selected_class)

	# Initialize weapon configuration
	initialize_weapon()

	# Add to players group so it can be found by other players
	add_to_group("players")

	# Configure MultiplayerSynchronizer for efficient network sync
	# NOTE: MultiplayerSynchronizer is configured in the scene file (player.tscn)
	# We just need to ensure authority is set correctly (done in _enter_tree)

	# Set up the MultiplayerSynchronizer authority (should match player authority)
	var pos_sync = get_node_or_null("MultiplayerSynchronizer")
	if pos_sync:
		pos_sync.set_multiplayer_authority(peer_id)
		print("Player ", name, " MultiplayerSynchronizer authority set to ", peer_id)
		print("  - Replication config: ", pos_sync.replication_config)
		print("  - Root path: ", pos_sync.root_path)

	# Set up the AnimatedSpriteSynchronizer authority
	var anim_sync = get_node_or_null("AnimatedSpriteSynchronizer")
	if anim_sync:
		anim_sync.set_multiplayer_authority(peer_id)
		print("Player ", name, " AnimatedSpriteSynchronizer authority set to ", peer_id)

	# Log spawn position
	print("Player ", name, " spawned at global_position: ", global_position, " (is_authority: ", is_multiplayer_authority(), ")")

	# Initialize health bar, XP display, stamina bar, coin display, wave display, combo UI, and consumables
	# Initialize interpolation position
	# server_position = global_position

	update_health_display()
	update_xp_display()
	update_stamina_display()
	setup_coin_display()
	setup_wave_display()
	setup_combo_ui()
	setup_consumables_display()

	# Set up camera to follow this player if this is the local player
	setup_camera()

	# Connect to network handler for receiving chat messages
	if NetworkHandler:
		NetworkHandler.chat_message_received.connect(_on_chat_message_received)

	# Connect to TeamXP signals
	TeamXP.level_up_ready.connect(_on_team_level_up)
	TeamXP.xp_changed.connect(_on_team_xp_changed)

	# Set up bow release sound
	setup_bow_sound()

	# Initialize health tracking with GameDirector (server only)
	if multiplayer.is_server():
		# Wait a frame for everything to be fully initialized
		await get_tree().process_frame
		var player_peer_id = name.to_int()
		GameDirector.update_player_health(player_peer_id, current_health, max_health)


## Enable or disable combat (used in hub/safe zones)
func set_combat_enabled(enabled: bool) -> void:
	combat_enabled = enabled
	if not enabled:
		# Reset combat state when disabling
		is_fire_button_held = false
		is_firing = false
		is_dodging = false
		print("[Player] Combat disabled for player %s" % name)
	else:
		print("[Player] Combat enabled for player %s" % name)


func _input(event: InputEvent) -> void:
	# Only handle input for the local player
	var peer_id = name.to_int()
	if peer_id != multiplayer.get_unique_id():
		return

	# Don't handle input if player is dead or downed
	if current_health <= 0 or is_downed:
		return

	# Handle dodge roll (Spacebar only, not Enter) - only if combat enabled
	if combat_enabled and event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_SPACE:
			if can_dodge and not is_dodging:
				perform_dodge_roll()
			return

	# Handle stats screen toggle
	if event.is_action_pressed("stats_toggle") and not event.is_echo():
		toggle_stats_screen()
		return

	# Handle chat input (Enter key or chat_toggle action)
	var should_toggle_chat = false
	if event is InputEventKey and event.pressed and not event.is_echo():
		# Enter key opens/closes chat
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			should_toggle_chat = true
	elif event.is_action_pressed("chat_toggle") and not event.is_echo():
		should_toggle_chat = true

	if should_toggle_chat:
		print("Player ", name, " (peer ", peer_id, ") handling chat input")
		var chat_ui = get_node("ChatUI")
		if chat_ui:
			# Add a small delay to prevent double processing
			await get_tree().process_frame
			chat_ui.toggle_chat()
		else:
			print("ERROR: ChatUI not found for player ", name)
		return

	# Handle consumable usage (1 and 2 keys) - only if combat enabled
	if combat_enabled and event is InputEventKey and event.pressed and not event.is_echo():
		# Check if UI is blocking (don't use consumables while in shop/menus)
		if not is_ui_blocking_combat():
			if event.keycode == KEY_1:
				use_consumable(1)
				return
			elif event.keycode == KEY_2:
				use_consumable(2)
				return

	# Handle fire button state (left mouse button) - only if combat enabled
	if combat_enabled and event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			# Check if any UI is blocking combat
			if is_ui_blocking_combat():
				is_fire_button_held = false
				return

			is_fire_button_held = mouse_event.pressed
			if mouse_event.pressed:
				# Fire immediately on button press
				handle_fire_action(mouse_event.position)


func _physics_process(_delta: float) -> void:
	# Remote players (non-authority): Don't process locally, MultiplayerSynchronizer handles it
	if !is_multiplayer_authority():
		# MultiplayerSynchronizer automatically updates global_position from server
		# We only need to update z_index for proper depth sorting
		z_index = int(global_position.y)
		return

	# Handle spectator camera if player is dead (not downed and not alive)
	if current_health <= 0 and not is_downed and not is_alive:
		update_spectator_camera()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Handle downed state
	if is_downed:
		handle_downed_state(_delta)
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Check for revive interactions (only for alive players)
	if is_alive and current_health > 0:
		check_revive_interactions(_delta)

	# Check if chat is active - if so, don't process movement or combat
	var chat_ui = get_node("ChatUI")
	if chat_ui and chat_ui.is_chat_active:
		# Chat is active, don't process movement or combat
		is_fire_button_held = false  # Reset fire button when chat is active
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Check if any UI is blocking movement (shop blocks movement, upgrade overlay doesn't)
	if is_ui_blocking_movement():
		is_fire_button_held = false  # Reset fire button when UI is active
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Check if UI is blocking combat (both shop and upgrade overlay block combat)
	if is_ui_blocking_combat():
		is_fire_button_held = false  # Reset fire button when UI is active
		# Don't return here - allow movement to continue

	# Handle combo dash (takes priority over normal movement and ALL blocking)
	if is_performing_combo:
		# During combo dash, movement is handled by perform_dash_combo
		# Just update z_index
		# IGNORE all UI/shop blocking during combo - nothing stops the combo!
		z_index = int(global_position.y)
		return

	# Handle dodge roll movement
	if is_dodging:
		# During dodge, move in dodge direction at high speed
		var dodge_speed = dodge_distance / dodge_duration
		velocity = dodge_direction * dodge_speed
		move_and_slide()
		# Update z_index even while dodging
		z_index = int(global_position.y)
		return

	# Handle automatic firing when fire button is held
	if is_fire_button_held and can_fire:
		fire_timer += _delta
		# Fire automatically based on fire_cooldown
		if fire_timer >= weapon_stats.fire_cooldown:
			fire_timer = 0.0
			var mouse_pos = get_viewport().get_mouse_position()
			handle_fire_action(mouse_pos)

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

	# Update combo cooldown
	if not combo_cooldown_ready and combo_cooldown_time > 0:
		combo_cooldown_time -= _delta
		if combo_cooldown_time <= 0:
			combo_cooldown_time = 0
			combo_cooldown_ready = true
		update_combo_ui()

	# Update consumable cooldown
	if consumable_cooldown > 0:
		consumable_cooldown -= _delta
		if consumable_cooldown < 0:
			consumable_cooldown = 0

	# Debug input detection (removed spam)
	#if direction != Vector2.ZERO:
	#print("Player ", name, " input detected: ", direction)

	velocity = direction * current_speed
	# Store old position for debugging
	var old_pos = global_position

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


func is_ui_blocking_combat() -> bool:
	# Check if shop UI is open
	var shop_ui = get_tree().root.get_node_or_null("ShopUI")
	if shop_ui and shop_ui.visible:
		return true

	# Check if upgrade overlay is open
	var upgrade_overlay = get_tree().root.get_node_or_null("UpgradeOverlay")
	if upgrade_overlay and upgrade_overlay.visible:
		return true

	# Check for any CanvasLayer with ShopUI or UpgradeOverlay
	for node in get_tree().get_nodes_in_group("ui"):
		if node is CanvasLayer and node.visible:
			if "ShopUI" in node.name or "UpgradeOverlay" in node.name:
				return true

	return false


func is_ui_blocking_movement() -> bool:
	# Only shop UI blocks movement, upgrade overlay allows movement
	var shop_ui = get_tree().root.get_node_or_null("ShopUI")
	if shop_ui and shop_ui.visible:
		return true

	# Check for any CanvasLayer with ShopUI (but NOT UpgradeOverlay)
	for node in get_tree().get_nodes_in_group("ui"):
		if node is CanvasLayer and node.visible:
			if "ShopUI" in node.name:
				return true

	return false


func handle_fire_action(_mouse_position: Vector2) -> void:
	# Don't fire while dodging
	if is_dodging:
		return

	# For melee combat, check if this could be a combo attack
	if combat_type == "melee":
		var current_time = Time.get_ticks_msec() / 1000.0
		var time_since_last_attack = current_time - last_attack_time

		# Allow click if:
		# 1. Can fire normally, OR
		# 2. Within combo window (for combo chaining)
		if can_fire or (time_since_last_attack <= combo_window and combo_count > 0):
			handle_melee_attack(_mouse_position)
		return

	# Ranged weapons require cooldown to be ready
	if not can_fire:
		return

	# Ranged weapons use cooldown system
	handle_ranged_attack(_mouse_position)


func handle_ranged_attack(_mouse_position: Vector2) -> void:
	# Trigger the fire animation
	var animated_sprite = get_node("AnimatedSprite2D")
	if animated_sprite:
		# Set cooldown immediately - can't fire again until cooldown expires
		can_fire = false
		fire_timer = 0.0  # Reset fire timer

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
			await get_tree().create_timer(0.3).timeout
			# Spawn visual-only projectile locally for instant feedback
			spawn_projectile_visual(world_target)

			# Request server to spawn authoritative projectile
			request_projectile_spawn(world_target)

		# After remaining animation time, return to normal animation
		await get_tree().create_timer(0.3).timeout
		is_firing = false

		# Wait for cooldown before allowing next shot (use upgraded fire_cooldown)
		await get_tree().create_timer(weapon_stats.fire_cooldown).timeout
		can_fire = true
	else:
		print("ERROR: AnimatedSprite2D not found!")


func handle_melee_attack(_mouse_position: Vector2) -> void:
	# Don't attack if already performing combo dash
	if is_performing_combo:
		return

	# Trigger the melee attack animation
	var animated_sprite = get_node("AnimatedSprite2D")
	if animated_sprite:
		# Convert mouse position to world coordinates
		var camera = get_viewport().get_camera_2d()
		if camera:
			var world_target = camera.get_global_mouse_position()
			var direction_to_target = (world_target - global_position).normalized()

			# Check if this is a combo attack (within combo window)
			var current_time = Time.get_ticks_msec() / 1000.0
			var time_since_last_attack = current_time - last_attack_time

			if time_since_last_attack <= combo_window and combo_count > 0 and not can_fire:
				# This is a combo click during the first attack!
				combo_count += 1
				print("Combo attack #", combo_count)

				# Update last attack time
				last_attack_time = current_time

				# Check if combo cooldown is ready
				if combo_count >= 2 and combo_cooldown_ready:
					print("DASH COMBO ACTIVATED!")

					# Stop current animation and reset state
					is_firing = false

					# Start combo cooldown
					combo_cooldown_ready = false
					combo_cooldown_time = combo_cooldown_duration
					update_combo_ui()

					# Start dash combo
					perform_dash_combo(world_target, direction_to_target)
					return
				elif combo_count >= 2 and not combo_cooldown_ready:
					print("Combo attack on cooldown! ", combo_cooldown_time, "s remaining")
					# Reset combo since it failed
					combo_count = 0
					return
			elif time_since_last_attack <= combo_window and combo_count > 0:
				# Continue combo on a completed attack
				combo_count += 1
				print("Combo attack #", combo_count)
			else:
				# Start new combo chain
				combo_count = 1
				print("Starting new combo chain")

			last_attack_time = current_time

			# Check if we should trigger dash combo (2 consecutive attacks when cooldown ready)
			if combo_count >= 2 and combat_type == "melee" and can_fire:
				if combo_cooldown_ready:
					print("DASH COMBO ACTIVATED!")

					# Start combo cooldown
					combo_cooldown_ready = false
					combo_cooldown_time = combo_cooldown_duration
					update_combo_ui()

					perform_dash_combo(world_target, direction_to_target)
					return
				else:
					print("Combo attack on cooldown! ", combo_cooldown_time, "s remaining")
					# Reset combo since it failed
					combo_count = 0

			# Set cooldown for normal attack
			can_fire = false

			# Turn player to face the attack direction
			if direction_to_target.x > 0:
				animated_sprite.flip_h = false  # Face right
			elif direction_to_target.x < 0:
				animated_sprite.flip_h = true  # Face left

			# Play attack animation - check which animation exists
			is_firing = true
			var sprite_frames = animated_sprite.sprite_frames

			if sprite_frames and sprite_frames.has_animation("attack"):
				# Make sure attack animation doesn't loop
				sprite_frames.set_animation_loop("attack", false)
				animated_sprite.play("attack")
			elif sprite_frames and sprite_frames.has_animation("fire"):
				# Make sure fire animation doesn't loop for melee
				sprite_frames.set_animation_loop("fire", false)
				animated_sprite.play("fire")
			else:
				print("WARNING: No attack or fire animation found!")

			# Play attack sound
			play_weapon_sound(self)

			# Wait for animation to reach attack point (about halfway through)
			await get_tree().create_timer(0.3).timeout

			# Request server to perform hit detection and damage
			# Server is authoritative for all combat
			request_melee_attack(world_target)

		# Wait for the animation to actually finish
		if animated_sprite:
			# Wait until animation finishes or timeout
			var max_wait = 1.0
			var elapsed = 0.0
			while animated_sprite.is_playing() and elapsed < max_wait:
				await get_tree().create_timer(0.1).timeout
				elapsed += 0.1

		is_firing = false

		# Force return to idle animation immediately
		if animated_sprite and animated_sprite.sprite_frames:
			var sprite_frames = animated_sprite.sprite_frames
			if sprite_frames.has_animation("idle"):
				sprite_frames.set_animation_loop("idle", true)
				animated_sprite.play("idle")

		# Wait for cooldown before allowing next attack (0.6 seconds for faster combat)
		await get_tree().create_timer(0.6).timeout
		can_fire = true
	else:
		print("ERROR: AnimatedSprite2D not found!")


func perform_dash_combo(world_target: Vector2, dash_direction: Vector2) -> void:
	# Perform a dash forward with multiple strikes
	is_performing_combo = true
	is_firing = true
	var animated_sprite = get_node("AnimatedSprite2D")

	if animated_sprite:
		# Turn player to face the dash direction
		if dash_direction.x > 0:
			animated_sprite.flip_h = false  # Face right
		elif dash_direction.x < 0:
			animated_sprite.flip_h = true  # Face left

		# Set up attack animation properties (will be played manually for each strike)
		var sprite_frames = animated_sprite.sprite_frames
		if sprite_frames:
			if sprite_frames.has_animation("attack"):
				sprite_frames.set_animation_loop("attack", false)  # Don't loop, we control it
			if sprite_frames.has_animation("fire"):
				sprite_frames.set_animation_loop("fire", false)  # Don't loop, we control it

		# Visual feedback - add dash trail effect
		animated_sprite.modulate = Color(1.5, 1.5, 1.8)  # Slight blue tint for dash

	# Store original position for dash
	var start_pos = global_position
	var target_pos = start_pos + (dash_direction * combo_dash_distance)

	# Dash forward quickly
	var start_time = Time.get_ticks_msec() / 1000.0  # Get current time in seconds
	var dash_timer = 0.0
	var strikes_performed = 0
	var strike_interval = combo_dash_duration / 3  # 3 strikes during dash (0.333s each)

	print("Starting dash combo from ", start_pos, " to ", target_pos)
	print("Strike interval: ", strike_interval, " seconds")
	print("Start time: ", start_time)

	# Perform dash with multiple strikes
	var loop_iterations = 0
	while is_performing_combo:
		loop_iterations += 1
		# Use real time instead of delta accumulation
		var current_time = Time.get_ticks_msec() / 1000.0
		dash_timer = current_time - start_time

		# Exit when duration is complete
		if dash_timer > combo_dash_duration:
			print("Dash duration complete, exiting loop")
			break

		# Interpolate position during dash
		var progress = min(dash_timer / combo_dash_duration, 1.0)
		global_position = start_pos.lerp(target_pos, progress)

		# Debug: log every 10th iteration
		if loop_iterations % 30 == 0:
			print("Loop running... timer: ", dash_timer, "/", combo_dash_duration, " strikes: ", strikes_performed)

		# Perform strikes at intervals during dash
		# Check if it's time for the next strike (haven't done this strike number yet)
		var current_strike_number = int(dash_timer / strike_interval) + 1
		if current_strike_number > strikes_performed and strikes_performed < 3:
			print("Triggering strike at dash_timer: ", dash_timer, " strike number: ", current_strike_number)
			strikes_performed = current_strike_number
			print("Dash strike #", strikes_performed)

			# Alternate animation direction for each strike
			if animated_sprite:
				var sprite_frames = animated_sprite.sprite_frames
				var anim_name = "attack" if sprite_frames and sprite_frames.has_animation("attack") else "fire"

				print("Animation setup - anim_name: ", anim_name, " is_playing: ", animated_sprite.is_playing())

				if strikes_performed == 1:
					# First strike: play forward from start
					animated_sprite.speed_scale = 1.5
					animated_sprite.play(anim_name)
					animated_sprite.frame = 0  # Set frame AFTER play
					print("Strike 1: Forward - speed 1.5, frame 0")
				elif strikes_performed == 2:
					# Second strike: play in reverse from end
					if sprite_frames:
						var frame_count = sprite_frames.get_frame_count(anim_name)
						animated_sprite.speed_scale = -1.5
						animated_sprite.play(anim_name)  # MUST call play() to restart animation
						animated_sprite.frame = frame_count - 1  # Jump to end
						print("Strike 2: Reverse - speed -1.5, frame ", frame_count - 1)
				elif strikes_performed == 3:
					# Third strike: play forward from start
					animated_sprite.speed_scale = 1.5
					animated_sprite.play(anim_name)  # MUST call play() to restart animation
					animated_sprite.frame = 0  # Jump back to start
					print("Strike 3: Forward - speed 1.5, frame 0")

			# Play attack sound
			play_weapon_sound(self)
			print("Sound played for strike #", strikes_performed)

			# Request server to perform dash strike damage
			var strike_range = melee_attack_range * 1.2  # 20% wider range during dash
			request_dash_strike(world_target, strike_range)

		await get_tree().process_frame

	print("Loop exited. Final dash_timer: ", dash_timer, " loop_iterations: ", loop_iterations)
	print("is_performing_combo: ", is_performing_combo)

	# Ensure we end at target position
	global_position = target_pos

	print("Combo complete! Total strikes performed: ", strikes_performed)

	# Reset visual effects and animation
	if animated_sprite:
		animated_sprite.modulate = Color(1.0, 1.0, 1.0)

		# Reset animation speed to normal
		animated_sprite.speed_scale = 1.0

		# Stop looping attack animation and return to idle
		var sprite_frames = animated_sprite.sprite_frames
		if sprite_frames:
			if sprite_frames.has_animation("attack"):
				sprite_frames.set_animation_loop("attack", false)
			if sprite_frames.has_animation("fire"):
				sprite_frames.set_animation_loop("fire", false)
			if sprite_frames.has_animation("idle"):
				sprite_frames.set_animation_loop("idle", true)
				animated_sprite.play("idle")

	# Reset combo after successful dash
	combo_count = 0
	is_firing = false
	is_performing_combo = false

	# Cooldown after combo before next normal attack
	await get_tree().create_timer(0.3).timeout
	can_fire = true

	print("Dash combo complete!")


## Client requests dash strike from server
func request_dash_strike(target_pos: Vector2, strike_range: float) -> void:
	# If we're the server, call directly instead of RPC
	if multiplayer.is_server():
		process_dash_strike_on_server(global_position, target_pos, strike_range)
	else:
		# Send dash strike request to server
		rpc_id(1, "process_dash_strike_on_server", global_position, target_pos, strike_range)

## Server processes dash strike (authoritative)
@rpc("any_peer", "reliable")
func process_dash_strike_on_server(attacker_pos: Vector2, target_pos: Vector2, strike_range: float) -> void:
	if not multiplayer.is_server():
		return

	# Get attacker
	var attacker_peer_id = multiplayer.get_remote_sender_id()
	# If called directly (not via RPC), use the caller's unique ID
	if attacker_peer_id == 0:
		attacker_peer_id = multiplayer.get_unique_id()

	# SECURITY: Rate limiting - prevent dash strike spam
	if not validate_rpc_rate_limit(attacker_peer_id, "process_dash_strike_on_server", ATTACK_RPC_MIN_INTERVAL):
		return

	# SECURITY: Validate vector bounds
	if not validate_vector_bounds(attacker_pos) or not validate_vector_bounds(target_pos):
		return

	# SECURITY: Validate strike range
	if not validate_float_bounds(strike_range, 0.0, 500.0):  # Max 500 pixels range
		return

	var attacker = null
	for player in get_tree().get_nodes_in_group("players"):
		if player.name.to_int() == attacker_peer_id:
			attacker = player
			break

	if not attacker or not is_instance_valid(attacker):
		return

	# SECURITY: Validate attacker position is near actual player position
	var distance_from_real_pos = attacker_pos.distance_to(attacker.global_position)
	if distance_from_real_pos > 150.0:  # Max 150 pixels (dash moves player)
		push_warning("Dash strike position too far from actual player position: ", distance_from_real_pos)
		return

	# SECURITY: Validate dash strike cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last_dash = current_time - attacker.last_dash_strike_time
	if time_since_last_dash < attacker.combo_cooldown_duration:  # Respect combo cooldown
		push_warning("Dash strike cooldown violation from peer ", attacker_peer_id)
		return

	# Update last dash strike time
	attacker.last_dash_strike_time = current_time

	# Server does hit detection
	var attack_direction = (target_pos - attacker_pos).normalized()
	var enemies = get_tree().get_nodes_in_group("enemies")

	# Calculate final damage (boosted for combo)
	var final_damage = (attacker.attack_damage + attacker.weapon_stats.damage) * attacker.weapon_stats.damage_multiplier * 1.15

	# Check for critical hit
	var is_crit = randf() < attacker.weapon_stats.crit_chance
	if is_crit:
		final_damage *= attacker.weapon_stats.crit_multiplier

	const KNOCKBACK_FORCE = 150.0

	var hits = []

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# Server validates hit
		var distance = attacker_pos.distance_to(enemy.global_position)
		if distance > strike_range:
			continue

		var direction_to_enemy = (enemy.global_position - attacker_pos).normalized()
		var dot_product = attack_direction.dot(direction_to_enemy)

		# Wider cone for dash strike
		var in_attack_direction = "whirlwind" in attacker.active_abilities or dot_product > 0.15

		if in_attack_direction:
			# Server applies damage
			if enemy.has_method("take_damage"):
				enemy.take_damage(int(final_damage), attacker)

				# Apply knockback
				if enemy.has_method("apply_knockback"):
					var knockback_direction = direction_to_enemy
					var knockback_velocity = knockback_direction * KNOCKBACK_FORCE
					enemy.apply_knockback(knockback_velocity)

			# Apply lifesteal
			if attacker.weapon_stats.lifesteal > 0:
				attacker.heal(attacker.weapon_stats.lifesteal)

			# Track damage
			if GameStats:
				GameStats.record_damage_dealt(int(final_damage))

			# Record hit for VFX
			hits.append({
				"enemy_name": enemy.name,
				"position": enemy.global_position,
				"damage": int(final_damage),
				"is_crit": is_crit
			})

	# Broadcast hits to all clients for VFX via VFXManager
	if hits.size() > 0:
		for hit in hits:
			VFXManager.spawn_damage_number.rpc(hit.position, hit.damage, hit.is_crit)


## DEPRECATED: Old client-authoritative network RPC
## No longer used - replaced by server-authoritative process_dash_strike_on_server
@rpc("any_peer", "reliable")
func perform_dash_strike_network(target_pos: Vector2, strike_range: float) -> void:
	push_warning("perform_dash_strike_network is deprecated - combat is now server-authoritative")


## ============================================================================
## RPC SECURITY VALIDATION HELPERS
## ============================================================================

## Validate RPC call is not being spammed (rate limiting)
func validate_rpc_rate_limit(peer_id: int, rpc_name: String, min_interval: float = RPC_MIN_INTERVAL) -> bool:
	var current_time = Time.get_ticks_msec() / 1000.0

	# Initialize peer tracking if needed
	if not rpc_rate_limits.has(peer_id):
		rpc_rate_limits[peer_id] = {}

	# Check if this RPC was called too recently
	if rpc_rate_limits[peer_id].has(rpc_name):
		var time_since_last_call = current_time - rpc_rate_limits[peer_id][rpc_name]
		if time_since_last_call < min_interval:
			push_warning("RPC rate limit exceeded for ", rpc_name, " from peer ", peer_id,
				" (", time_since_last_call, "s since last call, min: ", min_interval, "s)")
			return false

	# Update last call time
	rpc_rate_limits[peer_id][rpc_name] = current_time
	return true


## Validate RPC caller has server authority
func validate_rpc_authority(peer_id: int, rpc_name: String) -> bool:
	# Authority RPCs must come from server (peer 1)
	if peer_id != 1 and not multiplayer.is_server():
		push_warning("Unauthorized RPC call: ", rpc_name, " from non-server peer ", peer_id)
		return false
	return true


## Validate vector is within reasonable bounds (prevent exploit values)
func validate_vector_bounds(vec: Vector2, max_magnitude: float = 10000.0) -> bool:
	if vec.length_squared() > max_magnitude * max_magnitude:
		push_warning("Vector exceeds maximum bounds: ", vec)
		return false
	return true


## Validate float is within reasonable bounds
func validate_float_bounds(value: float, min_val: float = -10000.0, max_val: float = 10000.0) -> bool:
	if value < min_val or value > max_val or is_nan(value) or is_inf(value):
		push_warning("Float value out of bounds or invalid: ", value)
		return false
	return true


## ============================================================================
## MULTIPLAYER SYNCHRONIZATION
## ============================================================================
## NOTE: MultiplayerSynchronizer configuration is now in the scene file (player.tscn)
## This provides better visibility and prevents conflicts between scene and code configs


## ============================================================================
## CLIENT REQUEST FUNCTIONS
## ============================================================================

## Client requests melee attack from server
func request_melee_attack(target_pos: Vector2) -> void:
	# If we're the server, call directly instead of RPC
	if multiplayer.is_server():
		process_melee_attack_on_server(global_position, target_pos)
	else:
		# Send attack request to server with attacker's position and target
		rpc_id(1, "process_melee_attack_on_server", global_position, target_pos)

## Server processes melee attack (authoritative hit detection)
@rpc("any_peer", "reliable")
func process_melee_attack_on_server(attacker_pos: Vector2, target_pos: Vector2) -> void:
	if not multiplayer.is_server():
		return

	# Get attacker peer ID and find their player
	var attacker_peer_id = multiplayer.get_remote_sender_id()
	# If called directly (not via RPC), use the caller's unique ID
	if attacker_peer_id == 0:
		attacker_peer_id = multiplayer.get_unique_id()

	# SECURITY: Rate limiting - prevent attack spam
	if not validate_rpc_rate_limit(attacker_peer_id, "process_melee_attack_on_server", ATTACK_RPC_MIN_INTERVAL):
		return

	# SECURITY: Validate vector bounds
	if not validate_vector_bounds(attacker_pos) or not validate_vector_bounds(target_pos):
		return

	var attacker = null
	for player in get_tree().get_nodes_in_group("players"):
		if player.name.to_int() == attacker_peer_id:
			attacker = player
			break

	if not attacker or not is_instance_valid(attacker):
		return

	# SECURITY: Validate attacker position is near actual player position (anti-cheat)
	var distance_from_real_pos = attacker_pos.distance_to(attacker.global_position)
	if distance_from_real_pos > 100.0:  # Max 100 pixels deviation
		push_warning("Melee attack position too far from actual player position: ", distance_from_real_pos)
		return

	# SECURITY: Validate attack cooldown (prevent faster-than-allowed attacks)
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last_attack = current_time - attacker.last_melee_attack_time
	if time_since_last_attack < 0.3:  # Minimum 300ms between melee attacks
		push_warning("Melee attack cooldown violation from peer ", attacker_peer_id)
		return

	# Update last attack time
	attacker.last_melee_attack_time = current_time

	# Server does hit detection
	var attack_direction = (target_pos - attacker_pos).normalized()
	var enemies = get_tree().get_nodes_in_group("enemies")

	# Calculate final damage (using attacker's stats)
	var final_damage = (attacker.attack_damage + attacker.weapon_stats.damage) * attacker.weapon_stats.damage_multiplier

	# Check for critical hit
	var is_crit = randf() < attacker.weapon_stats.crit_chance
	if is_crit:
		final_damage *= attacker.weapon_stats.crit_multiplier

	const KNOCKBACK_FORCE = 200.0

	var hits = []  # Track hits for broadcasting

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# Server validates hit (range and cone check)
		var distance = attacker_pos.distance_to(enemy.global_position)
		if distance > attacker.melee_attack_range:
			continue

		var direction_to_enemy = (enemy.global_position - attacker_pos).normalized()
		var dot_product = attack_direction.dot(direction_to_enemy)

		# Whirlwind or cone check
		var in_attack_direction = "whirlwind" in attacker.active_abilities or dot_product > 0.3

		if in_attack_direction:
			# Server applies damage (enemy.take_damage validates authority)
			if enemy.has_method("take_damage"):
				enemy.take_damage(int(final_damage), attacker)

				# Apply knockback
				if enemy.has_method("apply_knockback"):
					var knockback_direction = direction_to_enemy
					var knockback_velocity = knockback_direction * KNOCKBACK_FORCE
					enemy.apply_knockback(knockback_velocity)

			# Apply lifesteal (server-authoritative healing)
			if attacker.weapon_stats.lifesteal > 0:
				attacker.heal(attacker.weapon_stats.lifesteal)

			# Track damage on server
			if GameStats:
				GameStats.record_damage_dealt(int(final_damage))

			# Record hit for VFX broadcast
			hits.append({
				"enemy_name": enemy.name,
				"position": enemy.global_position,
				"damage": int(final_damage),
				"is_crit": is_crit
			})

	# Broadcast hits to all clients for VFX via VFXManager
	if hits.size() > 0:
		for hit in hits:
			VFXManager.spawn_damage_number.rpc(hit.position, hit.damage, hit.is_crit)


## DEPRECATED: Old client-authoritative network RPC
## No longer used - replaced by server-authoritative process_melee_attack_on_server
@rpc("any_peer", "reliable")
func perform_melee_damage_network(target_pos: Vector2) -> void:
	push_warning("perform_melee_damage_network is deprecated - combat is now server-authoritative")


## DEPRECATED: Old client-authoritative projectile spawning
## Use spawn_projectile_on_server() instead (server-authoritative)
@rpc("any_peer", "reliable")
func spawn_arrow_network(target_pos: Vector2) -> void:
	push_warning("DEPRECATED: spawn_arrow_network() called - this is the old client-authoritative system")
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
		# Play weapon sound for remote clients when projectile spawns
		play_weapon_sound(shooter)
		spawn_arrow_for_player(shooter, target_pos)


## DEPRECATED: Helper for old client-authoritative system
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

	var sprite_frames = animated_sprite.sprite_frames
	if not sprite_frames:
		return

	# Determine which animation to play based on movement
	if direction != Vector2.ZERO:
		# Player is moving - play walk animation
		if animated_sprite.animation != "walk":
			# Make sure walk animation loops
			if sprite_frames.has_animation("walk"):
				sprite_frames.set_animation_loop("walk", true)
			animated_sprite.play("walk")

		# Flip sprite based on horizontal direction
		if direction.x < 0:
			animated_sprite.flip_h = true
		elif direction.x > 0:
			animated_sprite.flip_h = false
	else:
		# Player is stationary - play idle animation
		if animated_sprite.animation != "idle":
			# Make sure idle animation loops
			if sprite_frames.has_animation("idle"):
				sprite_frames.set_animation_loop("idle", true)
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
			scene_camera.enabled = true
			print("Attached camera to player ", name)
		else:
			# Create a new camera if none exists
			var camera = Camera2D.new()
			camera.limit_left = -2000
			camera.limit_top = -2000
			camera.limit_right = 2000
			camera.limit_bottom = 2000
			camera.zoom = Vector2(0.5, 0.5)  # Zoom in to 50% (2x closer)
			camera.enabled = true
			add_child(camera)
			print("Created camera for player ", name)


func update_health_display() -> void:
	# Update the health bar display
	var health_bar = get_node_or_null("HealthBar")
	if health_bar:
		health_bar.update_health(current_health, max_health)


func update_xp_display() -> void:
	# Update the XP bar with team XP
	var xp_bar = get_node_or_null("XPBar")
	if xp_bar:
		xp_bar.update_xp(TeamXP.get_team_xp(), TeamXP.get_xp_to_next_level())

	# Update the level label with team level
	var level_label = get_node_or_null("LevelLabel")
	if level_label:
		level_label.text = "Lv." + str(TeamXP.get_team_level())


func update_stamina_display() -> void:
	# Update the stamina bar display
	var stamina_bar = get_node_or_null("StaminaBar")
	if stamina_bar:
		stamina_bar.update_stamina(current_stamina, max_stamina)


func update_combo_ui() -> void:
	# Update the combo attack UI display (now in root, not child of player)
	var combo_ui = get_tree().root.get_node_or_null("ComboAttackUI")
	if combo_ui and combo_ui.has_method("update_cooldown"):
		combo_ui.update_cooldown(combo_cooldown_ready, combo_cooldown_time, combo_cooldown_duration)


func setup_combo_ui() -> void:
	# Create combo UI if it doesn't exist (only for local player and only for melee)
	var peer_id = name.to_int()
	if peer_id == multiplayer.get_unique_id() and combat_type == "melee":
		# Check if UI already exists in the scene tree (not as child of player)
		var existing_ui = get_tree().root.get_node_or_null("ComboAttackUI")
		if not existing_ui:
			var combo_ui_scene = load("res://coop/scenes/combo_attack_ui.tscn")
			if combo_ui_scene:
				var combo_ui = combo_ui_scene.instantiate()
				combo_ui.name = "ComboAttackUI"
				# Add to root instead of player so it doesn't move with player
				get_tree().root.add_child(combo_ui)
				# Initialize the display
				update_combo_ui()
			else:
				print("WARNING: Could not load combo_attack_ui.tscn")

	# Hide combo UI for ranged classes
	if combat_type != "melee":
		var combo_ui = get_tree().root.get_node_or_null("ComboAttackUI")
		if combo_ui:
			combo_ui.queue_free()


## Server-authoritative damage system
## External callers (enemies, projectiles) should call this
func take_damage(amount: int, attacker: Node2D) -> void:
	# Only server can apply damage to players
	if not multiplayer.is_server():
		push_warning("Client attempted to call take_damage - damage must be server-authoritative")
		return

	# Server checks dodge status
	if dodge_invincible:
		# Notify all clients damage was evaded (for VFX)
		rpc("on_damage_evaded")
		print("Player ", name, " evaded attack!")
		return

	# Server applies damage
	var old_health = current_health
	current_health -= amount
	current_health = max(0, current_health)  # Clamp to 0

	# Track damage on server
	if GameStats:
		GameStats.record_damage_taken(amount)

	# Update GameDirector (server only)
	var peer_id = name.to_int()
	GameDirector.update_player_health(peer_id, current_health, max_health)

	# Broadcast damage to all clients (including victim)
	var attacker_name = str(attacker.name) if attacker else "unknown"
	rpc("apply_damage_from_server", amount, current_health, attacker_name)

	# Check for death on server
	if current_health <= 0:
		handle_death_on_server(attacker_name)

## Server-only death handling
func handle_death_on_server(attacker_name: String) -> void:
	if not multiplayer.is_server():
		return

	# Broadcast death to all clients
	rpc("handle_death_rpc")
	rpc("on_player_died", attacker_name)

## Client receives damage from server (authoritative)
@rpc("authority", "reliable", "call_local")
func apply_damage_from_server(amount: int, new_health: int, attacker_name: String) -> void:
	# SECURITY: Verify this RPC came from server
	var sender_id = multiplayer.get_remote_sender_id()
	if not validate_rpc_authority(sender_id, "apply_damage_from_server"):
		return

	# Update local health to match server
	current_health = new_health

	# Update health bar
	update_health_display()

	# Play damage VFX/sounds locally
	# (damage feedback code would go here)

## Client receives evade notification
@rpc("authority", "reliable", "call_local")
func on_damage_evaded() -> void:
	# SECURITY: Verify this RPC came from server
	var sender_id = multiplayer.get_remote_sender_id()
	if not validate_rpc_authority(sender_id, "on_damage_evaded"):
		return

	spawn_evade_text()
	print("Player ", name, " evaded attack!")


func perform_dodge_roll() -> void:
	# Don't dodge if already dodging, performing combo, or if dead
	if is_dodging or is_performing_combo or current_health <= 0:
		return

	# Check if player has enough stamina
	if current_stamina < dodge_stamina_cost:
		print("Player ", name, " not enough stamina to dodge (", current_stamina, "/", dodge_stamina_cost, ")")
		return

	# Consume stamina
	current_stamina -= dodge_stamina_cost
	if current_stamina < 0:
		current_stamina = 0
	update_stamina_display()

	# Determine dodge direction based on movement input or facing direction
	var direction = Vector2()

	# Check for WASD keys for dodge direction
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1

	# If no direction input, dodge away from mouse (backwards)
	if direction == Vector2.ZERO:
		var camera = get_viewport().get_camera_2d()
		if camera:
			var mouse_pos = camera.get_global_mouse_position()
			direction = (global_position - mouse_pos).normalized()
		else:
			# Fallback: dodge downward
			direction = Vector2(0, 1)
	else:
		direction = direction.normalized()

	# Start dodge roll
	is_dodging = true
	dodge_invincible = true
	can_dodge = false
	dodge_direction = direction

	# Visual feedback - make player semi-transparent during dodge
	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.modulate.a = 0.5  # 50% opacity

	# Broadcast dodge to all clients for visual sync
	rpc("sync_dodge_visual", true)

	print("Player ", name, " dodge rolling in direction: ", direction)

	# End dodge roll after duration
	await get_tree().create_timer(dodge_duration).timeout
	is_dodging = false
	dodge_invincible = false  # End invincibility when dodge ends

	# Restore visual appearance
	if sprite:
		sprite.modulate.a = 1.0  # Full opacity
	rpc("sync_dodge_visual", false)

	# Start cooldown before next dodge
	await get_tree().create_timer(dodge_cooldown).timeout
	can_dodge = true
	print("Player ", name, " can dodge again")


@rpc("any_peer", "reliable", "call_local")
func sync_dodge_visual(is_dodging_state: bool) -> void:
	# Sync dodge visual effect across all clients
	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.modulate.a = 0.5 if is_dodging_state else 1.0


func spawn_evade_text() -> void:
	# Spawn "EVADED!" text visual effect using damage number system
	var damage_scene = load("res://coop/scenes/damage_number.tscn")
	if damage_scene:
		var evade_instance = damage_scene.instantiate()
		evade_instance.global_position = global_position + Vector2(0, -30)

		# Add to scene FIRST
		get_tree().current_scene.add_child(evade_instance)

		# Set as evade text (special styling)
		if evade_instance.has_method("set_evade_text"):
			evade_instance.set_evade_text()
		else:
			# Fallback: use damage text with 0 damage
			if evade_instance.has_method("set_damage"):
				evade_instance.set_damage(0, false, true)  # Pass true for "is_evade"


## DEPRECATED: Use apply_damage_from_server or apply_healing_from_server instead
## This RPC is now server-authoritative only
@rpc("authority", "reliable", "call_local")
func sync_player_health(health: int) -> void:
	# Only server can broadcast health changes
	# Clients receive this RPC from server, not send it
	current_health = health

	# Update GameDirector with health change (server only)
	if multiplayer.is_server():
		var peer_id = name.to_int()
		GameDirector.update_player_health(peer_id, current_health, max_health)

	update_health_display()


## Server-authoritative healing
## External callers (lifesteal, pickups) should call this
func heal(amount: int) -> void:
	# Only server can apply healing
	if not multiplayer.is_server():
		push_warning("Client attempted to call heal - healing must be server-authoritative")
		return

	# Server applies healing
	var old_health = current_health
	current_health = min(current_health + amount, max_health)

	# Update GameDirector (server only)
	var peer_id = name.to_int()
	GameDirector.update_player_health(peer_id, current_health, max_health)

	# Broadcast healing to all clients
	rpc("apply_healing_from_server", amount, current_health)

## Client receives healing from server (authoritative)
@rpc("authority", "reliable", "call_local")
func apply_healing_from_server(amount: int, new_health: int) -> void:
	# SECURITY: Verify this RPC came from server
	var sender_id = multiplayer.get_remote_sender_id()
	if not validate_rpc_authority(sender_id, "apply_healing_from_server"):
		return

	# Update local health to match server
	current_health = new_health

	# Update health bar
	update_health_display()

	# Play heal VFX/sounds locally
	# (healing feedback code would go here)


# Collect coin (called when player picks up a coin)
func collect_coin(amount: int) -> void:
	coins += amount

	# Track coins collected
	if GameStats:
		GameStats.record_coin_collected(amount)

	# Play coin pickup sound
	play_pickup_sound()

	# Broadcast coin update to all clients
	rpc("sync_player_coins", coins)

	# Update UI if you have a coin display
	update_coin_display()


@rpc("any_peer", "reliable", "call_local")
func sync_player_coins(total_coins: int) -> void:
	# Sync coins across all clients
	coins = total_coins
	update_coin_display()


func setup_coin_display() -> void:
	# Create coin display if it doesn't exist (only for local player)
	var peer_id = name.to_int()
	if peer_id == multiplayer.get_unique_id() and not get_node_or_null("CoinDisplay"):
		var coin_display_scene = load("res://coop/scenes/coin_display.tscn")
		if coin_display_scene:
			var coin_display = coin_display_scene.instantiate()
			coin_display.name = "CoinDisplay"
			add_child(coin_display)

	# Initialize the display
	update_coin_display()


func setup_wave_display() -> void:
	# Create wave display if it doesn't exist (only for local player)
	var peer_id = name.to_int()
	if peer_id == multiplayer.get_unique_id() and not get_node_or_null("WaveDisplay"):
		var wave_display_scene = load("res://coop/scenes/wave_display.tscn")
		if wave_display_scene:
			var wave_display = wave_display_scene.instantiate()
			wave_display.name = "WaveDisplay"
			add_child(wave_display)


func update_coin_display() -> void:
	# Update the coin display UI
	var coin_display = get_node_or_null("CoinDisplay")
	if coin_display and coin_display.has_method("update_coins"):
		coin_display.update_coins(coins)


# ============================================================================
# CONSUMABLES SYSTEM
# ============================================================================

func setup_consumables_display() -> void:
	# Create consumables display if it doesn't exist (only for local player)
	var peer_id = name.to_int()
	if peer_id == multiplayer.get_unique_id() and not get_node_or_null("ConsumablesDisplay"):
		var consumables_display_scene = load("res://coop/scenes/consumables_display.tscn")
		if consumables_display_scene:
			var consumables_display = consumables_display_scene.instantiate()
			consumables_display.name = "ConsumablesDisplay"
			add_child(consumables_display)
			print("Consumables display created for player ", name)

	# Initialize the display
	update_consumables_display()


func update_consumables_display() -> void:
	# Update the consumables display UI
	var consumables_display = get_node_or_null("ConsumablesDisplay")
	if consumables_display:
		for slot_num in [1, 2]:
			var slot = consumable_slots[slot_num]
			consumables_display.set_slot(slot_num, slot["item_id"], slot["quantity"])


func add_consumable_to_slot(slot_number: int, item_id: String, quantity: int = 1) -> void:
	# Add consumable to the specified slot
	if slot_number not in [1, 2]:
		push_error("Invalid consumable slot: " + str(slot_number))
		return

	var slot = consumable_slots[slot_number]

	# If slot is empty or has a different item, replace it
	if slot["item_id"] == "" or slot["item_id"] == item_id:
		slot["item_id"] = item_id
		slot["quantity"] += quantity
		print("Added ", quantity, " x ", item_id, " to slot ", slot_number, " (total: ", slot["quantity"], ")")
	else:
		# Slot has a different item, find an empty slot or replace slot 2
		var other_slot = 2 if slot_number == 1 else 1
		if consumable_slots[other_slot]["item_id"] == "" or consumable_slots[other_slot]["item_id"] == item_id:
			add_consumable_to_slot(other_slot, item_id, quantity)
			return
		else:
			# Both slots full with different items, replace the current slot
			slot["item_id"] = item_id
			slot["quantity"] = quantity
			print("Replaced slot ", slot_number, " with ", quantity, " x ", item_id)

	update_consumables_display()


func use_consumable(slot_number: int) -> void:
	# Check if on cooldown
	if consumable_cooldown > 0:
		print("Consumable on cooldown: ", consumable_cooldown, "s remaining")
		return

	# Check if valid slot
	if slot_number not in [1, 2]:
		return

	var slot = consumable_slots[slot_number]

	# Check if slot has items
	if slot["item_id"] == "" or slot["quantity"] <= 0:
		print("Consumable slot ", slot_number, " is empty")
		return

	# Get item data
	var item = ShopManager.get_item(slot["item_id"])
	if not item:
		push_error("Consumable item not found: " + slot["item_id"])
		return

	# Check if we're at full health (for healing items)
	if item.stat_bonuses.has("instant_heal"):
		if current_health >= max_health:
			print("Already at full health")
			return

	# Request server to use consumable (server-authoritative)
	if multiplayer.is_server():
		_server_use_consumable(slot_number, slot["item_id"])
	else:
		rpc_id(1, "_server_use_consumable", slot_number, slot["item_id"])


@rpc("any_peer", "reliable", "call_remote")
func _server_use_consumable(slot_number: int, item_id: String) -> void:
	# SECURITY: Verify sender is the player who owns this character
	var sender_id = multiplayer.get_remote_sender_id()
	var peer_id = name.to_int()
	if sender_id != peer_id and sender_id != 0:  # Allow server (0) or owning player
		push_error("Player " + str(sender_id) + " attempted to use consumable for player " + str(peer_id))
		return

	# Verify slot has the item
	var slot = consumable_slots[slot_number]
	if slot["item_id"] != item_id or slot["quantity"] <= 0:
		push_error("Consumable verification failed for player " + str(peer_id))
		return

	# Get item data
	var item = ShopManager.get_item(item_id)
	if not item:
		push_error("Consumable item not found: " + item_id)
		return

	# Apply consumable effect (server-side)
	if item.stat_bonuses.has("instant_heal"):
		var heal_amount = item.stat_bonuses.instant_heal
		# Cap at max health
		var actual_heal = min(heal_amount, max_health - current_health)
		if actual_heal > 0:
			heal(actual_heal)
			print("Player ", name, " healed for ", actual_heal, " HP using ", item.name)

	# Consume the item (reduce quantity)
	slot["quantity"] -= 1
	if slot["quantity"] <= 0:
		slot["quantity"] = 0
		slot["item_id"] = ""

	# Sync to all clients
	rpc("_sync_consumable_slot", slot_number, slot["item_id"], slot["quantity"])

	# Set cooldown
	consumable_cooldown = CONSUMABLE_COOLDOWN_DURATION
	rpc("_sync_consumable_cooldown", consumable_cooldown)


@rpc("authority", "reliable", "call_local")
func _sync_consumable_slot(slot_number: int, item_id: String, quantity: int) -> void:
	# SECURITY: Verify this RPC came from server
	var sender_id = multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() and sender_id != 1:
		push_error("Non-server attempted to sync consumable slot")
		return

	# Update local slot data
	if slot_number in [1, 2]:
		consumable_slots[slot_number]["item_id"] = item_id
		consumable_slots[slot_number]["quantity"] = quantity
		update_consumables_display()


@rpc("authority", "reliable", "call_local")
func _sync_consumable_cooldown(cooldown: float) -> void:
	# SECURITY: Verify this RPC came from server
	var sender_id = multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() and sender_id != 1:
		push_error("Non-server attempted to sync consumable cooldown")
		return

	consumable_cooldown = cooldown


@rpc("any_peer", "reliable")
func on_player_died(_killer: String) -> void:
	# Handle death (e.g., respawn, show death message, etc.)
	print("Player ", name, " died!")
	# You can add death effects here


@rpc("any_peer", "reliable", "call_local")
func handle_death_rpc() -> void:
	# This RPC is called on all clients when a player dies
	handle_death()


func handle_death() -> void:
	# Handle death on authority/server
	print("Player ", name, " has been downed!")

	# Check if there are any other alive players who could revive this player
	# If no other alive players exist, skip downed state and go straight to permanent death
	if not are_there_other_alive_players():
		print("Player ", name, " is the last player alive - skipping revive state")
		handle_permanent_death()
		return

	# Set downed state instead of immediate death
	is_downed = true
	is_alive = false  # Still mark as not alive for enemy targeting
	revive_timer = REVIVE_TIME
	revive_progress = 0.0
	reviving_player = null
	revive_timer_sync_cooldown = 0.0  # Reset sync cooldown

	# Broadcast downed state to all clients
	rpc("sync_downed_state", true, REVIVE_TIME)

	# Make sprite semi-transparent and slightly red to show downed state
	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite:
		print("[REVIVE] handle_death: Setting sprite visible for player ", name)
		sprite.modulate = Color(1.0, 0.5, 0.5, 0.7)  # Red tint, semi-transparent
		sprite.visible = true  # Keep visible so teammates can see them
		sprite.show()  # Force show to ensure visibility
	else:
		print("[REVIVE] ERROR: handle_death: AnimatedSprite2D not found for player ", name)

	# Hide UI elements on ALL clients (so other players don't see dead player's UI)
	hide_player_ui()

	# Disable collision so they don't block others
	set_collision_layer_value(1, false)  # Disable player collision layer
	set_collision_mask_value(1, false)  # Disable collision with other players

	# Stop movement
	velocity = Vector2.ZERO

	# Create revive UI indicator
	create_revive_indicator()

	# Start revive timeout timer
	if is_multiplayer_authority():
		start_revive_timeout()


func handle_permanent_death() -> void:
	# Actually die permanently (called after revive timeout)
	print("Player ", name, " has permanently died!")

	# Notify GameDirector of player death (server only)
	if multiplayer.is_server():
		var peer_id = name.to_int()
		GameDirector.on_player_death(peer_id)

	# Mark as permanently dead
	is_downed = false
	is_alive = false

	# Broadcast permanent death to all clients
	rpc("sync_downed_state", false, 0.0)

	# Hide the player sprite completely
	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.visible = false
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Reset color

	# Remove revive indicator
	remove_revive_indicator()

	# Check if ALL players are dead
	if is_multiplayer_authority() and are_all_players_dead():
		# Show game over to everyone
		rpc("show_game_over_screen_rpc")


func are_there_other_alive_players() -> bool:
	# Check if there are any OTHER alive players (excluding this player)
	# who could potentially revive this player
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if player == self:
			continue  # Skip ourselves
		if "is_alive" in player and player.is_alive:
			return true  # Found at least one other alive player
	return false  # No other alive players to revive this player


func are_all_players_dead() -> bool:
	# Check if all players in the game are dead (not downed, actually dead)
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if "is_alive" in player and player.is_alive:
			return false  # Found at least one alive player
		# Also check if downed (downed players are still "alive" for revive purposes)
		if "is_downed" in player and player.is_downed:
			return false  # Found at least one downed player (can be revived)
	return true  # All players are permanently dead


@rpc("any_peer", "reliable", "call_local")
func show_game_over_screen_rpc() -> void:
	# Sync stats from server to all clients before showing game over
	if multiplayer.is_server():
		# Server broadcasts its stats to all clients
		rpc("sync_stats_from_server",
			GameStats.total_enemies_killed,
			GameStats.total_coins_collected,
			GameStats.highest_wave_reached,
			GameStats.total_damage_dealt,
			GameStats.total_damage_taken,
			GameStats.bosses_killed
		)

	# Show game over screen to all players (called when everyone is dead)
	show_game_over_screen()


@rpc("any_peer", "reliable")
func sync_stats_from_server(enemies: int, total_coins: int, wave: int, damage_dealt: int, damage_taken: int, bosses: int) -> void:
	# Receive synced stats from server
	if GameStats:
		GameStats.sync_all_stats(enemies, total_coins, wave, damage_dealt, damage_taken, bosses)


func hide_player_ui() -> void:
	# Hide all UI elements when player becomes a spectator
	var health_bar = get_node_or_null("HealthBar")
	if health_bar:
		health_bar.visible = false

	var stamina_bar = get_node_or_null("StaminaBar")
	if stamina_bar:
		stamina_bar.visible = false

	var level_label = get_node_or_null("LevelLabel")
	if level_label:
		level_label.visible = false

	var xp_bar = get_node_or_null("XPBar")
	if xp_bar:
		xp_bar.visible = false

	var coin_display = get_node_or_null("CoinDisplay")
	if coin_display:
		coin_display.visible = false

	var wave_display = get_node_or_null("WaveDisplay")
	if wave_display:
		wave_display.visible = false

	var combo_ui = get_tree().root.get_node_or_null("ComboAttackUI")
	if combo_ui:
		combo_ui.visible = false

	# Hide stats screen if open
	var stats_screen = get_node_or_null("StatsScreen")
	if stats_screen:
		stats_screen.visible = false


func handle_downed_state(_delta: float) -> void:
	# Handle downed player state - countdown timer
	if is_multiplayer_authority():
		# If someone is actively reviving, pause the death timer
		var is_being_revived = reviving_player and is_instance_valid(reviving_player)

		if is_being_revived:
			# Check if reviving player is still in range
			var distance = global_position.distance_to(reviving_player.global_position)
			if distance <= REVIVE_RADIUS:
				# Someone is actively reviving in range - pause death timer and update progress
				revive_progress += _delta
				# Broadcast progress update (throttle to every 0.1 seconds to reduce network traffic)
				if int(revive_progress * 10) != int((revive_progress - _delta) * 10):
					rpc("sync_revive_progress", revive_progress)

				# Debug output every second
				if int(revive_progress) != int(revive_progress - _delta):
					print("[REVIVE] Progress: ", revive_progress, "/", REVIVE_TIME, " for player ", name, " (timer paused at ", revive_timer, "s)")

				# Check if revive is complete
				if revive_progress >= REVIVE_TIME:
					print("[REVIVE] Revive complete for player ", name)
					complete_revive()
					return
			else:
				# Reviving player moved out of range, cancel revive and resume timer
				print("[REVIVE] Reviver moved out of range (", distance, " > ", REVIVE_RADIUS, ")")
				cancel_revive()
				# Resume death timer countdown
				revive_timer -= _delta
		else:
			# No one is reviving, countdown timer normally
			revive_timer -= _delta
			# Reset progress if it was set
			if revive_progress > 0.0:
				revive_progress = 0.0
				rpc("sync_revive_progress", 0.0)

		# Sync timer to all clients periodically
		revive_timer_sync_cooldown -= _delta
		if revive_timer_sync_cooldown <= 0.0:
			rpc("sync_revive_timer", revive_timer)
			revive_timer_sync_cooldown = REVIVE_TIMER_SYNC_INTERVAL

		# Update revive indicator
		update_revive_indicator()

		# If timer expires (and no one is reviving), permanently die
		if revive_timer <= 0.0 and not is_being_revived:
			print("[REVIVE] Timer expired for player ", name, " - permanent death")
			handle_permanent_death()
			return
	else:
		# On non-authority clients, just update the indicator
		update_revive_indicator()


func check_revive_interactions(_delta: float) -> void:
	# Check if this alive player is near any downed players
	# Only check on authority to avoid duplicate RPC calls
	if not is_multiplayer_authority():
		return

	var players = get_tree().get_nodes_in_group("players")
	var downed_player_ids = []

	for player in players:
		if not is_instance_valid(player):
			continue

		# Skip self
		if player == self:
			continue

		# Check if player is downed
		if not ("is_downed" in player) or not player.is_downed:
			continue

		var player_id = player.name.to_int()
		downed_player_ids.append(player_id)

		# Update cooldown for this player
		if not revive_request_cooldowns.has(player_id):
			revive_request_cooldowns[player_id] = 0.0
		if revive_request_cooldowns[player_id] > 0.0:
			revive_request_cooldowns[player_id] -= _delta

		# Check distance
		var distance = global_position.distance_to(player.global_position)
		if distance <= REVIVE_RADIUS:
			# In range to revive - start/continue reviving
			# Only send revive request if cooldown is ready
			if revive_request_cooldowns[player_id] <= 0.0:
				start_revive(player)
				revive_request_cooldowns[player_id] = REVIVE_REQUEST_COOLDOWN_TIME
		else:
			# Out of range - stop reviving if we were
			# Only send stop request if cooldown is ready
			if revive_request_cooldowns[player_id] <= 0.0:
				stop_revive(player)
				revive_request_cooldowns[player_id] = REVIVE_REQUEST_COOLDOWN_TIME

	# Clean up cooldowns for players that are no longer downed
	for player_id in revive_request_cooldowns.keys():
		if player_id not in downed_player_ids:
			revive_request_cooldowns.erase(player_id)


func start_revive(downed_player: Node2D) -> void:
	# Start reviving a downed player
	# Send RPC to the downed player to start revive (they have authority over their state)
	if not is_multiplayer_authority():
		return

	var reviver_player_id = name.to_int()
	var distance = global_position.distance_to(downed_player.global_position)

	print("[REVIVE] start_revive called: ", name, " trying to revive ", downed_player.name, " (distance: ", distance, ")")

	# Call RPC on the downed player (will be processed by their authority)
	# Use rpc_id to send directly to the downed player's authority
	var downed_authority = downed_player.get_multiplayer_authority()
	if downed_authority > 0:
		downed_player.request_revive_start.rpc_id(downed_authority, reviver_player_id)
		print("[REVIVE] Sent RPC to player ", downed_player.name, " (authority: ", downed_authority, ", reviver: ", reviver_player_id, ")")
	else:
		print("[REVIVE] ERROR: Could not get authority for downed player ", downed_player.name)


func stop_revive(downed_player: Node2D) -> void:
	# Stop reviving a downed player
	# Send RPC to the downed player to stop revive
	if not is_multiplayer_authority():
		return

	# Call RPC on the downed player (will be processed by their authority)
	# Use rpc_id to send directly to the downed player's authority
	var downed_authority = downed_player.get_multiplayer_authority()
	if downed_authority > 0:
		downed_player.request_revive_stop.rpc_id(downed_authority)
		print("Player ", name, " stopped reviving player ", downed_player.name)


func cancel_revive() -> void:
	# Cancel revive (called when reviving player moves out of range)
	if reviving_player:
		var reviver_name = reviving_player.name
		reviving_player = null
		revive_progress = 0.0
		rpc("sync_revive_progress", 0.0)
		rpc("sync_revive_stop", name.to_int())
		print("Revive cancelled for player ", name, " (reviver: ", reviver_name, " moved away)")


func complete_revive() -> void:
	# Complete the revive process
	if not is_multiplayer_authority():
		return

	print("Player ", name, " has been revived!")

	# Restore health to 25% of max
	current_health = int(max_health * REVIVE_HP_PERCENT)

	# Reset downed state
	is_downed = false
	is_alive = true

	# Reset revive variables
	revive_timer = 0.0
	revive_progress = 0.0
	var reviver = reviving_player
	reviving_player = null

	# Restore sprite appearance
	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Reset color
		sprite.visible = true

	# Re-enable collision
	set_collision_layer_value(1, true)  # Enable player collision layer
	set_collision_mask_value(1, true)  # Enable collision with other players

	# Show UI elements again
	show_player_ui()

	# Update health display
	update_health_display()

	# Update GameDirector with health change (server only)
	if multiplayer.is_server():
		var peer_id = name.to_int()
		GameDirector.update_player_health(peer_id, current_health, max_health)

	# Broadcast revive completion
	rpc("sync_revive_complete", name.to_int(), current_health)

	# Remove revive indicator
	remove_revive_indicator()

	# Re-setup camera for local player (important after revival)
	var peer_id = name.to_int()
	if peer_id == multiplayer.get_unique_id():
		setup_camera()

	# Notify reviver
	if reviver and is_instance_valid(reviver):
		print("Player ", reviver.name, " successfully revived player ", name)


func start_revive_timeout() -> void:
	# Start the timer for permanent death if not revived
	# This is handled in handle_downed_state, but we can add a visual countdown here
	pass  # Timer is handled in handle_downed_state


func create_revive_indicator() -> void:
	# Create UI indicator for revive progress
	var existing_indicator = get_node_or_null("ReviveIndicator")
	if existing_indicator:
		return  # Already exists

	# Create a simple progress bar above the player
	var indicator = Control.new()
	indicator.name = "ReviveIndicator"
	indicator.position = Vector2(-50, -80)  # Above player
	indicator.size = Vector2(100, 20)

	# Background panel
	var bg = Panel.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.2, 0.2, 0.2, 0.8)
	indicator.add_child(bg)

	# Progress bar
	var progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	progress_bar.min_value = 0.0
	progress_bar.max_value = REVIVE_TIME
	progress_bar.value = 0.0
	progress_bar.show_percentage = false
	progress_bar.modulate = Color(0.2, 0.8, 0.2, 0.9)  # Green
	indicator.add_child(progress_bar)

	# Timer label
	var timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	timer_label.text = "DOWNED"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 12)
	timer_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	indicator.add_child(timer_label)

	add_child(indicator)


func update_revive_indicator() -> void:
	# Update the revive indicator UI
	var indicator = get_node_or_null("ReviveIndicator")
	if not indicator:
		return

	var progress_bar = indicator.get_node_or_null("ProgressBar")
	var timer_label = indicator.get_node_or_null("TimerLabel")

	if progress_bar:
		# Show time remaining or revive progress
		if reviving_player:
			# Someone is reviving - show progress
			progress_bar.value = revive_progress
			progress_bar.modulate = Color(0.2, 0.8, 0.2, 0.9)  # Green
		else:
			# No one reviving - show time remaining
			progress_bar.value = revive_timer
			progress_bar.modulate = Color(0.8, 0.2, 0.2, 0.9)  # Red

	if timer_label:
		if reviving_player:
			var reviver_name = reviving_player.player_name if "player_name" in reviving_player else reviving_player.name
			timer_label.text = "REVIVING..."
		else:
			var time_left = int(revive_timer)
			timer_label.text = "DOWNED (" + str(time_left) + "s)"


func remove_revive_indicator() -> void:
	# Remove the revive indicator UI
	var indicator = get_node_or_null("ReviveIndicator")
	if indicator:
		indicator.queue_free()


func show_player_ui() -> void:
	# Show all UI elements when player is revived
	var health_bar = get_node_or_null("HealthBar")
	if health_bar:
		health_bar.visible = true

	var stamina_bar = get_node_or_null("StaminaBar")
	if stamina_bar:
		stamina_bar.visible = true

	var level_label = get_node_or_null("LevelLabel")
	if level_label:
		level_label.visible = true

	var xp_bar = get_node_or_null("XPBar")
	if xp_bar:
		xp_bar.visible = true

	var coin_display = get_node_or_null("CoinDisplay")
	if coin_display:
		coin_display.visible = true

	var wave_display = get_node_or_null("WaveDisplay")
	if wave_display:
		wave_display.visible = true

	var combo_ui = get_tree().root.get_node_or_null("ComboAttackUI")
	if combo_ui:
		combo_ui.visible = true


@rpc("any_peer", "reliable", "call_local")
func sync_downed_state(downed: bool, timer: float) -> void:
	# Sync downed state across all clients
	print("[REVIVE] sync_downed_state called for player ", name, " - downed: ", downed, " timer: ", timer)
	is_downed = downed
	revive_timer = timer
	revive_timer_sync_cooldown = 0.0  # Reset sync cooldown

	if downed:
		# Apply visual state
		var sprite = get_node_or_null("AnimatedSprite2D")
		if sprite:
			print("[REVIVE] Setting sprite visible and red tint for player ", name)
			sprite.modulate = Color(1.0, 0.5, 0.5, 0.7)
			sprite.visible = true
			# Force update to ensure visibility
			sprite.show()
		else:
			print("[REVIVE] ERROR: AnimatedSprite2D not found for player ", name)
		create_revive_indicator()
	else:
		# Reset visual state (permanent death)
		var sprite = get_node_or_null("AnimatedSprite2D")
		if sprite:
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
			sprite.visible = false
		remove_revive_indicator()


@rpc("any_peer", "reliable", "call_local")
func sync_revive_timer(timer: float) -> void:
	# Sync revive timer across all clients (called periodically from authority)
	revive_timer = timer
	update_revive_indicator()


@rpc("any_peer", "reliable", "call_local")
func sync_revive_progress(progress: float) -> void:
	# Sync revive progress across all clients
	revive_progress = progress
	update_revive_indicator()


@rpc("any_peer", "reliable", "call_local")
func sync_revive_start(downed_player_id: int, reviver_player_id: int) -> void:
	# Sync revive start across all clients
	var downed_player = get_tree().current_scene.get_node_or_null(str(downed_player_id))
	var reviver_player = get_tree().current_scene.get_node_or_null(str(reviver_player_id))

	if downed_player and reviver_player:
		downed_player.reviving_player = reviver_player
		downed_player.revive_progress = 0.0
		downed_player.update_revive_indicator()


@rpc("any_peer", "reliable", "call_local")
func sync_revive_stop(downed_player_id: int) -> void:
	# Sync revive stop across all clients
	var downed_player = get_tree().current_scene.get_node_or_null(str(downed_player_id))

	if downed_player:
		downed_player.reviving_player = null
		downed_player.revive_progress = 0.0
		downed_player.update_revive_indicator()


@rpc("any_peer", "reliable")
func request_revive_start(reviver_player_id: int) -> void:
	# Request to start reviving this player (called by reviving player)
	print("[REVIVE] request_revive_start called for player ", name, " by reviver ", reviver_player_id)

	if not is_multiplayer_authority():
		print("[REVIVE] Not authority, returning")
		return  # Only process on authority

	if not is_downed:
		print("[REVIVE] Not downed, returning")
		return  # Not downed

	if reviving_player:
		print("[REVIVE] Already being revived by ", reviving_player.name)
		return  # Already being revived

	# Find the reviving player
	var reviver = get_tree().current_scene.get_node_or_null(str(reviver_player_id))
	if not reviver:
		print("[REVIVE] ERROR: Could not find reviver player ", reviver_player_id)
		return

	# Check distance
	var distance = global_position.distance_to(reviver.global_position)
	print("[REVIVE] Distance to reviver: ", distance, " (required: ", REVIVE_RADIUS, ")")
	if distance > REVIVE_RADIUS:
		print("[REVIVE] Too far away, returning")
		return  # Too far away

	# Start revive
	reviving_player = reviver
	revive_progress = 0.0

	# Broadcast revive start
	rpc("sync_revive_start", name.to_int(), reviver_player_id)

	print("[REVIVE] Player ", name, " started being revived by player ", reviver.name)


@rpc("any_peer", "reliable")
func request_revive_stop() -> void:
	# Request to stop reviving this player (called by reviving player)
	if not is_multiplayer_authority():
		return  # Only process on authority

	if not reviving_player:
		return  # Not being revived

	# Stop revive
	reviving_player = null
	revive_progress = 0.0

	# Broadcast revive stop
	rpc("sync_revive_stop", name.to_int())

	print("Player ", name, " stopped being revived")


@rpc("any_peer", "reliable", "call_local")
func sync_revive_complete(player_id: int, new_health: int) -> void:
	# Sync revive completion across all clients
	var player = get_tree().current_scene.get_node_or_null(str(player_id))

	if player:
		player.is_downed = false
		player.is_alive = true
		player.current_health = new_health
		player.reviving_player = null
		player.revive_progress = 0.0
		player.revive_timer = 0.0

		# Restore sprite
		var sprite = player.get_node_or_null("AnimatedSprite2D")
		if sprite:
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
			sprite.visible = true

		# Re-enable collision
		player.set_collision_layer_value(1, true)
		player.set_collision_mask_value(1, true)

		# Show UI
		player.show_player_ui()
		player.update_health_display()
		player.remove_revive_indicator()

		# Re-setup camera for local player (important after revival)
		var player_peer_id = player.name.to_int()
		if player_peer_id == multiplayer.get_unique_id():
			player.setup_camera()


func update_spectator_camera() -> void:
	# Follow an alive player's camera (preferably the host)
	# Only update camera position, don't move the player's position
	# The player should stay where they died
	var camera = get_node_or_null("Camera2D")
	if not camera:
		return

	# Don't update if this player is alive (shouldn't be in spectator mode)
	if is_alive and current_health > 0:
		return

	# Find the first alive player to spectate
	var players = get_tree().get_nodes_in_group("players")
	var alive_player = null

	# First, try to find the host (peer ID 1)
	for player in players:
		if "is_alive" in player and player.is_alive:
			var player_name = str(player.name)
			if player_name == "1" or player_name.to_int() == 1:
				alive_player = player
				break

	# If host is dead, find any alive player
	if not alive_player:
		for player in players:
			if "is_alive" in player and player.is_alive:
				alive_player = player
				break

	# Move camera to follow the alive player (but don't move the dead player's position)
	if alive_player:
		# Only update camera position, not player position
		# The camera will follow the alive player automatically if it's a child
		# But if we need to manually position it, we can do that here
		pass  # Camera should already be following if set up correctly


func show_game_over_screen() -> void:
	# Load and show the game over screen (shown when all players are dead)
	var game_over_scene = load("res://coop/scenes/game_over_screen.tscn")
	if game_over_scene:
		var game_over_instance = game_over_scene.instantiate()
		# Add to root so it's above everything
		get_tree().root.add_child(game_over_instance)


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


# Team XP System - Called when team levels up
func _on_team_level_up() -> void:
	# Apply automatic level up bonuses to this player
	max_health += 10
	current_health = max_health  # Full heal on level up
	attack_damage += 5  # Increase attack damage by 5 per level

	print("Player ", name, " received team level up bonuses!")
	print("New max health: ", max_health)
	print("New attack damage: ", attack_damage)

	# Update GameDirector with new health values (server only)
	if multiplayer.is_server():
		var peer_id = name.to_int()
		GameDirector.update_player_health(peer_id, current_health, max_health)

	# Update displays
	update_health_display()
	update_xp_display()

	# Show upgrade overlay (only for local player)
	# Game does NOT pause - player can choose upgrade while playing
	if is_multiplayer_authority():
		_on_level_up_ready()


# Team XP System - Called when team XP changes
func _on_team_xp_changed(_current_xp: int, _xp_needed: int) -> void:
	# Update XP display whenever team XP changes
	update_xp_display()


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
			# This upgrade is now deprecated with the new fire cooldown system
			# Instead, it provides additional fire rate bonus
			weapon_stats.fire_cooldown *= 0.9  # 10% faster fire rate
			print("Fire cooldown reduced to: ", weapon_stats.fire_cooldown)

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

		# ===== SWORD-SPECIFIC UPGRADES =====
		"sweep_attack":
			# Increase melee attack range by 50%
			melee_attack_range *= 1.5
			print("Melee attack range increased to: ", melee_attack_range)

		"heavy_strike":
			# +30% melee damage
			weapon_stats.damage_multiplier += 0.3
			print("Melee damage multiplier: ", weapon_stats.damage_multiplier)

		"whirlwind":
			# 360° attack (modify cone check to always hit)
			# This will be handled in perform_melee_damage
			if not "whirlwind" in active_abilities:
				active_abilities.append("whirlwind")
				print("Whirlwind ability unlocked! Attacks hit all around you")

		"dash_strike":
			# Dash and attack ability
			if not "dash_strike" in active_abilities:
				active_abilities.append("dash_strike")
				print("Dash Strike ability unlocked! Press Q to dash attack")
				# TODO: Implement dash strike ability

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


## Convert weapon name to projectile type for ProjectileManager
func _get_projectile_type() -> String:
	# Map weapon names to projectile types
	match equipped_weapon:
		"bow":
			return "arrow"
		"rocket":
			return "rocket"
		_:
			push_warning("Unknown weapon type: ", equipped_weapon, " - defaulting to arrow")
			return "arrow"


## Get weapon stats as dictionary for ProjectileManager
func _get_weapon_stats_dict() -> Dictionary:
	# Calculate final damage (base + flat + multiplier)
	var final_damage = (attack_damage + weapon_stats.damage) * weapon_stats.damage_multiplier

	return {
		"damage": final_damage,
		"speed": weapon_stats.arrow_speed,
		"pierce_count": weapon_stats.pierce_count,
		"crit_chance": weapon_stats.crit_chance,
		"crit_multiplier": weapon_stats.crit_multiplier,
		"explosion_chance": weapon_stats.explosion_chance,
		"explosion_radius": weapon_stats.explosion_radius,
		"explosion_damage": weapon_stats.explosion_damage if weapon_stats.explosion_damage > 0 else final_damage * 0.75,
		"lifesteal": weapon_stats.lifesteal,
		"poison_damage": weapon_stats.poison_damage,
		"poison_duration": weapon_stats.poison_duration,
		"homing_strength": weapon_stats.homing_strength
	}


## CLIENT: Spawn visual-only projectile for instant feedback
func spawn_projectile_visual(target_pos: Vector2) -> void:
	# Use ProjectileManager for clean API
	ProjectileManager.spawn_visual_projectile(
		self,
		target_pos,
		_get_projectile_type(),
		_get_weapon_stats_dict()
	)


## CLIENT: Request server to spawn authoritative projectile
func request_projectile_spawn(target_pos: Vector2) -> void:
	# Calculate spawn position and direction
	var animated_sprite = get_node("AnimatedSprite2D")
	var sprite_position = animated_sprite.global_position if animated_sprite else global_position
	var direction = (target_pos - sprite_position).normalized()

	# Use ProjectileManager RPC
	ProjectileManager.spawn_projectile.rpc(
		sprite_position,
		direction,
		_get_projectile_type(),
		multiplayer.get_unique_id(),
		_get_weapon_stats_dict()
	)


## DEPRECATED: Use ProjectileManager.spawn_projectile.rpc() instead
## SERVER: Validate and spawn authoritative projectile, broadcast to all clients
@rpc("any_peer", "reliable")
func spawn_projectile_on_server(spawn_pos: Vector2, direction: Vector2, shooter_peer_id: int) -> void:
	push_warning("DEPRECATED: spawn_projectile_on_server() - Use ProjectileManager instead")
	# Only server processes projectile spawning
	if not multiplayer.is_server():
		push_warning("Client attempted to call spawn_projectile_on_server directly")
		return

	# Get the actual sender (handle direct calls)
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:  # Called directly, not via RPC
		sender_id = shooter_peer_id

	# SECURITY: Rate limiting - prevent projectile spam
	if not validate_rpc_rate_limit(sender_id, "spawn_projectile_on_server", ATTACK_RPC_MIN_INTERVAL):
		return

	# SECURITY: Validate vector bounds
	if not validate_vector_bounds(spawn_pos) or not validate_vector_bounds(direction):
		return

	# SECURITY: Validate direction is normalized (prevent speed hacks)
	if abs(direction.length() - 1.0) > 0.1:  # Should be normalized (length ~= 1.0)
		push_warning("Projectile direction not normalized: ", direction.length())
		return

	# Find the shooter player to get their stats
	var shooter = null
	for player in get_tree().get_nodes_in_group("players"):
		if player.name.to_int() == shooter_peer_id:
			shooter = player
			break

	if not shooter:
		push_warning("Could not find shooter player for peer ", shooter_peer_id)
		return

	# SECURITY: Validate spawn position is near shooter (anti-cheat)
	var distance_from_shooter = spawn_pos.distance_to(shooter.global_position)
	if distance_from_shooter > 100.0:  # Max 100 pixels from shooter
		push_warning("Projectile spawn too far from shooter: ", distance_from_shooter)
		return

	# SECURITY: Validate fire cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last_shot = current_time - shooter.last_projectile_spawn_time
	var min_fire_cooldown = shooter.weapon_stats.fire_cooldown * 0.8  # Allow 20% leeway for network lag
	if time_since_last_shot < min_fire_cooldown:
		push_warning("Projectile fire cooldown violation from peer ", shooter_peer_id)
		return

	# Update last projectile spawn time
	shooter.last_projectile_spawn_time = current_time

	# Server spawns authoritative projectile and broadcasts to all clients
	shooter._internal_spawn_projectile(direction, false)


## DEPRECATED: Use ProjectileManager.spawn_visual_projectile() or ProjectileManager.spawn_projectile.rpc() instead
## INTERNAL: Spawn projectile with visual-only or authoritative mode
## @param is_visual_only: If true, projectile is client-side visual feedback only (no damage)
func _internal_spawn_projectile(direction: Vector2, is_visual_only: bool = false) -> void:
	push_warning("DEPRECATED: _internal_spawn_projectile() - Use ProjectileManager instead")
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

	var mode_str = "VISUAL" if is_visual_only else "AUTHORITATIVE"
	print("Spawning ", mode_str, " projectile for weapon: ", equipped_weapon, " (player: ", name, ")")

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
	print("Mode: ", mode_str)
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

		# Set multiplayer authority flags
		projectile.is_visual_only = is_visual_only
		projectile.shooter_peer_id = multiplayer.get_unique_id()

		# Initialize with old method for compatibility
		projectile.initialize(self, base_spawn_position, target_position)

		# Set shooter metadata
		projectile.set_meta("shooter", self)

		# Add to scene
		get_tree().current_scene.add_child(projectile)


# Spawn projectile(s) in given direction with current weapon_stats
# DEPRECATED: Use spawn_projectile_visual() or request_projectile_spawn() instead
func spawn_projectile(direction: Vector2) -> void:
	_internal_spawn_projectile(direction, false)


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

	# Get the base damage from weapon, but don't override if we already have damage set
	# This preserves class modifiers that were applied before weapon initialization
	var weapon_base_damage = int(current_weapon_config.base_damage)

	# If attack_damage is still default (15), use weapon base damage
	# Otherwise, keep the current value (which has class modifiers already applied)
	if attack_damage == 15:
		attack_damage = weapon_base_damage
		print("  - Set attack damage to weapon base: ", weapon_base_damage)
	else:
		print("  - Keeping existing attack damage (has class modifiers): ", attack_damage)

	# Update weapon_stats with weapon-specific defaults
	weapon_stats.fire_cooldown = current_weapon_config.fire_cooldown
	weapon_stats.arrow_speed = current_weapon_config.projectile_speed
	weapon_stats.explosion_chance = current_weapon_config.base_explosion_chance
	weapon_stats.explosion_radius = current_weapon_config.base_explosion_radius
	weapon_stats.explosion_damage = current_weapon_config.base_explosion_damage

	print("Initialized weapon: ", current_weapon_config.name)
	print("  - Final attack damage: ", attack_damage)
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


func play_pickup_sound() -> void:
	# Play coin pickup sound
	var pickup_sound = load("res://assets/Sounds/SFX/pickup.mp3")
	if pickup_sound:
		var temp_sound = AudioStreamPlayer2D.new()
		temp_sound.stream = pickup_sound
		temp_sound.position = global_position
		# Add to scene tree and play
		get_tree().current_scene.add_child(temp_sound)
		temp_sound.play()
		# Clean up after sound finishes
		temp_sound.finished.connect(func(): temp_sound.queue_free())


func play_levelup_sound() -> void:
	# Play player level up sound (note: filename has typo "leveup")
	var levelup_sound = load("res://assets/Sounds/SFX/player_leveup.mp3")
	if levelup_sound:
		var temp_sound = AudioStreamPlayer2D.new()
		temp_sound.stream = levelup_sound
		temp_sound.position = global_position
		# Add to scene tree and play
		get_tree().current_scene.add_child(temp_sound)
		temp_sound.play()
		# Clean up after sound finishes
		temp_sound.finished.connect(func(): temp_sound.queue_free())


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

	# Apply combat type and melee range
	if class_data.has("combat_type"):
		combat_type = class_data["combat_type"]
		print("  Combat type: ", combat_type)

		# Set appropriate weapon based on combat type
		if combat_type == "melee":
			equipped_weapon = "sword"
			print("  Equipped weapon set to: sword (melee)")
		elif equipped_weapon == "sword":
			# If switching from melee to ranged, default to bow
			equipped_weapon = "bow"
			print("  Equipped weapon set to: bow (ranged)")

	if class_data.has("attack_range"):
		melee_attack_range = class_data["attack_range"]
		if combat_type == "melee":
			print("  Melee attack range: ", melee_attack_range)

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


# Load player name from save system
func _load_player_name() -> void:
	# Wait for SaveSystem to load if it hasn't yet
	if not SaveSystem.is_loaded:
		await SaveSystem.data_loaded

	player_name = SaveSystem.get_player_name()
	print("[Player] Loaded player name: ", player_name)
