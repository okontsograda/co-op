extends CharacterBody2D

# Enemy size variations
enum EnemySize {
	SMALL,
	MEDIUM,
	LARGE,
	HUGE
}

var enemy_size: EnemySize = EnemySize.MEDIUM

# Boss properties
var is_boss: bool = false
var boss_name: String = ""
var boss_name_label: Label = null

# Sound settings
@export_file("*.mp3", "*.wav", "*.ogg") var attack_hit_sound_path: String = "res://assets/Sounds/SFX/mushroom_hit.mp3"

# Base stats (for MEDIUM size)
var speed: float = 80.0
var attack_range: float = 40.0
var attack_damage: int = 15
var attack_cooldown: float = 1.5
var max_health: int = 50
var current_health: int = max_health
var target_player: Node2D = null
var can_attack: bool = true
var is_in_attack_range: bool = false

# Area attack properties (for flyguy)
var is_area_attack: bool = false
var area_attack_radius: float = 100.0  # Radius for area attacks
var attack_warning_indicator: Node2D = null  # Visual warning circle
var attack_collision_area: Area2D = null  # Collision area for attack range (visible)
var warning_tween: Tween = null  # Tween for warning animation
var area_attack_position: Vector2 = Vector2.ZERO  # Store position when attack starts
var last_attacker: String = ""  # Track who dealt the killing blow

# Animation states
var is_attacking: bool = false
var is_hit: bool = false
var hit_timer: float = 0.0
const hit_animation_duration: float = 0.3  # Duration of hit animation

# Knockback system
var is_knocked_back: bool = false
var knockback_timer: float = 0.0
const knockback_duration: float = 0.2  # How long knockback lasts
const knockback_friction: float = 8.0  # How quickly knockback decays

# Damage over time (poison, etc.)
var poison_damage: int = 0  # Damage per second
var poison_duration: float = 0.0  # Duration remaining in seconds
var poison_tick_timer: float = 0.0  # Timer for damage ticks
const poison_tick_rate: float = 1.0  # Apply poison damage every 1 second

# Sound effects
var hit_sound_player: AudioStreamPlayer2D = null

# Multiplayer synchronization
var sync_node: MultiplayerSynchronizer = null

# Client-side interpolation
var server_position: Vector2 = Vector2.ZERO  # Last position from server
var interpolation_speed: float = 15.0  # How fast to lerp to server position

# RPC Security - Rate limiting
var rpc_rate_limits: Dictionary = {}  # Track RPC calls: {rpc_name: last_call_time}
const RPC_MIN_INTERVAL: float = 0.05  # Minimum 50ms between same RPC


func _ready() -> void:
	# Add to enemies group
	add_to_group("enemies")
	
	# Check if this is a flyguy enemy (area attack)
	var scene_file = get_scene_file_path()
	if scene_file and "flyguy" in scene_file.to_lower():
		is_area_attack = true
		# Area attack radius will be set in apply_size_stats() based on enemy size
		# Set flyguy-specific attack sound (if not already set in scene)
		if attack_hit_sound_path == "res://assets/Sounds/SFX/mushroom_hit.mp3":
			attack_hit_sound_path = "res://assets/Sounds/SFX/ground_impact.mp3"  # Change to flyguy sound
	
	# Make enemy not pushable by other CharacterBody2D (players)
	# Set motion mode to MOTION_MODE_FLOATING to prevent being pushed
	# This prevents the bug where players can push enemies around
	set_motion_mode(CharacterBody2D.MOTION_MODE_FLOATING)
	
	# Enable Y-sort for proper depth sorting
	# Characters with higher Y position (lower on screen) will render in front
	y_sort_enabled = true

	# Connect Area2D signals for attack detection
	var area = get_node("Area2D")
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

	# Apply size-based stats
	apply_size_stats()

	# Initialize health bar
	update_health_display()

	# Set authority to server only when we're on the server
	if multiplayer.is_server():
		# On server, set authority to 1 (server) and run AI
		set_multiplayer_authority(1)
	else:
		# On clients, set authority to 1 (server) so they sync from server
		set_multiplayer_authority(1)

	# Configure MultiplayerSynchronizer for efficient network sync
	setup_multiplayer_sync()

	# Initialize interpolation position
	server_position = global_position

	# Start with idle animation
	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.play("idle")

	# Set up hit sound
	setup_hit_sound()

	# Only initialize AI on server
	if not is_multiplayer_authority():
		return


