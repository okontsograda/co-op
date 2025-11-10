extends Node

## Game Director - AI Director for Dynamic Difficulty and Pacing
## Manages wave intensity, performance tracking, and adaptive spawning

# ============================================================================
# CONFIGURATION PARAMETERS
# ============================================================================

## Intensity Phase Durations (seconds)
const CALM_DURATION_MIN = 20.0
const CALM_DURATION_MAX = 30.0
const BUILDING_DURATION_MIN = 25.0
const BUILDING_DURATION_MAX = 40.0
const PEAK_DURATION_MIN = 15.0
const PEAK_DURATION_MAX = 30.0
const RELIEF_DURATION = 10.0

## Stress Thresholds
const STRESS_THRESHOLD_LOW = 0.3
const STRESS_THRESHOLD_MEDIUM = 0.5
const STRESS_THRESHOLD_HIGH = 0.7

## Player Count Scaling
const SCALING_1_PLAYER = 1.0
const SCALING_2_PLAYERS = 1.5
const SCALING_3_PLAYERS = 1.8
const SCALING_4_PLAYERS = 2.0

## Boss Wave Configuration
const BOSS_WAVE_INTERVAL = 5  # Boss wave every N waves
const BOSS_ENEMY_COUNT = 3  # Number of HUGE enemies in boss wave
const BOSS_MIN_HEALTH = 200
const BOSS_MAX_HEALTH = 500
const BOSS_SIZE = 3  # EnemySize.HUGE
const BOSS_NAMES: Array[String] = [
	"Gargantua", "Titan", "Colossus", "Behemoth", "Leviathan",
	"Juggernaut", "Goliath", "Destroyer", "Ravager", "Annihilator",
	"Dreadnought", "Obliterator", "Executioner", "Warlord", "Overlord",
	"Havoc", "Reaper", "Crusher", "Demolisher", "Decimator"
]

## Spawn Rate Multipliers (per intensity phase)
const SPAWN_RATE_CALM = 0.6
const SPAWN_RATE_BUILDING = 1.0
const SPAWN_RATE_PEAK = 1.5
const SPAWN_RATE_RELIEF = 0.3

## Performance Tracking Update Rate
const PERFORMANCE_UPDATE_INTERVAL = 1.0  # seconds

## Enemy Stat Scaling (Wave-Based)
const WAVE_HEALTH_SCALING = 0.05  # +5% health per wave
const WAVE_DAMAGE_SCALING = 0.02  # +2% damage per wave
const MAX_HEALTH_MULTIPLIER = 3.0  # Cap at 3x health
const MAX_DAMAGE_MULTIPLIER = 2.0  # Cap at 2x damage

## Wave System Configuration
const WAVE_COUNTDOWN_SECONDS = 5
const REST_WAVE_END_DELAY = 1.0
const PRE_COUNTDOWN_DELAY = 1.0
const DEFAULT_SPAWN_POSITIONS: Array[Vector2] = [
	Vector2(800, 200), Vector2(-800, 200),
	Vector2(800, -200), Vector2(-800, -200),
	Vector2(0, 600), Vector2(0, -600),
	Vector2(1200, 0), Vector2(-1200, 0)
]

# ============================================================================
# ENUMS
# ============================================================================

enum IntensityPhase {
	CALM,       # Slow start, easy enemies
	BUILDING,   # Gradual escalation
	PEAK,       # Maximum intensity
	RELIEF      # Wind down before wave end
}

enum SpecialEventType {
	NONE,
	BOSS_WAVE,      # Multiple HUGE enemies
	ELITE_SWARM,    # All enemies one size larger
	SPEED_CHALLENGE, # Faster enemies, bonus XP
	TANK_WAVE       # More Large/Huge enemies
}

enum WaveType {
	NORMAL,     # Standard combat wave
	BOSS,       # Boss wave (every 5 waves)
	REST        # Rest wave for shop/upgrades
}

# ============================================================================
# STATE VARIABLES
# ============================================================================

## Current intensity state
var current_intensity: IntensityPhase = IntensityPhase.CALM
var intensity_phase_timer: float = 0.0
var intensity_phase_duration: float = 0.0

## Current wave information
var current_wave: int = 1
var current_event: SpecialEventType = SpecialEventType.NONE

## Player tracking
var player_count: int = 1
var player_performance: Dictionary = {}  # peer_id -> performance data
var group_stress_level: float = 0.0

## Spawn control
var spawn_rate_multiplier: float = 1.0
var enemies_to_spawn_this_wave: int = 0
var enemies_spawned_count: int = 0

## Performance tracking timer
var performance_update_timer: float = 0.0

