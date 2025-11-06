extends Node

# Save file path - Godot stores user data in a platform-specific location
# Windows: %APPDATA%\Godot\app_userdata\Co-op\
# Linux: ~/.local/share/godot/app_userdata/Co-op/
# macOS: ~/Library/Application Support/Godot/app_userdata/Co-op/
const SAVE_FILE_PATH = "user://save_data.json"

# Player data structure
var player_data = {
	"player_name": "Player",  # Default name
	"total_playtime": 0.0,  # Total time played in seconds
	"games_played": 0,  # Number of games played
	"total_kills": 0,  # Lifetime enemy kills
	"highest_wave": 0,  # Highest wave reached
	"total_coins_earned": 0,  # Lifetime coins earned
	"settings": {
		"master_volume": 1.0,
		"music_volume": 1.0,
		"sfx_volume": 1.0
	}
}

# Flag to track if data has been loaded
var is_loaded: bool = false

# Signal emitted when player data is loaded
signal data_loaded
signal data_saved


func _ready() -> void:
	print("[SaveSystem] Initializing...")
	load_data()
	print("[SaveSystem] Save file location: ", OS.get_user_data_dir())


# Load player data from disk
func load_data() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("[SaveSystem] No save file found. Creating default save data.")
		is_loaded = true
		save_data()  # Create initial save file
		data_loaded.emit()
		return false
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("[SaveSystem] Failed to open save file: " + str(FileAccess.get_open_error()))
		is_loaded = true
		data_loaded.emit()
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("[SaveSystem] Failed to parse save file JSON at line " + str(json.get_error_line()) + ": " + json.get_error_message())
		is_loaded = true
		data_loaded.emit()
		return false
	
	var loaded_data = json.data
	
	# Merge loaded data with default structure (in case new fields were added)
	_merge_data(player_data, loaded_data)
	
	print("[SaveSystem] Successfully loaded save data")
	print("[SaveSystem] Player name: ", player_data.player_name)
	is_loaded = true
	data_loaded.emit()
	return true


# Save player data to disk
func save_data() -> bool:
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveSystem] Failed to create save file: " + str(FileAccess.get_open_error()))
		return false
	
	var json_string = JSON.stringify(player_data, "\t")
	file.store_string(json_string)
	file.close()
	
	print("[SaveSystem] Successfully saved data")
	data_saved.emit()
	return true


# Merge loaded data into default structure (preserves new fields in updates)
func _merge_data(default_dict: Dictionary, loaded_dict: Dictionary) -> void:
	for key in loaded_dict:
		if key in default_dict:
			if typeof(default_dict[key]) == TYPE_DICTIONARY and typeof(loaded_dict[key]) == TYPE_DICTIONARY:
				_merge_data(default_dict[key], loaded_dict[key])
			else:
				default_dict[key] = loaded_dict[key]


# === GETTER FUNCTIONS ===

func get_player_name() -> String:
	return player_data.player_name


func get_total_playtime() -> float:
	return player_data.total_playtime


func get_games_played() -> int:
	return player_data.games_played


func get_total_kills() -> int:
	return player_data.total_kills


func get_highest_wave() -> int:
	return player_data.highest_wave


func get_total_coins_earned() -> int:
	return player_data.total_coins_earned


func get_master_volume() -> float:
	return player_data.settings.master_volume


func get_music_volume() -> float:
	return player_data.settings.music_volume


func get_sfx_volume() -> float:
	return player_data.settings.sfx_volume


# === SETTER FUNCTIONS ===

func set_player_name(name: String) -> void:
	player_data.player_name = name
	save_data()


func add_playtime(seconds: float) -> void:
	player_data.total_playtime += seconds
	save_data()


func increment_games_played() -> void:
	player_data.games_played += 1
	save_data()


func add_kills(count: int) -> void:
	player_data.total_kills += count
	save_data()


func update_highest_wave(wave: int) -> void:
	if wave > player_data.highest_wave:
		player_data.highest_wave = wave
		save_data()


func add_coins_earned(coins: int) -> void:
	player_data.total_coins_earned += coins
	save_data()


func set_master_volume(volume: float) -> void:
	player_data.settings.master_volume = clamp(volume, 0.0, 1.0)
	save_data()


func set_music_volume(volume: float) -> void:
	player_data.settings.music_volume = clamp(volume, 0.0, 1.0)
	save_data()


func set_sfx_volume(volume: float) -> void:
	player_data.settings.sfx_volume = clamp(volume, 0.0, 1.0)
	save_data()


# === UTILITY FUNCTIONS ===

# Reset all save data (useful for testing or implementing a "reset progress" feature)
func reset_save_data() -> void:
	player_data = {
		"player_name": "Player",
		"total_playtime": 0.0,
		"games_played": 0,
		"total_kills": 0,
		"highest_wave": 0,
		"total_coins_earned": 0,
		"settings": {
			"master_volume": 1.0,
			"music_volume": 1.0,
			"sfx_volume": 1.0
		}
	}
	save_data()
	print("[SaveSystem] Save data has been reset")


# Delete the save file
func delete_save_file() -> bool:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(SAVE_FILE_PATH)
		print("[SaveSystem] Save file deleted")
		return true
	return false


# Check if a save file exists
func save_file_exists() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)


# Get the full path to the save file (for debugging)
func get_save_file_path() -> String:
	return ProjectSettings.globalize_path(SAVE_FILE_PATH)


