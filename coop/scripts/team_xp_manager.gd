extends Node

## Team XP Manager
## Manages shared XP pool and team-wide leveling
## Server-authoritative with RPC synchronization

# Signals
signal level_up_ready  # Emitted when team levels up
signal xp_changed(current_xp: int, xp_needed: int)
signal level_changed(new_level: int)

# Team XP State
var team_xp: int = 0
var team_level: int = 1
var xp_to_next_level: int = 100

# Constants
const BASE_XP_PER_LEVEL: int = 100
const XP_PER_ENEMY_KILL: int = 25

# Leveling sound
var level_up_sound: AudioStreamPlayer


func _ready() -> void:
	# Create level up sound player
	level_up_sound = AudioStreamPlayer.new()
	add_child(level_up_sound)

	# Load level up sound if it exists
	var sound_path = "res://sounds/level_up.wav"
	if ResourceLoader.exists(sound_path):
		level_up_sound.stream = load(sound_path)

	# Initialize XP requirement
	update_xp_requirement()


## Calculate XP requirement based on level and player count
## Formula: (BASE_XP_PER_LEVEL * level) * (1 + player_count * 0.5)
func calculate_xp_requirement(level: int, player_count: int) -> int:
	var base_requirement = BASE_XP_PER_LEVEL * level
	var scaling_multiplier = 1.0 + (player_count * 0.5)
	return int(base_requirement * scaling_multiplier)


## Get current number of active players
func get_player_count() -> int:
	var players = get_tree().get_nodes_in_group("players")
	return max(1, players.size())  # At least 1 to avoid division by zero


## Update XP requirement based on current state
func update_xp_requirement() -> void:
	var player_count = get_player_count()
	xp_to_next_level = calculate_xp_requirement(team_level, player_count)


## Gain XP (call this from anywhere, it will sync via RPC)
func gain_xp(amount: int) -> void:
	# Only server processes XP gains
	if multiplayer.is_server():
		_process_xp_gain(amount)
	else:
		# Clients request XP gain from server
		rpc_id(1, "request_xp_gain", amount)


## Server processes XP gain
func _process_xp_gain(amount: int) -> void:
	team_xp += amount

	# Check for level up (can level multiple times)
	while team_xp >= xp_to_next_level:
		_level_up()

	# Sync to all clients
	rpc("sync_team_xp", team_xp, team_level, xp_to_next_level)

	# Emit local signal
	xp_changed.emit(team_xp, xp_to_next_level)


## Handle team level up
func _level_up() -> void:
	# Roll over excess XP
	team_xp -= xp_to_next_level
	team_level += 1

	# Update XP requirement for next level
	update_xp_requirement()

	# Play sound
	if level_up_sound and level_up_sound.stream:
		level_up_sound.play()

	# Broadcast level up to all clients
	rpc("broadcast_level_up", team_level)

	# Emit signals
	level_changed.emit(team_level)
	level_up_ready.emit()


## RPC: Client requests XP gain from server
@rpc("any_peer", "reliable")
func request_xp_gain(amount: int) -> void:
	# Only server processes this
	if not multiplayer.is_server():
		return

	_process_xp_gain(amount)


## RPC: Sync team XP state to all clients
@rpc("authority", "reliable", "call_local")
func sync_team_xp(xp: int, level: int, xp_needed: int) -> void:
	team_xp = xp
	team_level = level
	xp_to_next_level = xp_needed

	xp_changed.emit(team_xp, xp_to_next_level)


## RPC: Broadcast level up to all clients
@rpc("authority", "reliable", "call_local")
func broadcast_level_up(new_level: int) -> void:
	team_level = new_level

	# Update XP requirement
	update_xp_requirement()

	# Play sound on clients
	if level_up_sound and level_up_sound.stream:
		level_up_sound.play()

	# Emit signals
	level_changed.emit(team_level)
	level_up_ready.emit()


## Get current team level
func get_team_level() -> int:
	return team_level


## Get current team XP
func get_team_xp() -> int:
	return team_xp


## Get XP needed for next level
func get_xp_to_next_level() -> int:
	return xp_to_next_level


## Reset team XP (for testing or new game)
func reset() -> void:
	if multiplayer.is_server():
		team_xp = 0
		team_level = 1
		update_xp_requirement()
		rpc("sync_team_xp", team_xp, team_level, xp_to_next_level)