## Rest wave tracking
var waves_since_last_rest: int = 0
var rest_wave_threshold: int = 3  # Default, dynamically adjusted

## Debug mode
var debug_mode: bool = true

# ============================================================================
# SIGNALS
# ============================================================================

signal intensity_changed(new_intensity: IntensityPhase)
signal special_event_started(event_type: SpecialEventType)
signal spawn_rate_changed(new_multiplier: float)
signal stress_level_changed(new_stress: float)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	print("[GameDirector] Initialized")
	if debug_mode:
		print("[GameDirector] Debug mode enabled - Press F3 to toggle debug overlay")

func _process(delta):
	if not multiplayer.is_server():
		return

	# Update performance tracking
	performance_update_timer += delta
	if performance_update_timer >= PERFORMANCE_UPDATE_INTERVAL:
		performance_update_timer = 0.0
		update_performance_metrics()

	# Update intensity phase
	update_intensity_phase(delta)

# ============================================================================
# WAVE MANAGEMENT
# ============================================================================

## Called when starting a new wave
func start_wave(wave_number: int) -> void:
	current_wave = wave_number
	print("[GameDirector] Starting wave %d" % wave_number)

	# Determine special event
	current_event = determine_special_event(wave_number)
	if current_event != SpecialEventType.NONE:
		print("[GameDirector] Special event: %s" % SpecialEventType.keys()[current_event])
		special_event_started.emit(current_event)

	# Calculate enemy count with player scaling
	var base_count = get_base_enemy_count(wave_number)
	var scaled_count = apply_player_count_scaling(base_count)
	enemies_to_spawn_this_wave = scaled_count
	enemies_spawned_count = 0

	# Reset intensity to CALM
	transition_to_intensity(IntensityPhase.CALM)

	print("[GameDirector] Wave %d: %d enemies (base: %d, players: %d, scaling: %.1fx)" % [
		wave_number, scaled_count, base_count, player_count, get_player_scaling_multiplier()
	])

## Calculate base enemy count for a wave (before scaling)
func get_base_enemy_count(wave_number: int) -> int:
	# Original formula: 5 + (wave - 1) * 3
	# Wave 1: 5, Wave 2: 8, Wave 3: 11, etc.
	return 5 + (wave_number - 1) * 3

## Determine if this wave has a special event
func determine_special_event(wave_number: int) -> SpecialEventType:
	# Boss wave every N waves
	if wave_number % BOSS_WAVE_INTERVAL == 0:
		return SpecialEventType.BOSS_WAVE

	# Random special events for other waves (20% chance)
	if wave_number > 2 and randf() < 0.2:
		var events = [
			SpecialEventType.ELITE_SWARM,
			SpecialEventType.SPEED_CHALLENGE,
			SpecialEventType.TANK_WAVE
		]
		return events[randi() % events.size()]

	return SpecialEventType.NONE

## Called when wave completes
func on_wave_complete() -> void:
	print("[GameDirector] Wave %d complete - Stress level: %.1f%%" % [current_wave, group_stress_level * 100])

	# Increment waves since last rest (only called for combat waves, not rest waves)
	waves_since_last_rest += 1
	print("[GameDirector] Waves since last rest: %d" % waves_since_last_rest)

## Get the type for a specific wave number
func get_wave_type_for_wave(wave_number: int) -> WaveType:
	# Boss waves take priority
	if wave_number % BOSS_WAVE_INTERVAL == 0:
		return WaveType.BOSS

	# Check if rest wave should trigger
	if should_trigger_rest_wave():
		return WaveType.REST

	return WaveType.NORMAL

## Determine if a rest wave should occur based on dynamic factors
func should_trigger_rest_wave() -> bool:
	# Calculate dynamic threshold based on stress and difficulty
	calculate_rest_wave_frequency()

	# Trigger rest if we've reached threshold
	if waves_since_last_rest >= rest_wave_threshold:
		return true

	return false

## Calculate rest wave frequency based on player performance
func calculate_rest_wave_frequency() -> void:
	# Base frequency: 2-4 waves between rest periods
	var base_frequency = 3

	# Adjust based on stress level
	if group_stress_level >= STRESS_THRESHOLD_HIGH:
		# High stress = more frequent rests (every 2 waves)
		rest_wave_threshold = 2
	elif group_stress_level >= STRESS_THRESHOLD_MEDIUM:
		# Medium stress = normal frequency (every 3 waves)
		rest_wave_threshold = 3
	elif group_stress_level >= STRESS_THRESHOLD_LOW:
		# Low stress = less frequent rests (every 4 waves)
		rest_wave_threshold = 4
	else:
		# Very low stress = even less frequent (every 4-5 waves)
		rest_wave_threshold = 4

	# Early game (first 3 waves) always gets faster rest waves
	if current_wave <= 3:
		rest_wave_threshold = min(rest_wave_threshold, 2)

	print("[GameDirector] Rest wave threshold: %d (stress: %.2f, waves since rest: %d)" % [
		rest_wave_threshold, group_stress_level, waves_since_last_rest
	])

