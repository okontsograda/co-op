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
var last_sync_position: Vector2 = Vector2.ZERO
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

# Sound effects
var hit_sound_player: AudioStreamPlayer2D = null


func _ready() -> void:
	# Add to enemies group
	add_to_group("enemies")
	
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
		print("Enemy (", get_size_name(), ") spawned on server at position: ", global_position)
	else:
		# On clients, set authority to 1 (server) so they sync from server
		set_multiplayer_authority(1)
		print("Enemy (", get_size_name(), ") spawned on client at position: ", global_position)

	# Initialize sync position
	last_sync_position = global_position

	# Start with idle animation
	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.play("idle")

	# Set up hit sound
	setup_hit_sound()

	# Only initialize AI on server
	if not is_multiplayer_authority():
		return


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
	
	match enemy_size:
		EnemySize.SMALL:
			# Small enemies: Fast, low health, low damage
			speed = base_speed * 1.3  # 104
			max_health = int(base_health * 0.5)  # 25
			attack_damage = int(base_damage * 0.7)  # 10
			attack_range = base_range * 0.8  # 32
			attack_cooldown = base_cooldown * 0.8  # 1.2
			scale = Vector2.ONE * 0.7  # Smaller sprite
			
		EnemySize.MEDIUM:
			# Medium enemies: Balanced
			speed = base_speed  # 80
			max_health = base_health  # 50
			attack_damage = base_damage  # 15
			attack_range = base_range  # 40
			attack_cooldown = base_cooldown  # 1.5
			scale = Vector2.ONE * base_scale  # Normal sprite
			
		EnemySize.LARGE:
			# Large enemies: Slow, high health, high damage
			speed = base_speed * 0.7  # 56
			max_health = int(base_health * 2.5)  # 125
			attack_damage = int(base_damage * 1.8)  # 27
			attack_range = base_range * 1.2  # 48
			attack_cooldown = base_cooldown * 1.3  # 1.95
			scale = Vector2.ONE * 1.5  # Larger sprite
			
		EnemySize.HUGE:
			# Huge enemies: Very slow, very high health, very high damage (boss-like)
			speed = base_speed * 0.5  # 40
			max_health = int(base_health * 5.0)  # 250
			attack_damage = int(base_damage * 2.5)  # 37
			attack_range = base_range * 1.5  # 60
			attack_cooldown = base_cooldown * 1.5  # 2.25
			scale = Vector2.ONE * 2.0  # Much larger sprite
	
	# Set current health to max health
	current_health = max_health
	
	print("Enemy size set to ", get_size_name(), " - Health: ", max_health, ", Speed: ", speed, ", Damage: ", attack_damage)


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


func apply_wave_scaling(health_multiplier: float, damage_multiplier: float) -> void:
	# Apply progressive wave scaling to enemy stats
	max_health = int(max_health * health_multiplier)
	current_health = max_health
	attack_damage = int(attack_damage * damage_multiplier)
	
	print("Wave scaling applied - Health: ", max_health, ", Damage: ", attack_damage)


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
	
	print("Enemy converted to BOSS: ", boss_name, " with ", boss_health, " HP and ", attack_damage, " damage")


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

	# Only process on server (authority)
	if not is_multiplayer_authority():
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
			if not is_in_attack_range and not is_attacking:
				velocity = direction_to_target * speed
			else:
				# Stop moving when in attack range or attacking
				velocity = Vector2.ZERO
		else:
			# No target, stop moving
			velocity = Vector2.ZERO
			is_in_attack_range = false
			
	# Always call move_and_slide for proper physics handling
	move_and_slide()
	
	# Update z_index based on Y position for proper depth sorting
	z_index = int(global_position.y)

	# Update animation
	update_animation()

	# Sync position to clients via NetworkHandler (always sync every frame to ensure smooth movement)
	var distance_moved = global_position.distance_to(last_sync_position)
	if distance_moved > 0.5:  # Only sync if moved significantly to reduce bandwidth
		NetworkHandler.sync_enemy_position(name, global_position)
		last_sync_position = global_position


