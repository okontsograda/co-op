extends CharacterBody2D

const speed: float = 80.0  # Slower than players
const attack_range: float = 40.0  # Distance at which enemy can attack
const attack_damage: int = 15  # Damage per attack
const attack_cooldown: float = 1.5  # Time between attacks

const max_health: int = 50
var current_health: int = max_health
var target_player: Node2D = null
var can_attack: bool = true
var is_in_attack_range: bool = false
var last_sync_position: Vector2 = Vector2.ZERO
var last_attacker: String = ""  # Track who dealt the killing blow

func _ready() -> void:
	# Add to enemies group
	add_to_group("enemies")
	
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
		print("Enemy spawned on server at position: ", global_position)
	else:
		# On clients, set authority to 1 (server) so they sync from server
		set_multiplayer_authority(1)
		print("Enemy spawned on client at position: ", global_position)
	
	# Initialize sync position
	last_sync_position = global_position
	
	# Only initialize AI on server
	if not is_multiplayer_authority():
		return

func _physics_process(_delta: float) -> void:
	# Only process on server (authority)
	if not is_multiplayer_authority():
		return
	
	# Find nearest player
	find_target_player()
	
	# Check if target is in attack range
	if target_player:
		var distance_to_target = global_position.distance_to(target_player.global_position)
		is_in_attack_range = distance_to_target <= attack_range
		
		# Attack if in range
		if is_in_attack_range and can_attack:
			attack_target(target_player)
		
		# Move towards target if not in attack range
		if not is_in_attack_range:
			var direction = (target_player.global_position - global_position).normalized()
			velocity = direction * speed
			move_and_slide()
			
			# Flip sprite to face movement direction
			var sprite = get_node("AnimatedSprite2D")
			if sprite and direction.x != 0:
				sprite.flip_h = direction.x < 0
		else:
			# Stop moving when in attack range
			velocity = Vector2.ZERO
	else:
		# No target, stop moving
		velocity = Vector2.ZERO
		is_in_attack_range = false
	
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

func take_damage(amount: int, attacker: Node2D) -> void:
	print("take_damage called on enemy ", name, " (instance ID: ", get_instance_id(), ") for ", amount, " damage from ", attacker.name if attacker else "null")
	
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
	print("take_damage_rpc received on enemy ", name, " (instance ID: ", get_instance_id(), ") for ", amount, " damage, is_authority: ", is_multiplayer_authority())
	# Only process damage on server (authority)
	if not is_multiplayer_authority():
		print("Not authority, returning")
		return
	
	current_health -= amount
	print("Enemy took ", amount, " damage from ", attacker_name, ", health: ", current_health)
	
	# Track the attacker for XP purposes
	last_attacker = attacker_name
	
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
	queue_free()

func attack_target(target: Node2D) -> void:
	# Only attack if we can attack
	if not can_attack:
		return
	
	# Deal damage to the target
	if target.has_method("take_damage"):
		target.take_damage(attack_damage, self)
		print("Enemy attacked ", target.name, " for ", attack_damage, " damage")
	
	# Start attack cooldown
	can_attack = false
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

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
