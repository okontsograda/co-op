extends Node

## ProjectileManager - Centralized Projectile Spawning System
## Handles all projectile spawning with server authority and client prediction
## Follows VFXManager pattern for clean API

# Projectile type registry
const projectile_configs = {
	"arrow": {
		"scene": "res://coop/scenes/arrow.tscn",
		"default_speed": 500.0,
		"trail": false
	},
	"rocket": {
		"scene": "res://coop/scenes/rocket.tscn",
		"default_speed": 300.0,
		"trail": true
	}
}

# RPC Security - Rate limiting
var rpc_rate_limits: Dictionary = {}
const RPC_MIN_INTERVAL: float = 0.05  # 50ms between projectile spawns


func _ready() -> void:
	print("ProjectileManager initialized")


## ============================================================================
## CLIENT PREDICTION: Spawn visual-only projectile for instant feedback
## ============================================================================

func spawn_visual_projectile(
	shooter: Node2D,
	target_pos: Vector2,
	projectile_type: String,
	weapon_stats: Dictionary
) -> void:
	print("ProjectileManager: Spawning VISUAL ", projectile_type)

	# Get projectile config
	if not projectile_configs.has(projectile_type):
		push_error("Unknown projectile type: ", projectile_type)
		return

	var config = projectile_configs[projectile_type]

	# Instantiate projectile
	var projectile_scene = load(config.scene)
	var projectile = projectile_scene.instantiate()

	# Mark as visual-only (no damage)
	projectile.is_visual_only = true
	projectile.shooter_peer_id = multiplayer.get_unique_id()

	# Apply stats from weapon
	_apply_weapon_stats(projectile, weapon_stats)

	# Initialize position and direction
	var spawn_pos = shooter.global_position
	if shooter.has_node("AnimatedSprite2D"):
		spawn_pos = shooter.get_node("AnimatedSprite2D").global_position

	var direction = (target_pos - spawn_pos).normalized()
	projectile.initialize(shooter, spawn_pos, target_pos)

	# Add to scene
	get_tree().current_scene.add_child(projectile)


## ============================================================================
## SERVER AUTHORITY: Spawn real projectile that deals damage
## ============================================================================

@rpc("any_peer", "call_local", "reliable")
func spawn_projectile(
	spawn_pos: Vector2,
	direction: Vector2,
	projectile_type: String,
	shooter_peer_id: int,
	weapon_stats: Dictionary
) -> void:
	print("ProjectileManager: spawn_projectile RPC called - type: ", projectile_type, " is_server: ", multiplayer.is_server())

	# Only server processes projectile spawning
	if not multiplayer.is_server():
		push_warning("Client attempted to call spawn_projectile directly")
		return

	print("ProjectileManager: Server processing spawn_projectile RPC")

	# Get actual sender (handle direct calls vs RPC)
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:  # Called directly, not via RPC
		sender_id = shooter_peer_id

	# SECURITY: Rate limiting
	if not _validate_rpc_rate_limit(sender_id, "spawn_projectile"):
		return

	# SECURITY: Validate vector bounds
	if not _validate_vector_bounds(spawn_pos) or not _validate_vector_bounds(direction):
		return

	# SECURITY: Validate direction is normalized
	if abs(direction.length() - 1.0) > 0.1:
		push_warning("Projectile direction not normalized: ", direction.length())
		return

	# Get projectile config
	if not projectile_configs.has(projectile_type):
		push_error("Unknown projectile type: ", projectile_type)
		return

	var config = projectile_configs[projectile_type]

	# Find shooter player
	var shooter = null
	for player in get_tree().get_nodes_in_group("players"):
		if player.name.to_int() == shooter_peer_id:
			shooter = player
			break

	if not shooter:
		push_warning("Could not find shooter player for peer ", shooter_peer_id)
		return

	# SECURITY: Validate spawn position is near shooter
	var distance_from_shooter = spawn_pos.distance_to(shooter.global_position)
	if distance_from_shooter > 100.0:
		push_warning("Projectile spawn too far from shooter: ", distance_from_shooter)
		return

	# Instantiate projectile
	var projectile_scene = load(config.scene)
	var projectile = projectile_scene.instantiate()

	# Mark as authoritative (deals damage)
	projectile.is_visual_only = false
	projectile.shooter_peer_id = shooter_peer_id

	# Apply stats from weapon
	_apply_weapon_stats(projectile, weapon_stats)

	# Initialize position and direction
	var target_pos = spawn_pos + direction * 1000.0
	projectile.initialize(shooter, spawn_pos, target_pos)

	# Add to scene
	get_tree().current_scene.add_child(projectile)

	print("ProjectileManager: Spawned authoritative ", projectile_type)


## ============================================================================
## HELPER FUNCTIONS
## ============================================================================

## Apply weapon stats to projectile
func _apply_weapon_stats(projectile: Node, stats: Dictionary) -> void:
	# Apply all stats from dictionary
	if stats.has("damage"):
		projectile.damage = stats.damage
	if stats.has("speed"):
		projectile.speed = stats.speed
	if stats.has("pierce_count"):
		projectile.pierce_remaining = stats.pierce_count
	if stats.has("crit_chance"):
		projectile.crit_chance = stats.crit_chance
	if stats.has("crit_multiplier"):
		projectile.crit_multiplier = stats.crit_multiplier
	if stats.has("explosion_chance"):
		projectile.explosion_chance = stats.explosion_chance
	if stats.has("explosion_radius"):
		projectile.explosion_radius = stats.explosion_radius
	if stats.has("explosion_damage"):
		projectile.explosion_damage = stats.explosion_damage
	if stats.has("lifesteal"):
		projectile.lifesteal = stats.lifesteal
	if stats.has("poison_damage"):
		projectile.poison_damage = stats.poison_damage
	if stats.has("poison_duration"):
		projectile.poison_duration = stats.poison_duration
	if stats.has("homing_strength"):
		projectile.homing_strength = stats.homing_strength

	# Set direction if provided
	if stats.has("direction"):
		projectile.direction = stats.direction


## ============================================================================
## SECURITY VALIDATION
## ============================================================================

func _validate_rpc_rate_limit(peer_id: int, rpc_name: String) -> bool:
	var current_time = Time.get_ticks_msec() / 1000.0

	# Initialize peer tracking
	if not rpc_rate_limits.has(peer_id):
		rpc_rate_limits[peer_id] = {}

	# Check if RPC was called too recently
	if rpc_rate_limits[peer_id].has(rpc_name):
		var time_since_last = current_time - rpc_rate_limits[peer_id][rpc_name]
		if time_since_last < RPC_MIN_INTERVAL:
			push_warning("RPC rate limit exceeded for ", rpc_name, " from peer ", peer_id)
			return false

	# Update last call time
	rpc_rate_limits[peer_id][rpc_name] = current_time
	return true


func _validate_vector_bounds(vec: Vector2, max_magnitude: float = 10000.0) -> bool:
	if vec.length_squared() > max_magnitude * max_magnitude:
		push_warning("Vector exceeds maximum bounds: ", vec)
		return false
	return true