## Configure MultiplayerSynchronizer for automatic property syncing
func setup_multiplayer_sync() -> void:
	# Check if we already have a MultiplayerSynchronizer (from scene)
	sync_node = get_node_or_null("MultiplayerSynchronizer")

	if not sync_node:
		# Create MultiplayerSynchronizer programmatically
		sync_node = MultiplayerSynchronizer.new()
		sync_node.name = "MultiplayerSynchronizer"
		add_child(sync_node)

	# Set root path to this enemy node
	sync_node.root_path = NodePath("..")

	# Configure replication for smooth movement
	sync_node.replication_interval = 0.0  # Sync as fast as possible (no throttling)
	sync_node.delta_interval = 0.0  # Always sync position changes

	# Enable visibility culling to reduce bandwidth
	sync_node.visibility_update_mode = MultiplayerSynchronizer.VISIBILITY_PROCESS_IDLE

	# Configure which properties to sync (only essential ones)
	var config = SceneReplicationConfig.new()

	# Sync position (most important for smooth movement)
	config.add_property(".:global_position")
	config.property_set_spawn(".:global_position", true)
	config.property_set_replication_mode(".:global_position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)

	# Sync health (for health bars)
	config.add_property(".:current_health")
	config.property_set_replication_mode(".:current_health", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

	# Sync animation state (for visual consistency)
	config.add_property(".:is_attacking")
	config.property_set_replication_mode(".:is_attacking", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

	config.add_property(".:is_hit")
	config.property_set_replication_mode(".:is_hit", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

	# Apply configuration
	sync_node.replication_config = config

	print("Enemy ", name, " MultiplayerSynchronizer configured")


## ============================================================================
## RPC SECURITY VALIDATION HELPERS
## ============================================================================

## Validate RPC call is not being spammed (rate limiting)
func validate_rpc_rate_limit(rpc_name: String, min_interval: float = RPC_MIN_INTERVAL) -> bool:
	var current_time = Time.get_ticks_msec() / 1000.0

	# Check if this RPC was called too recently
	if rpc_rate_limits.has(rpc_name):
		var time_since_last_call = current_time - rpc_rate_limits[rpc_name]
		if time_since_last_call < min_interval:
			push_warning("Enemy ", name, " RPC rate limit exceeded for ", rpc_name,
				" (", time_since_last_call, "s since last call)")
			return false

	# Update last call time
	rpc_rate_limits[rpc_name] = current_time
	return true


## Validate RPC caller has server authority
func validate_rpc_authority(rpc_name: String) -> bool:
	var sender_id = multiplayer.get_remote_sender_id()
	# Authority RPCs must come from server (peer 1)
	if sender_id != 1 and not multiplayer.is_server():
		push_warning("Enemy ", name, " unauthorized RPC: ", rpc_name, " from peer ", sender_id)
		return false
	return true


func set_enemy_size(size: EnemySize) -> void:
	enemy_size = size
	apply_size_stats()


func apply_size_stats() -> void:
	# Base stats for MEDIUM
	var base_speed = 80.0
	var base_health = 50
	var base_damage = 15
	var base_range = 40.0
	var base_cooldown = 1.5
	var base_scale = 1.0
	var base_area_radius = 100.0  # Base area attack radius for flyguy
	
	match enemy_size:
		EnemySize.SMALL:
			# Small enemies: Fast, low health, low damage
			speed = base_speed * 1.3  # 104
			max_health = int(base_health * 0.5)  # 25
			attack_damage = int(base_damage * 0.7)  # 10
			attack_range = base_range * 0.8  # 32
			attack_cooldown = base_cooldown * 0.8  # 1.2
			scale = Vector2.ONE * 0.7  # Smaller sprite
			# Scale area attack radius with sprite scale for flyguy
			if is_area_attack:
				area_attack_radius = base_area_radius * 0.7  # 70
			
		EnemySize.MEDIUM:
			# Medium enemies: Balanced
			speed = base_speed  # 80
			max_health = base_health  # 50
			attack_damage = base_damage  # 15
			attack_range = base_range  # 40
			attack_cooldown = base_cooldown  # 1.5
			scale = Vector2.ONE * base_scale  # Normal sprite
			# Base area attack radius for flyguy
			if is_area_attack:
				area_attack_radius = base_area_radius  # 100
			
		EnemySize.LARGE:
			# Large enemies: Slow, high health, high damage
			speed = base_speed * 0.7  # 56
			max_health = int(base_health * 2.5)  # 125
			attack_damage = int(base_damage * 1.8)  # 27
			attack_range = base_range * 1.2  # 48
			attack_cooldown = base_cooldown * 1.3  # 1.95
			scale = Vector2.ONE * 1.5  # Larger sprite
			# Scale area attack radius with sprite scale for flyguy
			if is_area_attack:
				area_attack_radius = base_area_radius * 1.5  # 150
			
		EnemySize.HUGE:
			# Huge enemies: Very slow, very high health, very high damage (boss-like)
			speed = base_speed * 0.5  # 40
			max_health = int(base_health * 5.0)  # 250
			attack_damage = int(base_damage * 2.5)  # 37
			attack_range = base_range * 1.5  # 60
			attack_cooldown = base_cooldown * 1.5  # 2.25
			scale = Vector2.ONE * 2.0  # Much larger sprite
			# Scale area attack radius with sprite scale for flyguy
			if is_area_attack:
				area_attack_radius = base_area_radius * 2.0  # 200
	
	# Set current health to max health
	current_health = max_health
	
	# Update attack range for area attacks
	if is_area_attack:
		attack_range = area_attack_radius
		# Update collision shape and polygon if they exist (for flyguy)
		update_area_attack_visuals()


func get_size_name() -> String:
	match enemy_size:
		EnemySize.SMALL:
			return "SMALL"
		EnemySize.MEDIUM:
			return "MEDIUM"
		EnemySize.LARGE:
			return "LARGE"
		EnemySize.HUGE:
			return "HUGE"
	return "UNKNOWN"


func update_area_attack_visuals() -> void:
	"""Update the area attack collision shape and polygon to match current radius"""
	if not is_area_attack:
		return
	
	var area = get_node_or_null("AttackRangeArea")
	if not area:
		return
	
	# Update collision shape radius
	var collision_shape = area.get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = area_attack_radius
	
	# Update polygon points
	var polygon = area.get_node_or_null("Polygon2D")
	if polygon:
		var segments = 64  # Smooth circle
		var polygon_points = PackedVector2Array()
		for i in range(segments):
			var angle = (i / float(segments)) * TAU
			var point = Vector2(cos(angle), sin(angle)) * area_attack_radius
			polygon_points.append(point)
		polygon.polygon = polygon_points


func apply_wave_scaling(health_multiplier: float, damage_multiplier: float) -> void:
	# Apply progressive wave scaling to enemy stats
	max_health = int(max_health * health_multiplier)
	current_health = max_health
	attack_damage = int(attack_damage * damage_multiplier)


func make_boss(boss_name_param: String, boss_health: int) -> void:
	# Convert this enemy into a boss with unique properties
	is_boss = true
	boss_name = boss_name_param
	max_health = boss_health
	current_health = boss_health
	
	# Bosses are tougher and deal more damage
	attack_damage = int(attack_damage * 1.5)  # 50% more damage
	speed = speed * 0.8  # Slightly slower (more menacing)
	
	# Visual distinction: Add golden/red tint to sprite
	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.modulate = Color(1.2, 0.8, 0.8)  # Reddish tint
	
	# Create and position name label above the boss
	create_boss_name_label()
	
	# Update health bar to show boss health
	update_health_display()


func create_boss_name_label() -> void:
	# Create a label to display the boss name above the sprite
	boss_name_label = Label.new()
	boss_name_label.text = boss_name
	boss_name_label.name = "BossNameLabel"
	
	# Style the label
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 16)
	boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))  # Golden color
	boss_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	boss_name_label.add_theme_constant_override("outline_size", 3)
	
	# Position label above the enemy sprite
	# Offset upward based on enemy scale (bosses are larger)
	var offset_y = -32.5 * scale.y  # Adjust based on sprite size
	boss_name_label.position = Vector2(-50, offset_y)  # Center horizontally, above sprite
	boss_name_label.size = Vector2(100, 30)
	
	add_child(boss_name_label)


func _physics_process(_delta: float) -> void:
	# Handle poison damage over time (only on server)
	if is_multiplayer_authority() and poison_duration > 0.0:
		poison_duration -= _delta
		poison_tick_timer -= _delta
		
		# Apply poison damage every tick
		if poison_tick_timer <= 0.0:
			poison_tick_timer = poison_tick_rate
			if current_health > 0:
				# Apply poison damage
				var damage_to_apply = poison_damage
				current_health -= damage_to_apply
				
				# Show damage number for poison tick (green color for poison)
				spawn_damage_number(global_position, damage_to_apply, false, true)
				
				# Update health bar
				update_health_display()
				
				# Sync health to all clients
				rpc("sync_health", current_health)
				
				# Check if poison killed the enemy
				if current_health <= 0:
					# Award XP to the last attacker
					award_xp_to_killer()
					# Notify NetworkHandler of enemy death
					NetworkHandler.on_enemy_died(is_boss)
					# Broadcast death
					rpc("die_rpc")
					return
		
		# Clear poison when duration expires
		if poison_duration <= 0.0:
			poison_damage = 0
			poison_tick_timer = 0.0

	# Handle hit animation timer
	if is_hit:
		hit_timer -= _delta
		if hit_timer <= 0:
			is_hit = false

	# Handle knockback timer
	if is_knocked_back:
		knockback_timer -= _delta
		if knockback_timer <= 0:
			is_knocked_back = false

	# Client-side interpolation for smooth movement
	if not is_multiplayer_authority():
		# Clients lerp to server position for smooth movement
		# MultiplayerSynchronizer updates our actual global_position from server
		# We store that as server_position and smoothly interpolate to it

		# If position changed significantly from server, update target
		if global_position.distance_squared_to(server_position) > 1.0:
			server_position = global_position

		# Smoothly interpolate visual position toward server position
		# This creates smooth movement between server updates
		global_position = global_position.lerp(server_position, interpolation_speed * _delta)

		# Update animations and visuals
		update_animation()
		z_index = int(global_position.y)
		return

	# If knocked back, apply friction to velocity and skip normal AI
	if is_knocked_back:
		# Apply friction to slow down knockback
		velocity = velocity.lerp(Vector2.ZERO, knockback_friction * _delta)
		# Stop knockback if velocity is very small
		if velocity.length() < 5.0:
			velocity = Vector2.ZERO
			is_knocked_back = false
	else:
		# Normal AI behavior when not knocked back
		# Find nearest player
		find_target_player()

		# Check if target is in attack range
		if target_player:
			var distance_to_target = global_position.distance_to(target_player.global_position)
			is_in_attack_range = distance_to_target <= attack_range

			# Calculate direction to target for sprite facing
			var direction_to_target = (target_player.global_position - global_position).normalized()

			# Flip sprite to face target player
			# flip_h = true faces left, flip_h = false faces right
			# If target is to the right, we want to face right (flip_h = false)
			# If target is to the left, we want to face left (flip_h = true)
			var sprite = get_node_or_null("AnimatedSprite2D")
			if sprite:
				sprite.flip_h = direction_to_target.x > 0

			# Attack if in range
			if is_in_attack_range and can_attack and not is_attacking:
				attack_target(target_player)

			# Move towards target if not in attack range and not attacking
			# For area attacks, also stop moving when attacking (even if not "in range" by single-target logic)
			if not is_in_attack_range and not is_attacking and not (is_area_attack and is_attacking):
				velocity = direction_to_target * speed
			else:
				# Stop moving when in attack range or attacking
				# For area attacks, always stop when attacking
				velocity = Vector2.ZERO
		else:
			# No target, stop moving
			velocity = Vector2.ZERO
			is_in_attack_range = false
		
		# For area attacks, always stop moving when attacking (extra safety check)
		if is_area_attack and is_attacking:
			velocity = Vector2.ZERO
			
	# Always call move_and_slide for proper physics handling
	move_and_slide()
	
	# Update z_index based on Y position for proper depth sorting
	z_index = int(global_position.y)

	# Update animation
	update_animation()

	# Position sync is handled automatically by MultiplayerSynchronizer
	# No manual sync needed - it causes conflicts and choppy movement


func find_target_player() -> void:
	var players = get_tree().get_nodes_in_group("players")
	if players.is_empty():
		target_player = null
		return

	# Find closest ALIVE player (target all players, not just authoritative ones)
	var closest_distance = INF
	var closest_player = null

	for player in players:
		# Skip dead players (check if property exists and is false)
		if "is_alive" in player and not player.is_alive:
			continue
		
		var distance = global_position.distance_to(player.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_player = player

	target_player = closest_player


func apply_knockback(knockback_velocity: Vector2) -> void:
	# Apply knockback to this enemy
	velocity = knockback_velocity
	is_knocked_back = true
	knockback_timer = knockback_duration


func take_damage(amount: int, attacker: Node2D) -> void:
	# Only process damage on server instances
	if not is_multiplayer_authority():
		return

	var attacker_name = str(attacker.name) if attacker else "unknown"

	# Process damage directly on server
	take_damage_rpc(amount, attacker_name)


@rpc("any_peer", "reliable")
func take_damage_rpc(amount: int, attacker_name: String) -> void:
	# Only process damage on server (authority)
	if not is_multiplayer_authority():
		return

	current_health -= amount

	# Track the attacker for XP purposes
	last_attacker = attacker_name

	# Play hit sound every time damage is taken (including killing blow)
	# Play locally first for immediate feedback, then via RPC for all clients
	play_hit_sound()
	rpc("play_hit_sound")

	# Trigger hit animation (only if enemy survives)
	if current_health > 0:
		is_hit = true
		hit_timer = hit_animation_duration
		rpc("play_hit_animation")

	# Update health bar locally
	update_health_display()

	# Broadcast damage number to all clients via VFXManager
	VFXManager.spawn_damage_number.rpc(global_position, amount, false)

	if current_health <= 0:
		# Award XP to the killer before death
		award_xp_to_killer()
		# Notify NetworkHandler of enemy death for wave tracking
		NetworkHandler.on_enemy_died(is_boss)
		# Broadcast death to all clients
		rpc("die_rpc")
	else:
		# Broadcast health update to all clients
		rpc("sync_health", current_health)


@rpc("any_peer", "reliable", "call_local")
func sync_health(health: int) -> void:
	# SECURITY: Verify this RPC came from server
	if not validate_rpc_authority("sync_health"):
		return

	# SECURITY: Rate limiting
	if not validate_rpc_rate_limit("sync_health"):
		return

	current_health = health
	update_health_display()


@rpc("any_peer", "reliable", "call_local")
func die_rpc() -> void:
	# SECURITY: Verify this RPC came from server
	if not validate_rpc_authority("die_rpc"):
		return

	# Random chance to drop a coin (only on server to prevent duplicate drops)
	if multiplayer.is_server():
		spawn_coin_drop()

	# Immediately queue for deletion
	queue_free()


func spawn_coin_drop() -> void:
	# Random chance to drop a coin
	var drop_chance = 0.3  # 30% base chance
	
	# Bosses have higher drop chance
	if is_boss:
		drop_chance = 0.8  # 80% chance for bosses
	
	# Roll for drop
	if randf() < drop_chance:
		# Determine coin value based on enemy size
		var coin_value = 1
		match enemy_size:
			EnemySize.SMALL:
				coin_value = 1
			EnemySize.MEDIUM:
				coin_value = 2
			EnemySize.LARGE:
				coin_value = 3
			EnemySize.HUGE:
				coin_value = 5
		
		# Bosses drop extra coins
		if is_boss:
			coin_value *= 3
		
		# Broadcast coin spawn to all clients
		rpc("spawn_coin_rpc", global_position, coin_value)


@rpc("any_peer", "reliable", "call_local")
func spawn_coin_rpc(spawn_position: Vector2, coin_value: int) -> void:
	# SECURITY: Verify this RPC came from server
	if not validate_rpc_authority("spawn_coin_rpc"):
		return

	# SECURITY: Rate limiting
	if not validate_rpc_rate_limit("spawn_coin_rpc", 0.5):  # Max once per 500ms
		return

	# Spawn coin at the specified position on all clients
	var coin_scene = load("res://coop/scenes/coin.tscn")
	if coin_scene:
		var coin = coin_scene.instantiate()
		coin.global_position = spawn_position
		coin.coin_value = coin_value

		# Add coin to the scene
		get_tree().current_scene.add_child(coin)


@rpc("any_peer", "reliable", "call_local")
func play_hit_animation() -> void:
	# SECURITY: Verify this RPC came from server
	if not validate_rpc_authority("play_hit_animation"):
		return

	# SECURITY: Rate limiting
	if not validate_rpc_rate_limit("play_hit_animation"):
		return

	# Play hit animation on all clients
	is_hit = true
	hit_timer = hit_animation_duration
	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("hit"):
		sprite.play("hit")


func setup_hit_sound() -> void:
	# Load the hit sound (try common names)
	var hit_sound = null
	var possible_names = [
		"res://assets/Sounds/SFX/hit.mp3",
		"res://assets/Sounds/SFX/enemy_hit.mp3",
		"res://assets/Sounds/SFX/hit.wav"
	]

	for sound_path in possible_names:
		hit_sound = load(sound_path)
		if hit_sound:
			break

	if hit_sound:
		# Create AudioStreamPlayer2D as a child of this enemy
		hit_sound_player = AudioStreamPlayer2D.new()
		hit_sound_player.name = "HitSoundPlayer"
		hit_sound_player.stream = hit_sound
		hit_sound_player.bus = "SFX"
		add_child(hit_sound_player)
	else:
		print("WARNING: No hit sound found. Tried: ", possible_names)


@rpc("any_peer", "reliable", "call_local")
func play_hit_sound() -> void:
	# SECURITY: Verify this RPC came from server
	if not validate_rpc_authority("play_hit_sound"):
		return

	# SECURITY: Rate limiting
	if not validate_rpc_rate_limit("play_hit_sound"):
		return

	# Play hit sound - always create a new sound instance to allow overlapping sounds
	var temp_sound = AudioStreamPlayer2D.new()
	var hit_sound = null

	# Try to use the cached sound from hit_sound_player if available
	if hit_sound_player and hit_sound_player.stream:
		hit_sound = hit_sound_player.stream
	else:
		# Load sound if not cached
		var possible_names = [
			"res://assets/Sounds/SFX/hit.mp3",
			"res://assets/Sounds/SFX/enemy_hit.mp3",
			"res://assets/Sounds/SFX/hit.wav"
		]
		for sound_path in possible_names:
			hit_sound = load(sound_path)
			if hit_sound:
				print("Loaded hit sound from: ", sound_path)
				break

	if hit_sound:
		temp_sound.stream = hit_sound
		temp_sound.bus = "SFX"
		temp_sound.position = global_position
		# Randomly vary the pitch slightly for variation (0.9 to 1.1 = 10% variation)
		temp_sound.pitch_scale = randf_range(0.9, 1.1)
		# Add to scene tree and play
		get_tree().current_scene.add_child(temp_sound)
		temp_sound.play()
		print(
			"Playing hit sound for enemy ",
			name,
			" at position ",
			global_position,
			" with pitch ",
			temp_sound.pitch_scale
		)
		# Clean up after sound finishes
		temp_sound.finished.connect(func(): temp_sound.queue_free())
	else:
		print("WARNING: Hit sound not found or not loaded for enemy ", name)


func attack_target(target: Node2D) -> void:
	# Only attack if we can attack
	if not can_attack:
		return

	# Set attacking state and play attack animation
	is_attacking = true
	can_attack = false  # Prevent multiple attacks

	# Get sprite reference
	var sprite = get_node_or_null("AnimatedSprite2D")
	
	# Calculate attack animation duration dynamically
	var attack_animation_duration: float = 0.7  # Default fallback
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
		var frame_count = sprite.sprite_frames.get_frame_count("attack")
		var anim_speed = sprite.sprite_frames.get_animation_speed("attack")
		if frame_count > 0 and anim_speed > 0:
			# Calculate duration: frame_count / anim_speed
			attack_animation_duration = frame_count / anim_speed
	
	# Play attack animation - immediate for single target, delayed for area attacks
	if not is_area_attack:
		# For single target attacks, play animation immediately (telegraph)
		rpc("play_attack_animation")
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
			# Ensure attack animation doesn't loop
			sprite.sprite_frames.set_animation_loop("attack", false)
			# Stop current animation and reset to ensure it plays from start
			sprite.stop()
			sprite.play("attack")
	
	# Show area attack warning indicator for flyguy
	if is_area_attack:
		# Store the attack position NOW - this is where the damage will be calculated from
		# Even if the flyguy moves during the attack, damage is based on where the warning was shown
		area_attack_position = global_position
		show_area_attack_warning()
	
	# Visual telegraph - flash red to warn player
	if sprite:
		var original_modulate = sprite.modulate
		sprite.modulate = Color(1.5, 0.7, 0.7)  # Red tint
		await get_tree().create_timer(0.1).timeout
		if sprite:
			sprite.modulate = original_modulate

	# Telegraph/windup delay - gives player time to react and move away
	const ATTACK_TELEGRAPH_DURATION = 0.3  # 0.3 seconds to react
	await get_tree().create_timer(ATTACK_TELEGRAPH_DURATION).timeout
	
	# Play attack animation for area attacks - delayed to sync with damage
	if is_area_attack:
		# For area attacks (flyguy), start animation now
		rpc("play_attack_animation")
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
			# Ensure attack animation doesn't loop
			sprite.sprite_frames.set_animation_loop("attack", false)
			# Stop current animation and reset to ensure it plays from start
			sprite.stop()
			sprite.play("attack")
		
		# Wait a bit for animation to reach the impact frame before dealing damage
		# This syncs the damage with the visual impact of the attack
		const AREA_ATTACK_DAMAGE_DELAY = 1.5  # Delay damage slightly after animation starts
		await get_tree().create_timer(AREA_ATTACK_DAMAGE_DELAY).timeout
		
		# Area attack - damage all players in radius
		perform_area_attack()
	else:
		# Single target attack - damage happens immediately after telegraph
		if target and is_instance_valid(target) and target.has_method("take_damage"):
			var distance_to_target = global_position.distance_to(target.global_position)
			
			if distance_to_target <= attack_range:
				# Player is still in range - hit them!
				target.take_damage(attack_damage, self)
				
				# Play mushroom hit sound when damage is dealt
				play_mushroom_hit_sound()
			else:
				# Player moved out of range - attack missed!
				print("Enemy ", name, " attack MISSED! Target moved out of range (", distance_to_target, " > ", attack_range, ")")
				spawn_miss_text()
	
	# Hide area attack warning after attack
	if is_area_attack:
		hide_area_attack_warning()

	# Wait for attack animation to finish
	if is_area_attack:
		# For area attacks, animation started after telegraph, so wait for full duration
		await get_tree().create_timer(attack_animation_duration).timeout
	else:
		# For single target attacks, animation started before telegraph
		# Wait for remaining animation duration minus telegraph time (0.3s) and flash time (0.1s)
		var remaining_duration = max(0.1, attack_animation_duration - ATTACK_TELEGRAPH_DURATION - 0.1)
		await get_tree().create_timer(remaining_duration).timeout

	# Reset attacking state
	is_attacking = false

	# Start attack cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


func show_area_attack_warning() -> void:
	# Create visual warning indicator for area attack
	if attack_warning_indicator:
		hide_area_attack_warning()
	
	# Create a circle indicator using Line2D (outline)
	var circle = Line2D.new()
	circle.z_index = 10  # Render above ground but below enemies
	circle.width = 3.0
	circle.default_color = Color(1.0, 0.2, 0.2, 0.8)  # Red with transparency
	
	# Generate circle points
	var points = PackedVector2Array()
	var segments = 64  # Smooth circle
	for i in range(segments + 1):
		var angle = (i / float(segments)) * TAU
		var point = Vector2(cos(angle), sin(angle)) * area_attack_radius
		points.append(point)
	
	circle.points = points
	circle.position = Vector2.ZERO  # Center on enemy
	add_child(circle)
	attack_warning_indicator = circle
	
	# Use existing AttackRangeArea from scene if it exists, otherwise create dynamically
	var area = get_node_or_null("AttackRangeArea")
	if not area:
		# Create collision area for visual debugging (fallback if not in scene)
		area = Area2D.new()
		area.name = "AttackRangeArea"
		area.position = Vector2.ZERO  # Center on enemy
		
		# Create collision shape
		var collision_shape = CollisionShape2D.new()
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = area_attack_radius
		collision_shape.shape = circle_shape
		area.add_child(collision_shape)
		
		# Create visual representation of collision (filled circle)
		var polygon = Polygon2D.new()
		polygon.z_index = 9  # Just below the outline
		polygon.color = Color(1.0, 0.2, 0.2, 0.3)  # Semi-transparent red fill
		
		# Generate filled circle polygon
		var polygon_points = PackedVector2Array()
		for i in range(segments):
			var angle = (i / float(segments)) * TAU
			var point = Vector2(cos(angle), sin(angle)) * area_attack_radius
			polygon_points.append(point)
		polygon.polygon = polygon_points
		area.add_child(polygon)
		
		add_child(area)
	else:
		# Update existing collision shape radius to match current attack radius
		var collision_shape = area.get_node_or_null("CollisionShape2D")
		if collision_shape and collision_shape.shape:
			if collision_shape.shape is CircleShape2D:
				collision_shape.shape.radius = area_attack_radius
		
		# Update polygon if it exists
		var polygon = area.get_node_or_null("Polygon2D")
		if polygon:
			# Regenerate polygon points for new radius
			var polygon_points = PackedVector2Array()
			for i in range(segments):
				var angle = (i / float(segments)) * TAU
				var point = Vector2(cos(angle), sin(angle)) * area_attack_radius
				polygon_points.append(point)
			polygon.polygon = polygon_points
	
	# Make the area visible
	area.visible = true
	attack_collision_area = area
	
	# Animate the warning (pulse effect)
	if warning_tween:
		warning_tween.kill()
	warning_tween = create_tween()
	warning_tween.set_loops()
	warning_tween.tween_property(circle, "modulate:a", 0.4, 0.3)
	warning_tween.tween_property(circle, "modulate:a", 0.8, 0.3)
	
	# Also animate the fill if polygon exists
	var polygon = area.get_node_or_null("Polygon2D")
	if polygon:
		var fill_tween = create_tween()
		fill_tween.set_loops()
		fill_tween.tween_property(polygon, "color:a", 0.2, 0.3)
		fill_tween.tween_property(polygon, "color:a", 0.3, 0.3)
	
	# Broadcast to all clients (only if server)
	if multiplayer.is_server():
		rpc("show_area_attack_warning_rpc")


@rpc("any_peer", "reliable", "call_local")
func show_area_attack_warning_rpc() -> void:
	# Only show on clients (server already showed it)
	if multiplayer.is_server():
		return
	
	show_area_attack_warning()


func hide_area_attack_warning() -> void:
	if warning_tween:
		warning_tween.kill()
		warning_tween = null
	
	if attack_warning_indicator:
		attack_warning_indicator.queue_free()
		attack_warning_indicator = null
	
	if attack_collision_area:
		# Hide the area instead of freeing it (so it stays in scene for editor visibility)
		attack_collision_area.visible = false
		# Only free if it was created dynamically (not from scene)
		if attack_collision_area.name == "AttackCollisionArea":
			attack_collision_area.queue_free()
		attack_collision_area = null
	
	# Broadcast to all clients (only if server)
	if multiplayer.is_server():
		rpc("hide_area_attack_warning_rpc")


@rpc("any_peer", "reliable", "call_local")
func hide_area_attack_warning_rpc() -> void:
	# Only hide on clients (server already hid it)
	if multiplayer.is_server():
		return
	
	hide_area_attack_warning()


func perform_area_attack() -> void:
	# Only server processes area attacks
	if not multiplayer.is_server():
		return
	
	# IMPORTANT: Use the stored attack position (where warning was shown), not current position
	# This ensures damage matches the warning circle, even if flyguy moved during the attack
	var attack_pos = area_attack_position
	if attack_pos == Vector2.ZERO:
		# Fallback to current position if somehow not set
		attack_pos = global_position
	
	var players = get_tree().get_nodes_in_group("players")
	var players_hit = 0
	
	# Debug: Log attack position and radius
	print("Flyguy ", name, " performing area attack at stored position ", attack_pos, " (current: ", global_position, ") with radius ", area_attack_radius)
	
	for player in players:
		if not is_instance_valid(player):
			continue
		
		# Skip dead players
		if "is_alive" in player and not player.is_alive:
			continue
		
		# Check distance from the stored attack position (where warning was shown)
		# Use the exact same calculation as the warning circle
		var distance_to_player = attack_pos.distance_to(player.global_position)
		
		# Debug: Log all player distances
		print("Flyguy ", name, " checking player ", player.name, " at ", player.global_position, " distance from attack pos: ", distance_to_player, " (radius: ", area_attack_radius, ")")
		
		# Use <= for inclusive check (same as warning circle boundary)
		if distance_to_player <= area_attack_radius:
			# Player is in range - hit them!
			if player.has_method("take_damage"):
				player.take_damage(attack_damage, self)
				players_hit += 1
				print("Flyguy ", name, " HIT player ", player.name, " at distance ", distance_to_player, " (within radius ", area_attack_radius, ")")
		else:
			# Player moved out of range during delay - they dodged!
			print("Flyguy ", name, " MISSED player ", player.name, " (distance: ", distance_to_player, " > radius: ", area_attack_radius, ")")
	
	if players_hit > 0:
		# Play hit sound when damage is dealt
		play_mushroom_hit_sound()
		print("Flyguy ", name, " area attack hit ", players_hit, " player(s)")
	else:
		# No players hit - attack missed!
		print("Flyguy ", name, " area attack MISSED! No players in range")
		spawn_miss_text()
	
	# Reset attack position
	area_attack_position = Vector2.ZERO


func spawn_miss_text() -> void:
	# Spawn "MISS!" text above enemy when attack misses
	var damage_scene = load("res://coop/scenes/damage_number.tscn")
	if damage_scene:
		var miss_instance = damage_scene.instantiate()
		miss_instance.global_position = global_position + Vector2(0, -40)
		
		# Add to scene
		get_tree().current_scene.add_child(miss_instance)
		
		# Set as miss text
		if miss_instance.has_method("set_miss_text"):
			miss_instance.set_miss_text()
		elif miss_instance.has_method("set_damage"):
			# Fallback: use damage text with special flag
			var label = miss_instance.get_node_or_null("Label")
			if label:
				label.text = "MISS!"
				label.add_theme_font_size_override("font_size", 18)
				label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))  # Gray