## Reset rest wave counter (called when rest wave starts)
func reset_rest_wave_counter() -> void:
	waves_since_last_rest = 0
	print("[GameDirector] Rest wave counter reset")

## Get random boss health within configured range
func get_boss_health() -> int:
	return randi_range(BOSS_MIN_HEALTH, BOSS_MAX_HEALTH)

## Get random boss name from configured list
func get_random_boss_name() -> String:
	return BOSS_NAMES[randi() % BOSS_NAMES.size()]

## Get boss size (always HUGE)
func get_boss_size() -> int:
	return BOSS_SIZE

## Check if current wave is a boss wave
func is_boss_wave() -> bool:
	return current_event == SpecialEventType.BOSS_WAVE

## Check if all spawned enemies have been killed
func check_all_enemies_killed() -> bool:
	# Only check if we've spawned enemies
	if enemies_spawned_count == 0:
		return false

	# Get current enemy count from scene
	var scene_tree = Engine.get_main_loop() as SceneTree
	if not scene_tree:
		return false

	var enemies_alive = scene_tree.get_nodes_in_group("enemies").size()

	# If we've spawned all enemies and none are alive, all are killed
	if enemies_spawned_count >= enemies_to_spawn_this_wave and enemies_alive == 0:
		return true

	return false

# ============================================================================
# INTENSITY MANAGEMENT
# ============================================================================

## Update intensity phase based on time and conditions
func update_intensity_phase(delta: float) -> void:
	intensity_phase_timer += delta

	# Check if all spawned enemies have been killed (early wave completion)
	# This handles cases where players kill enemies faster than expected
	if current_intensity != IntensityPhase.RELIEF:
		if check_all_enemies_killed():
			print("[GameDirector] All enemies killed early, transitioning to RELIEF")
			transition_to_intensity(IntensityPhase.RELIEF)
			return

	# Check if phase duration elapsed
	if intensity_phase_timer >= intensity_phase_duration:
		advance_to_next_intensity()

## Advance to the next intensity phase
func advance_to_next_intensity() -> void:
	match current_intensity:
		IntensityPhase.CALM:
			transition_to_intensity(IntensityPhase.BUILDING)
		IntensityPhase.BUILDING:
			transition_to_intensity(IntensityPhase.PEAK)
		IntensityPhase.PEAK:
			# Stay in PEAK if enemies remain, or go to RELIEF
			if enemies_spawned_count >= enemies_to_spawn_this_wave:
				transition_to_intensity(IntensityPhase.RELIEF)
			else:
				# Extend PEAK phase
				intensity_phase_timer = 0.0
				intensity_phase_duration = randf_range(PEAK_DURATION_MIN, PEAK_DURATION_MAX)
		IntensityPhase.RELIEF:
			# Relief ends when wave completes (handled externally)
			pass

## Transition to a specific intensity phase
func transition_to_intensity(phase: IntensityPhase) -> void:
	if current_intensity == phase:
		return

	current_intensity = phase
	intensity_phase_timer = 0.0

	# Set duration for this phase
	match phase:
		IntensityPhase.CALM:
			intensity_phase_duration = randf_range(CALM_DURATION_MIN, CALM_DURATION_MAX)
			spawn_rate_multiplier = SPAWN_RATE_CALM
		IntensityPhase.BUILDING:
			intensity_phase_duration = randf_range(BUILDING_DURATION_MIN, BUILDING_DURATION_MAX)
			spawn_rate_multiplier = SPAWN_RATE_BUILDING
		IntensityPhase.PEAK:
			intensity_phase_duration = randf_range(PEAK_DURATION_MIN, PEAK_DURATION_MAX)
			spawn_rate_multiplier = SPAWN_RATE_PEAK
		IntensityPhase.RELIEF:
			intensity_phase_duration = RELIEF_DURATION
			spawn_rate_multiplier = SPAWN_RATE_RELIEF

	print("[GameDirector] Intensity -> %s (duration: %.1fs, spawn rate: %.1fx)" % [
		IntensityPhase.keys()[phase], intensity_phase_duration, spawn_rate_multiplier
	])

	intensity_changed.emit(phase)
	spawn_rate_changed.emit(spawn_rate_multiplier)

