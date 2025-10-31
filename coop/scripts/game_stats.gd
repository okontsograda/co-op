extends Node

# Game statistics tracking
var total_enemies_killed: int = 0
var total_coins_collected: int = 0
var highest_wave_reached: int = 1
var game_start_time: float = 0.0
var game_end_time: float = 0.0
var total_damage_dealt: int = 0
var total_damage_taken: int = 0
var bosses_killed: int = 0

# Per-player stats (for multiplayer)
var player_stats: Dictionary = {}  # {peer_id: {kills: int, coins: int, damage: int}}


func _ready() -> void:
	game_start_time = Time.get_ticks_msec() / 1000.0


func reset_stats() -> void:
	total_enemies_killed = 0
	total_coins_collected = 0
	highest_wave_reached = 1
	game_start_time = Time.get_ticks_msec() / 1000.0
	game_end_time = 0.0
	total_damage_dealt = 0
	total_damage_taken = 0
	bosses_killed = 0
	player_stats.clear()


func record_enemy_kill(is_boss: bool = false) -> void:
	total_enemies_killed += 1
	if is_boss:
		bosses_killed += 1


func record_coin_collected(amount: int = 1) -> void:
	total_coins_collected += amount


func record_wave_reached(wave: int) -> void:
	if wave > highest_wave_reached:
		highest_wave_reached = wave


func record_damage_dealt(amount: int) -> void:
	total_damage_dealt += amount


func record_damage_taken(amount: int) -> void:
	total_damage_taken += amount


# Sync all stats to a specific client (used when showing game over)
@rpc("any_peer", "reliable")
func sync_all_stats(enemies: int, coins: int, wave: int, damage_dealt: int, damage_taken: int, bosses: int) -> void:
	total_enemies_killed = enemies
	total_coins_collected = coins
	highest_wave_reached = wave
	total_damage_dealt = damage_dealt
	total_damage_taken = damage_taken
	bosses_killed = bosses


func get_time_survived() -> float:
	var end_time = game_end_time if game_end_time > 0 else Time.get_ticks_msec() / 1000.0
	return end_time - game_start_time


func get_time_survived_formatted() -> String:
	var time = get_time_survived()
	var minutes = int(time) / 60
	var seconds = int(time) % 60
	return "%d:%02d" % [minutes, seconds]


func finalize_stats() -> void:
	game_end_time = Time.get_ticks_msec() / 1000.0