@rpc("any_peer", "reliable", "call_local")
func play_attack_animation() -> void:
	# SECURITY: Verify this RPC came from server
	if not validate_rpc_authority("play_attack_animation"):
		return

	# SECURITY: Rate limiting
	if not validate_rpc_rate_limit("play_attack_animation"):
		return

	# Play attack animation on all clients
	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
		# Ensure attack animation doesn't loop
		sprite.sprite_frames.set_animation_loop("attack", false)
		# Stop current animation and reset to ensure it plays from start
		sprite.stop()
		sprite.play("attack")


func _on_body_entered(body: Node2D) -> void:
	# Check if a player entered attack range
	if body.has_method("take_damage") and body.is_in_group("players"):
		is_in_attack_range = true
		print("Player entered attack range")


func _on_body_exited(body: Node2D) -> void:
	# Check if a player left attack range
	if body.has_method("take_damage") and body.is_in_group("players"):
		is_in_attack_range = false
		print("Player left attack range")


# Position sync is now handled automatically by MultiplayerSynchronizer
# Client-side interpolation provides smooth movement


func update_health_display() -> void:
	# Update the health bar display
	var health_bar = get_node_or_null("HealthBar")
	if health_bar:
		health_bar.update_health(current_health, max_health)


func update_animation() -> void:
	var sprite = get_node_or_null("AnimatedSprite2D")
	if not sprite:
		return

	# Helper function to check if animation exists
	var sprite_frames = sprite.sprite_frames
	if not sprite_frames:
		return

	if is_hit:
		if sprite.animation != "hit" and sprite_frames.has_animation("hit"):
			sprite.play("hit")
		return

	if is_attacking:
		if sprite_frames.has_animation("attack"):
			if sprite.animation != "attack":
				# Ensure attack animation doesn't loop
				sprite_frames.set_animation_loop("attack", false)
				sprite.play("attack")
		return

	# Update animation based on movement
	if velocity.length() > 0.1:
		# Moving - play walk animation
		if sprite_frames.has_animation("walk"):
			if sprite.animation != "walk":
				sprite.play("walk")
		elif sprite_frames.has_animation("run"):
			if sprite.animation != "run":
				sprite.play("run")
		else:
			# Fallback to idle if no walk/run animation
			if sprite.animation != "idle":
				sprite.play("idle")
	else:
		# Not moving - play idle animation
		if sprite.animation != "idle":
			sprite.play("idle")