## Get current spawn delay based on intensity
func get_spawn_delay() -> float:
	var base_delay = 0.5  # Original delay
	return base_delay / spawn_rate_multiplier

# ============================================================================
# PLAYER COUNT SCALING
# ============================================================================

## Update player count (call this when players join/leave)
func update_player_count(count: int) -> void:
	if player_count != count:
		player_count = count
		print("[GameDirector] Player count updated: %d (scaling: %.1fx)" % [count, get_player_scaling_multiplier()])

## Get scaling multiplier based on player count
func get_player_scaling_multiplier() -> float:
	match player_count:
		1: return SCALING_1_PLAYER
		2: return SCALING_2_PLAYERS
		3: return SCALING_3_PLAYERS
		_: return SCALING_4_PLAYERS  # 4 or more

## Apply player count scaling to enemy count
func apply_player_count_scaling(base_count: int) -> int:
	return int(ceil(base_count * get_player_scaling_multiplier()))

## Apply player count scaling to enemy health
func get_enemy_health_multiplier() -> float:
	# Slight HP boost in multiplayer to compensate for focus fire
	if player_count <= 1:
		return 1.0
	else:
		return 1.0 + (player_count - 1) * 0.2  # +20% HP per extra player

## Get wave-based health multiplier for enemy scaling
func get_wave_health_multiplier(wave: int) -> float:
	if wave <= 1:
		return 1.0
	var multiplier = 1.0 + ((wave - 1) * WAVE_HEALTH_SCALING)
	return min(multiplier, MAX_HEALTH_MULTIPLIER)

## Get wave-based damage multiplier for enemy scaling
func get_wave_damage_multiplier(wave: int) -> float:
	if wave <= 1:
		return 1.0
	var multiplier = 1.0 + ((wave - 1) * WAVE_DAMAGE_SCALING)
	return min(multiplier, MAX_DAMAGE_MULTIPLIER)

# ============================================================================
# PERFORMANCE TRACKING
# ============================================================================

## Initialize tracking for a player
func register_player(peer_id: int) -> void:
	player_performance[peer_id] = {
		"health_percent": 1.0,
		"max_health": 100,
		"current_health": 100,
		"deaths": 0,
		"kills": 0,
		"damage_taken_recent": 0.0,
		"time_since_damage": 0.0,
		"last_update": Time.get_ticks_msec() / 1000.0
	}
	print("[GameDirector] Registered player %d for tracking" % peer_id)

## Remove tracking for a player
func unregister_player(peer_id: int) -> void:
	player_performance.erase(peer_id)
	print("[GameDirector] Unregistered player %d" % peer_id)

## Update player health data
func update_player_health(peer_id: int, current_hp: float, max_hp: float) -> void:
	if not player_performance.has(peer_id):
		register_player(peer_id)

	var perf = player_performance[peer_id]
	var old_health = perf.current_health

	perf.current_health = current_hp
	perf.max_health = max_hp
	perf.health_percent = current_hp / max_hp if max_hp > 0 else 0.0

	# Track damage taken
	if current_hp < old_health:
		var damage = old_health - current_hp
		perf.damage_taken_recent += damage
		perf.time_since_damage = 0.0

## Called when a player dies
func on_player_death(peer_id: int) -> void:
	if player_performance.has(peer_id):
		player_performance[peer_id].deaths += 1
		print("[GameDirector] Player %d died (total deaths: %d)" % [peer_id, player_performance[peer_id].deaths])

## Called when a player kills an enemy
func on_player_kill(peer_id: int) -> void:
	if player_performance.has(peer_id):
		player_performance[peer_id].kills += 1

## Update all performance metrics
func update_performance_metrics() -> void:
	var total_health_percent = 0.0
	var total_recent_damage = 0.0
	var player_data_count = 0

	for peer_id in player_performance:
		var perf = player_performance[peer_id]

		# Decay recent damage over time
		perf.time_since_damage += PERFORMANCE_UPDATE_INTERVAL
		if perf.time_since_damage > 5.0:  # Damage older than 5s doesn't count
			perf.damage_taken_recent *= 0.5  # Decay

		total_health_percent += perf.health_percent
		total_recent_damage += perf.damage_taken_recent
		player_data_count += 1

	# Calculate group stress level (0.0 - 1.0)
	if player_data_count > 0:
		var avg_health = total_health_percent / player_data_count
		var damage_stress = min(total_recent_damage / 200.0, 1.0)  # Normalize damage

		# Stress is combination of low health and recent damage
		group_stress_level = (1.0 - avg_health) * 0.6 + damage_stress * 0.4
		group_stress_level = clamp(group_stress_level, 0.0, 1.0)

		stress_level_changed.emit(group_stress_level)