func find_target_player() -> void:
	var players = get_tree().get_nodes_in_group("players")
	if players.is_empty():
		target_player = null
		return

	# Find closest player (target all players, not just authoritative ones)
	var closest_distance = INF
	var closest_player = null

	for player in players:
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
	print("Knockback applied to enemy: ", knockback_velocity)


func take_damage(amount: int, attacker: Node2D) -> void:
	var attacker_name_str = "null"
	if attacker:
		attacker_name_str = str(attacker.name)
	print(
		"take_damage called on enemy ",
		name,
		" (instance ID: ",
		get_instance_id(),
		") for ",
		amount,
		" damage from ",
		attacker_name_str
	)

	# Only process damage on server instances
	if not is_multiplayer_authority():
		print("Client instance, ignoring damage")
		return

	var attacker_name = str(attacker.name) if attacker else "unknown"

	# Process damage directly on server
	print("Server instance, processing damage directly")
	take_damage_rpc(amount, attacker_name)


@rpc("any_peer", "reliable")
func take_damage_rpc(amount: int, attacker_name: String) -> void:
	print(
		"take_damage_rpc received on enemy ",
		name,
		" (instance ID: ",
		get_instance_id(),
		") for ",
		amount,
		" damage, is_authority: ",
		is_multiplayer_authority()
	)
	# Only process damage on server (authority)
	if not is_multiplayer_authority():
		print("Not authority, returning")
		return

	current_health -= amount
	print("Enemy took ", amount, " damage from ", attacker_name, ", health: ", current_health)

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

	if current_health <= 0:
		# Award XP to the killer before death
		award_xp_to_killer()
		# Notify NetworkHandler of enemy death for wave tracking
		NetworkHandler.on_enemy_died()
		# Broadcast death to all clients
		rpc("die_rpc")
	else:
		# Broadcast health update to all clients
		rpc("sync_health", current_health)


@rpc("any_peer", "reliable", "call_local")
func sync_health(health: int) -> void:
	current_health = health
	update_health_display()
	print("Enemy health synced to ", health)


@rpc("any_peer", "reliable", "call_local")
func die_rpc() -> void:
	print("Enemy died")
	# Immediately queue for deletion
	queue_free()


@rpc("any_peer", "reliable", "call_local")
func play_hit_animation() -> void:
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
		add_child(hit_sound_player)
	else:
		print("WARNING: No hit sound found. Tried: ", possible_names)


@rpc("any_peer", "reliable", "call_local")
func play_hit_sound() -> void:
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

	# Deal damage to the target immediately (or after a brief delay for visual timing)
	if target.has_method("take_damage"):
		# Small delay before dealing damage for better visual feedback
		await get_tree().create_timer(0.3).timeout
		if target and is_instance_valid(target):
			target.take_damage(attack_damage, self)
			print("Enemy attacked ", target.name, " for ", attack_damage, " damage")

	# Play attack animation
	rpc("play_attack_animation")
	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
		# Ensure attack animation doesn't loop
		sprite.sprite_frames.set_animation_loop("attack", false)
		sprite.play("attack")

	# Wait for attack animation to finish (use a fixed duration to prevent getting stuck)
	# Attack animations are typically short, so wait for a reasonable duration
	await get_tree().create_timer(0.8).timeout  # Wait for attack animation

	# Reset attacking state
	is_attacking = false

	# Start attack cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


@rpc("any_peer", "reliable", "call_local")
func play_attack_animation() -> void:
	# Play attack animation on all clients
	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
		# Ensure attack animation doesn't loop
		sprite.sprite_frames.set_animation_loop("attack", false)
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


# sync_position removed - now using NetworkHandler.sync_enemy_position


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
	# Find the player who killed this enemy and award XP
	if last_attacker.is_empty():
		return

	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if str(player.name) == last_attacker or str(player.name.to_int()) == last_attacker:
			print("Awarding XP to player ", player.name, " for killing enemy")
			player.gain_xp(25)  # Award 25 XP per kill
			break
