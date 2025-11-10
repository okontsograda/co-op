extends Area2D

# Rocket stats (set by player when spawned)
var damage: float = 25.0  # Higher base damage than arrows
var speed: float = 300.0  # Slower than arrows
var direction: Vector2 = Vector2.RIGHT
var pierce_remaining: int = 0
var crit_chance: float = 0.0
var crit_multiplier: float = 2.0
var explosion_chance: float = 1.0  # Rockets ALWAYS explode by default
var explosion_radius: float = 50.0  # Larger explosion radius than arrows
var explosion_damage: float = 20.0  # Guaranteed AoE damage
var lifesteal: int = 0
var poison_damage: int = 0
var poison_duration: float = 0.0
var homing_strength: float = 0.0

# Tracking
var enemies_hit: Array = []  # For pierce tracking
var has_hit: bool = false

# Multiplayer authority
var is_visual_only: bool = false  # Client visual projectiles don't deal damage
var shooter_peer_id: int = 0  # ID of player who shot this rocket

# Rocket-specific
var trail_particles: GPUParticles2D = null


func _ready() -> void:
	# Connect to body entered signal
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	# Connect to visibility notifier
	var visibility = get_node_or_null("VisibilityNotifier2D")
	if visibility:
		visibility.screen_exited.connect(_on_screen_exited)

	# Get trail particles reference
	trail_particles = get_node_or_null("TrailParticles")
	if trail_particles:
		trail_particles.emitting = true


func _physics_process(delta: float) -> void:
	if has_hit:
		return

	# Homing behavior (rockets track better than arrows)
	if homing_strength > 0:
		var nearest_enemy = find_nearest_enemy()
		if nearest_enemy:
			var to_enemy = (nearest_enemy.global_position - global_position).normalized()
			direction = direction.lerp(to_enemy, homing_strength * delta * 8.0)  # 8x multiplier (stronger than arrows)
			rotation = direction.angle()

	# Move the rocket in its direction
	global_position += direction * speed * delta


# Find nearest enemy for homing
func find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist = INF

	for enemy in enemies:
		if enemy in enemies_hit:  # Skip already hit enemies
			continue

		var dist = global_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	return nearest


func _on_body_entered(body: Node2D) -> void:
	# Don't hit the player who fired it
	if body == get_meta("shooter", null):
		return

	# Skip if already hit this enemy (pierce tracking)
	if body in enemies_hit:
		return

	# Don't hit other players (no friendly fire)
	if body.is_in_group("players"):
		return

	# Visual-only projectiles don't deal damage (client prediction)
	if is_visual_only:
		# Still destroy on hit for visual feedback
		if trail_particles:
			trail_particles.emitting = false
		has_hit = true
		queue_free()
		return

	# Only server processes actual hits
	if not multiplayer.is_server():
		return

	# Check if we hit something that can take damage
	if body.has_method("take_damage"):
		var shooter = get_meta("shooter", null)

		# Track this enemy
		enemies_hit.append(body)

		# Calculate damage
		var final_damage = damage

		# Critical hit check
		var is_crit = randf() < crit_chance
		if is_crit:
			final_damage *= crit_multiplier

		# Server applies damage (enemy.take_damage already validates authority)
		body.take_damage(final_damage, shooter)

		# Lifesteal (server-authoritative healing)
		if lifesteal > 0 and shooter and shooter.has_method("heal"):
			shooter.heal(lifesteal)

		# Poison application
		if poison_damage > 0 and body.has_method("apply_poison"):
			body.apply_poison(poison_damage, poison_duration)

		# Explosion (rockets always explode unless explosion_chance is manually set to 0)
		if randf() < explosion_chance:
			call_deferred("create_explosion")

		# Pierce check - destroy rocket only if no pierce remaining
		if pierce_remaining > 0:
			pierce_remaining -= 1
			return  # Don't destroy rocket, let it continue

	# Destroy rocket (no pierce remaining or hit non-damageable object)
	# Stop trail particles before destroying
	if trail_particles:
		trail_particles.emitting = false

	has_hit = true
	queue_free()


## All clients show VFX for rocket hit
@rpc("authority", "reliable", "call_local")
func show_rocket_hit(enemy_name: String, hit_position: Vector2, damage_amount: float, is_crit: bool) -> void:
	# Spawn damage number
	spawn_damage_number(hit_position, damage_amount, is_crit)


## All clients show VFX for explosion hits
@rpc("authority", "reliable", "call_local")
func show_explosion_hits(hits: Array) -> void:
	# Show damage numbers for all explosion hits
	for hit in hits:
		spawn_damage_number(hit.position, hit.damage, false)


# Create explosion effect and deal AoE damage (server-only)
func create_explosion() -> void:
	# Only server processes explosions
	if not multiplayer.is_server():
		return

	# Spawn explosion visual effect
	var explosion_scene = preload("res://coop/scenes/explosion.tscn")
	if explosion_scene:
		var explosion_visual = explosion_scene.instantiate()
		explosion_visual.global_position = global_position
		get_tree().current_scene.add_child(explosion_visual)

	# Create Area2D for explosion detection
	var explosion_area = Area2D.new()
	explosion_area.global_position = global_position

	# Add collision shape for explosion radius
	var collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = explosion_radius
	collision_shape.shape = circle
	explosion_area.add_child(collision_shape)

	# Add to scene temporarily
	get_tree().current_scene.add_child(explosion_area)

	# Wait one frame for physics to update
	await get_tree().process_frame

	# Get all bodies in explosion radius
	var bodies_in_explosion = explosion_area.get_overlapping_bodies()

	var shooter = get_meta("shooter", null)
	var explosion_dmg = explosion_damage if explosion_damage > 0 else damage * 0.75

	# Deal damage to all enemies in radius
	for body in bodies_in_explosion:
		if body == shooter:  # Don't damage shooter
			continue

		if body.has_method("take_damage") and body.is_in_group("enemies"):
			# Server applies damage (enemy will broadcast its own damage number)
			body.take_damage(explosion_dmg, shooter)

	# Clean up explosion area
	explosion_area.queue_free()


func _on_screen_exited() -> void:
	# Stop trail particles before removing
	if trail_particles:
		trail_particles.emitting = false
	# Remove rocket when it leaves the screen
	queue_free()


func get_shooter() -> Node2D:
	# Return the shooter for enemy collision detection
	return get_meta("shooter", null)


func initialize(shooter: Node2D, start_pos: Vector2, target_pos: Vector2) -> void:
	# Set shooter metadata
	set_meta("shooter", shooter)

	# Position rocket
	global_position = start_pos

	# Calculate direction to target
	direction = (target_pos - start_pos).normalized()

	# Rotate rocket to face direction
	rotation = direction.angle()


# Spawn floating damage number
func spawn_damage_number(pos: Vector2, damage_amount: float, is_crit: bool) -> void:
	var damage_number_scene = preload("res://coop/scenes/damage_number.tscn")
	var damage_number = damage_number_scene.instantiate()

	# Position at hit location
	damage_number.global_position = pos

	# Add to scene FIRST (this triggers _ready() which initializes the label reference)
	get_tree().current_scene.add_child(damage_number)

	# NOW set damage text and styling (after _ready() has been called)
	damage_number.set_damage(damage_amount, is_crit, false)
