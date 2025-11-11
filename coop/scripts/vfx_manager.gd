extends Node

## VFXManager - Centralized Visual Effects System
## Handles all combat VFX (damage numbers, explosions, particles)
## Decouples VFX from entity lifetimes for reliability

# Preload VFX scenes for performance
const DAMAGE_NUMBER_SCENE = preload("res://coop/scenes/damage_number.tscn")

# VFX pools (for future optimization)
var damage_number_pool: Array = []
const POOL_SIZE: int = 20


func _ready() -> void:
	print("VFXManager initialized")
	# Defer pool creation until scene is ready
	call_deferred("_populate_damage_number_pool")


## Pre-create damage numbers for reuse
func _populate_damage_number_pool() -> void:
	# Skip if already populated
	if damage_number_pool.size() > 0:
		return

	# Wait for scene tree to be ready
	if not get_tree() or not get_tree().current_scene:
		return

	for i in range(POOL_SIZE):
		var dmg_number = DAMAGE_NUMBER_SCENE.instantiate()
		dmg_number.visible = false
		dmg_number.z_index = 100  # Render on top
		damage_number_pool.append(dmg_number)
		# Add to current scene, NOT to VFXManager (so they can render)
		get_tree().current_scene.add_child(dmg_number)


## ============================================================================
## DAMAGE NUMBER VFX
## ============================================================================

## Spawn damage number at position (called via RPC from server)
@rpc("authority", "reliable", "call_local")
func spawn_damage_number(position: Vector2, damage_amount: float, is_crit: bool) -> void:
	# Server-only: verify authority
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != 0 and sender_id != 1 and not multiplayer.is_server():
		push_warning("VFXManager: Unauthorized spawn_damage_number from peer ", sender_id)
		return

	# Lazy initialization: Create pool if not already created
	if damage_number_pool.size() == 0:
		_populate_damage_number_pool()

	# Get or create damage number
	var damage_number = _get_damage_number_from_pool()
	if not damage_number:
		# Pool exhausted, create new
		damage_number = DAMAGE_NUMBER_SCENE.instantiate()
		damage_number.z_index = 100  # Render on top
		get_tree().current_scene.add_child(damage_number)
	else:
		# Reset pooled damage number before reuse
		if damage_number.has_method("reset"):
			damage_number.reset()

	# Position and configure
	damage_number.global_position = position
	damage_number.visible = true
	damage_number.z_index = 100  # Render on top of everything

	# Set damage styling
	if damage_number.has_method("set_damage"):
		damage_number.set_damage(damage_amount, is_crit, false)


## Get available damage number from pool
func _get_damage_number_from_pool() -> Node:
	# Clean up any invalid references and find available damage number
	var valid_pool = []
	for dmg in damage_number_pool:
		# Check if node is still valid (not freed)
		if not is_instance_valid(dmg):
			continue  # Skip freed nodes

		valid_pool.append(dmg)

		# Return if found invisible (available) damage number
		if not dmg.visible:
			return dmg

	# Update pool to only contain valid references
	damage_number_pool = valid_pool

	return null


## Return damage number to pool (called by damage_number when done)
func return_to_pool(damage_number: Node) -> void:
	if damage_number in damage_number_pool:
		# Reset state for reuse
		damage_number.visible = false
		damage_number.global_position = Vector2.ZERO

		# Reset damage number's internal state
		if damage_number.has_method("reset"):
			damage_number.reset()


## ============================================================================
## EXPLOSION VFX
## ============================================================================

## Spawn explosion visual at position
@rpc("authority", "reliable", "call_local")
func spawn_explosion(position: Vector2, radius: float) -> void:
	# Server-only: verify authority
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != 0 and sender_id != 1 and not multiplayer.is_server():
		push_warning("VFXManager: Unauthorized spawn_explosion from peer ", sender_id)
		return

	# Try to load explosion scene
	var explosion_scene = load("res://coop/scenes/explosion.tscn")
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.global_position = position
		get_tree().current_scene.add_child(explosion)

		# Scale based on radius
		var scale_factor = radius / 50.0  # Normalize to default radius
		explosion.scale = Vector2(scale_factor, scale_factor)

	print("VFXManager: Spawned explosion at ", position, " with radius ", radius)


## ============================================================================
## HIT EFFECTS
## ============================================================================

## Spawn hit particle effect
@rpc("authority", "reliable", "call_local")
func spawn_hit_effect(position: Vector2, hit_type: String = "normal") -> void:
	# Server-only: verify authority
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != 0 and sender_id != 1 and not multiplayer.is_server():
		push_warning("VFXManager: Unauthorized spawn_hit_effect from peer ", sender_id)
		return

	# TODO: Implement hit particle effects based on type
	# For now, just a placeholder
	print("VFXManager: Spawned ", hit_type, " hit effect at ", position)


## ============================================================================
## HEALING VFX
## ============================================================================

## Spawn healing number at position
@rpc("authority", "reliable", "call_local")
func spawn_healing_number(position: Vector2, heal_amount: int) -> void:
	# Server-only: verify authority
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != 0 and sender_id != 1 and not multiplayer.is_server():
		push_warning("VFXManager: Unauthorized spawn_healing_number from peer ", sender_id)
		return

	# Spawn damage number in healing mode (green)
	var damage_number = DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.global_position = position
	get_tree().current_scene.add_child(damage_number)

	# Set as healing (green, positive number)
	if damage_number.has_method("set_damage"):
		damage_number.set_damage(heal_amount, false, true)  # Third param = is_healing

	print("VFXManager: Spawned healing number at ", position, " for ", heal_amount, " HP")
