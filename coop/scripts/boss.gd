extends CharacterBody2D

# Boss-specific stats
var speed: float = 40.0  # Boss moves slower
const attack_range: float = 50.0  # Boss has slightly larger attack range
const attack_damage: int = 20  # Boss deals more damage
const attack_cooldown: float = 2.0  # Boss attacks slower

var max_health: int = 1500  # Boss has much more health
var current_health: int = max_health
var target_player: Node2D = null
var can_attack: bool = true
var is_in_attack_range: bool = false
var last_sync_position: Vector2 = Vector2.ZERO
var last_attacker: String = ""  # Track who dealt the killing blow

# Animation variables
var animated_sprite: AnimatedSprite2D
var is_attacking: bool = false
var is_hurt: bool = false
var hurt_timer: float = 0.0
const hurt_duration: float = 0.5  # Duration to show hurt animation

func _ready() -> void:
	# Add to enemies group
	add_to_group("enemies")
	
	# Get the animated sprite reference
	animated_sprite = get_node("AnimatedSprite2D")
	
	print("Boss spawned with ", max_health, " health and speed ", speed)
	
	# Connect Area2D signals for attack detection
	var area = get_node("Area2D")
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
	
	# Initialize health bar
	update_health_display()
	
	# Set authority to server only when we're on the server
	if multiplayer.is_server():
		# On server, set authority to 1 (server) and run AI
		set_multiplayer_authority(1)
		print("Boss spawned on server at position: ", global_position)
	else:
		# On clients, set authority to 1 (server) so they sync from server
		set_multiplayer_authority(1)
		print("Boss spawned on client at position: ", global_position)
	
	# Initialize sync position
	last_sync_position = global_position
	
	# Only initialize AI on server
	if not is_multiplayer_authority():
		return

func _physics_process(_delta: float) -> void:
	# Handle hurt animation timer
	if is_hurt:
		hurt_timer -= _delta
		if hurt_timer <= 0:
			is_hurt = false
	
	# Only process on server (authority)
	if not is_multiplayer_authority():
		return
	
	# Find closest player
	find_closest_player()
	
	if target_player:
		# Calculate distance to target
		var distance_to_target = global_position.distance_to(target_player.global_position)
		var attack_range = 50.0  # Attack range
		
		# Move towards target player if not in attack range
		if distance_to_target > attack_range:
			var direction = (target_player.global_position - global_position).normalized()
			velocity = direction * speed
			move_and_slide()
		else:
			# Stop moving if in attack range
			velocity = Vector2.ZERO
		
		# Update animation based on state
		update_animation()
		
		# Sync position to clients
		if global_position.distance_to(last_sync_position) > 5.0:
			NetworkHandler.sync_enemy_position(name, global_position)
			last_sync_position = global_position
		
		# Sync sprite direction to clients
		if velocity.length() > 0.1:
			rpc("sync_sprite_direction", velocity.x > 0)
		
		# Attack if in range
		if is_in_attack_range and can_attack:
			attack_target(target_player)
	else:
		# No target, play idle animation
		if animated_sprite and animated_sprite.animation != "default":
			animated_sprite.play("default")

func find_closest_player() -> void:
	var players = get_tree().get_nodes_in_group("players")
	var closest_distance = INF
	var closest_player = null
	
	for player in players:
		var distance = global_position.distance_to(player.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_player = player
	
	target_player = closest_player

func update_animation() -> void:
	if not animated_sprite:
		return
	
	# Handle sprite flipping based on movement direction
	if velocity.length() > 0.1:
		if velocity.x > 0:
			animated_sprite.flip_h = false  # Face right
		elif velocity.x < 0:
			animated_sprite.flip_h = true   # Face left
	
	# Priority: hurt > attack > walk > idle
	if is_hurt:
		if animated_sprite.animation != "hurt":
			animated_sprite.play("hurt")
	elif is_attacking:
		if animated_sprite.animation != "attack":
			animated_sprite.play("attack")
	elif velocity.length() > 0.1:
		if animated_sprite.animation != "walk":
			animated_sprite.play("walk")
	else:
		if animated_sprite.animation != "default":
			animated_sprite.play("default")

func take_damage(amount: int, attacker: Node2D) -> void:
	print("take_damage called on boss ", name, " (instance ID: ", get_instance_id(), ") for ", amount, " damage from ", attacker.name if attacker else "null")
	
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
	print("take_damage_rpc received on boss ", name, " (instance ID: ", get_instance_id(), ") for ", amount, " damage, is_authority: ", is_multiplayer_authority())
	# Only process damage on server (authority)
	if not is_multiplayer_authority():
		print("Not authority, returning")
		return
	
	current_health -= amount
	print("Boss took ", amount, " damage from ", attacker_name, ", health: ", current_health)
	
	# Track the attacker for XP purposes
	last_attacker = attacker_name
	
	# Trigger hurt animation
	is_hurt = true
	hurt_timer = hurt_duration
	
	# Sync hurt animation to all clients
	rpc("sync_hurt_animation")
	
	# Update health bar locally
	update_health_display()
	
	if current_health <= 0:
		# Award XP to the killer before death
		award_xp_to_killer()
		# Notify NetworkHandler of boss death
		NetworkHandler.on_boss_died()
		# Broadcast death to all clients
		rpc("die_rpc")
	else:
		# Broadcast health update to all clients
		rpc("sync_health", current_health)

@rpc("any_peer", "reliable", "call_local")
func sync_health(health: int) -> void:
	current_health = health
	update_health_display()
	print("Boss health synced to ", health)

@rpc("any_peer", "reliable", "call_local")
func sync_sprite_direction(facing_right: bool) -> void:
	if animated_sprite:
		animated_sprite.flip_h = not facing_right
		print("Boss sprite direction synced: ", "right" if facing_right else "left")

@rpc("any_peer", "reliable", "call_local")
func sync_hurt_animation() -> void:
	is_hurt = true
	hurt_timer = hurt_duration
	print("Boss hurt animation synced")

@rpc("any_peer", "reliable", "call_local")
func sync_attack_animation() -> void:
	is_attacking = true
	print("Boss attack animation synced")

@rpc("any_peer", "reliable", "call_local")
func die_rpc() -> void:
	print("Boss died")
	queue_free()

func attack_target(target: Node2D) -> void:
	# Only attack if we can attack
	if not can_attack:
		return
	
	# Set attacking state
	is_attacking = true
	
	# Sync attack animation to all clients
	rpc("sync_attack_animation")
	
	# Deal damage to the target
	if target.has_method("take_damage"):
		target.take_damage(attack_damage, self)
		print("Boss attacked ", target.name, " for ", attack_damage, " damage")
	
	# Start attack cooldown
	can_attack = false
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
	is_attacking = false

func _on_body_entered(body: Node2D) -> void:
	# Check if a player entered attack range
	if body.has_method("take_damage") and body.is_in_group("players"):
		is_in_attack_range = true
		print("Player entered boss attack range")

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("take_damage") and body.is_in_group("players"):
		is_in_attack_range = false
		print("Player left boss attack range")

func update_health_display() -> void:
	# Update the health bar display
	var health_bar = get_node_or_null("HealthBar")
	if health_bar:
		health_bar.update_health(current_health, max_health)

func award_xp_to_killer() -> void:
	# Find the player who killed this boss and award XP
	if last_attacker.is_empty():
		return
	
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if str(player.name) == last_attacker or str(player.name.to_int()) == last_attacker:
			print("Awarding XP to player ", player.name, " for killing boss")
			player.gain_xp(100)  # Award 100 XP for killing boss
			break