func award_xp_to_killer() -> void:
	# Award XP to the team (team-based XP system)
	TeamXP.gain_xp(25)

	# Track individual kill stats for GameDirector
	if not last_attacker.is_empty() and multiplayer.is_server():
		var players = get_tree().get_nodes_in_group("players")
		for player in players:
			if str(player.name) == last_attacker or str(player.name.to_int()) == last_attacker:
				var peer_id = player.name.to_int()
				GameDirector.on_player_kill(peer_id)
				break


func apply_poison(damage_per_sec: int, duration: float) -> void:
	# Apply or refresh poison effect
	poison_damage = damage_per_sec
	poison_duration = duration
	poison_tick_timer = poison_tick_rate  # Apply first tick immediately on next frame


func spawn_damage_number(pos: Vector2, damage: int, is_crit: bool, is_poison: bool = false) -> void:
	# Spawn floating damage number (for poison and other passive damage)
	var damage_number_scene = preload("res://coop/scenes/damage_number.tscn")
	var damage_number = damage_number_scene.instantiate()
	
	# Position at enemy location
	damage_number.global_position = pos
	
	# Add to scene FIRST (this triggers _ready() which initializes the label reference)
	get_tree().current_scene.add_child(damage_number)
	
	# NOW set damage text and styling (after _ready() has been called)
	damage_number.set_damage(damage, is_crit, is_poison)


func play_mushroom_hit_sound() -> void:
	# Play enemy attack hit sound (configurable via export var)
	if attack_hit_sound_path.is_empty():
		return
		
	var attack_sound = load(attack_hit_sound_path)
	if attack_sound:
		var temp_sound = AudioStreamPlayer2D.new()
		temp_sound.stream = attack_sound
		temp_sound.bus = "SFX"
		temp_sound.position = global_position
		# Add to scene tree and play
		get_tree().current_scene.add_child(temp_sound)
		temp_sound.play()
		# Clean up after sound finishes
		temp_sound.finished.connect(func(): temp_sound.queue_free())