## Get current group stress level
func get_stress_level() -> float:
	return group_stress_level

## Get stress category for display
func get_stress_category() -> String:
	if group_stress_level < STRESS_THRESHOLD_LOW:
		return "LOW"
	elif group_stress_level < STRESS_THRESHOLD_MEDIUM:
		return "MEDIUM"
	elif group_stress_level < STRESS_THRESHOLD_HIGH:
		return "HIGH"
	else:
		return "CRITICAL"

# ============================================================================
# SPAWN DECISION LOGIC
# ============================================================================

## Get the enemy size for the next spawn
func get_next_enemy_size() -> int:
	# Apply special event modifiers
	match current_event:
		SpecialEventType.BOSS_WAVE:
			# Boss waves spawn more HUGE enemies
			if enemies_spawned_count < BOSS_ENEMY_COUNT:
				return 3  # HUGE
			else:
				return get_standard_enemy_size()

		SpecialEventType.ELITE_SWARM:
			# All enemies one size larger
			var base_size = get_standard_enemy_size()
			return min(base_size + 1, 3)  # Cap at HUGE

		SpecialEventType.TANK_WAVE:
			# More large/huge enemies
			return get_tank_wave_size()

		_:
			return get_standard_enemy_size()

## Standard enemy size distribution (original logic)
func get_standard_enemy_size() -> int:
	var wave_factor = floor(current_wave / 3.0)

	# Adjust probabilities based on wave
	var small_chance = max(0.3 - wave_factor * 0.05, 0.1)
	var medium_chance = max(0.5 - wave_factor * 0.05, 0.3)
	var large_chance = min(0.15 + wave_factor * 0.05, 0.35)
	# huge_chance is remainder

	var roll = randf()

	if roll < small_chance:
		return 0  # SMALL
	elif roll < small_chance + medium_chance:
		return 1  # MEDIUM
	elif roll < small_chance + medium_chance + large_chance:
		return 2  # LARGE
	else:
		return 3  # HUGE

## Tank wave size distribution (more heavy enemies)
func get_tank_wave_size() -> int:
	var roll = randf()

	if roll < 0.1:
		return 0  # SMALL (10%)
	elif roll < 0.3:
		return 1  # MEDIUM (20%)
	elif roll < 0.7:
		return 2  # LARGE (40%)
	else:
		return 3  # HUGE (30%)

## Check if we should spawn more enemies this wave
func should_spawn_enemy() -> bool:
	return enemies_spawned_count < enemies_to_spawn_this_wave

## Called when an enemy is spawned
func on_enemy_spawned() -> void:
	enemies_spawned_count += 1

# ============================================================================
# DEBUG DATA (for debug overlay)
# ============================================================================

## Get debug data for display
func get_debug_data() -> Dictionary:
	return {
		"intensity": IntensityPhase.keys()[current_intensity],
		"intensity_timer": intensity_phase_timer,
		"intensity_duration": intensity_phase_duration,
		"intensity_progress": intensity_phase_timer / intensity_phase_duration if intensity_phase_duration > 0 else 0,
		"wave": current_wave,
		"event": SpecialEventType.keys()[current_event],
		"player_count": player_count,
		"scaling_multiplier": get_player_scaling_multiplier(),
		"stress_level": group_stress_level,
		"stress_category": get_stress_category(),
		"spawn_rate": spawn_rate_multiplier,
		"enemies_spawned": enemies_spawned_count,
		"enemies_total": enemies_to_spawn_this_wave,
		"spawn_progress": float(enemies_spawned_count) / enemies_to_spawn_this_wave if enemies_to_spawn_this_wave > 0 else 0,
		"player_performance": player_performance,
		"next_wave_type": WaveType.keys()[get_wave_type_for_wave(current_wave + 1)],
		"waves_since_rest": waves_since_last_rest,
		"rest_threshold": rest_wave_threshold
	}

## Get intensity color for debug display
func get_intensity_color() -> Color:
	match current_intensity:
		IntensityPhase.CALM:
			return Color(0.3, 0.8, 0.3)  # Green
		IntensityPhase.BUILDING:
			return Color(0.8, 0.8, 0.3)  # Yellow
		IntensityPhase.PEAK:
			return Color(0.9, 0.3, 0.3)  # Red
		IntensityPhase.RELIEF:
			return Color(0.3, 0.6, 0.9)  # Blue
		_:
			return Color.WHITE
