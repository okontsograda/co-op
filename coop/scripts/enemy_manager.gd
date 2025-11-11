extends Node

## EnemyManager - Centralized Enemy Spawning System
## Handles all enemy spawning with server authority and wave scaling
## Follows VFXManager pattern for clean API

# Enemy type registry
const enemy_types = {
	"mushroom": {
		"scene": "res://coop/scenes/enemy.tscn",
		"base_health": 50,
		"base_damage": 15,
		"base_speed": 80.0
	}
	# Future enemy types can be added here:
	# "goblin": { ... },
	# "skeleton": { ... },
}

# Enemy tracking
var enemy_id_counter: int = 0


func _ready() -> void:
	print("EnemyManager initialized")


## ============================================================================
## SERVER AUTHORITY: Spawn enemy with wave scaling
## ============================================================================

@rpc("authority", "reliable", "call_local")
func spawn_enemy(
	spawn_position: Vector2,
	enemy_type: String,
	enemy_size: int,
	wave_number: int = 1,
	is_boss: bool = false,
	boss_health: int = 0,
	boss_name: String = ""
) -> void:
	print("EnemyManager: Spawning ", enemy_type, " size:", enemy_size, " wave:", wave_number, " boss:", is_boss)

	# Get enemy config
	if not enemy_types.has(enemy_type):
		push_error("Unknown enemy type: ", enemy_type)
		return

	var config = enemy_types[enemy_type]

	# Generate unique enemy ID
	enemy_id_counter += 1
	var enemy_id = ("Boss_" if is_boss else "Enemy_") + str(enemy_id_counter)

	# Load and instantiate enemy scene
	var enemy_scene = load(config.scene)
	var enemy = enemy_scene.instantiate()

	# Set basic properties
	enemy.global_position = spawn_position
	enemy.name = enemy_id

	# Set enemy size before adding to scene
	if enemy.has_method("set_enemy_size"):
		enemy.set_enemy_size(enemy_size)

	# Apply wave scaling (if wave > 1)
	if wave_number > 1:
		var health_multiplier = _get_wave_health_multiplier(wave_number)
		var damage_multiplier = _get_wave_damage_multiplier(wave_number)

		if enemy.has_method("apply_wave_scaling"):
			enemy.apply_wave_scaling(health_multiplier, damage_multiplier)

	# Apply boss configuration
	if is_boss and boss_health > 0:
		if enemy.has_method("make_boss"):
			enemy.make_boss(boss_name, boss_health)

	# Add to scene
	get_tree().current_scene.add_child(enemy)

	print("EnemyManager: Spawned ", enemy_type, " with ID ", enemy_id)


## ============================================================================
## WAVE SCALING FORMULAS
## ============================================================================

func _get_wave_health_multiplier(wave: int) -> float:
	# Progressive health scaling
	# Wave 1: 1.0x, Wave 2: 1.15x, Wave 3: 1.32x, Wave 5: 1.75x, Wave 10: 3.05x
	return 1.0 + (wave - 1) * 0.15


func _get_wave_damage_multiplier(wave: int) -> float:
	# Progressive damage scaling (slower than health)
	# Wave 1: 1.0x, Wave 2: 1.08x, Wave 3: 1.17x, Wave 5: 1.35x, Wave 10: 1.79x
	return 1.0 + (wave - 1) * 0.08


## ============================================================================
## HELPER FUNCTIONS
## ============================================================================

## Get next available enemy ID
func get_next_enemy_id() -> String:
	enemy_id_counter += 1
	return "Enemy_" + str(enemy_id_counter)


## Get next available boss ID
func get_next_boss_id() -> String:
	enemy_id_counter += 1
	return "Boss_" + str(enemy_id_counter)
