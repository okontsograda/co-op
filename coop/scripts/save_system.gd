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

	# Meta progression (persistent hub currency and unlocks)
	"meta_coins": 0,  # Currency earned from missions, spent in hub
	"unlocked_classes": ["Archer", "Knight"],  # Default: Archer and Knight unlocked
	"unlocked_weapons": ["bow"],  # Default: bow unlocked
	"unlocked_cosmetics": [],  # Future: cosmetic items
	"permanent_upgrades": {},  # Future: permanent stat boosts {upgrade_id: level}
	"achievements": [],  # Future: achievement tracking
	"selected_class": "Archer",  # Currently selected class

	# Combat stats
	"boss_kills": 0,
	"deaths": 0,
	"damage_dealt": 0,

	# Loadout preferences (saved from hub)
	"last_loadout": {
		"class": "Archer",
		"weapon": "bow"
	},

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
	
	# Ensure Knight is unlocked by default (for backwards compatibility with old saves)
	if "Knight" not in player_data.unlocked_classes:
		player_data.unlocked_classes.append("Knight")
		print("[SaveSystem] Added Knight to unlocked classes (backwards compatibility)")
	
	print("[SaveSystem] Successfully loaded save data")
	print("[SaveSystem] Player name: ", player_data.player_name)
	print("[SaveSystem] Selected class: ", player_data.selected_class)
	print("[SaveSystem] Unlocked classes: ", player_data.unlocked_classes)
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
	print("[SaveSystem] Selected class in saved data: %s" % player_data.selected_class)
	data_saved.emit()
	return true


# Merge loaded data into default structure (preserves new fields in updates)
func _merge_data(default_dict: Dictionary, loaded_dict: Dictionary) -> void:
	for key in loaded_dict:
		if key in default_dict:
			if typeof(default_dict[key]) == TYPE_DICTIONARY and typeof(loaded_dict[key]) == TYPE_DICTIONARY:
				_merge_data(default_dict[key], loaded_dict[key])
			elif typeof(default_dict[key]) == TYPE_ARRAY and typeof(loaded_dict[key]) == TYPE_ARRAY:
				# For arrays, merge unique values (preserve defaults that might be missing in old saves)
				var default_array = default_dict[key] as Array
				var loaded_array = loaded_dict[key] as Array
				# Combine arrays and remove duplicates
				var merged_array = default_array.duplicate()
				for item in loaded_array:
					if item not in merged_array:
						merged_array.append(item)
				default_dict[key] = merged_array
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


# === META PROGRESSION FUNCTIONS ===

func get_meta_coins() -> int:
	return player_data.meta_coins


func add_meta_currency(amount: int) -> void:
	player_data.meta_coins += amount
	print("[SaveSystem] Earned %d meta coins (Total: %d)" % [amount, player_data.meta_coins])
	save_data()


func spend_meta_currency(amount: int) -> bool:
	if player_data.meta_coins >= amount:
		player_data.meta_coins -= amount
		print("[SaveSystem] Spent %d meta coins (Remaining: %d)" % [amount, player_data.meta_coins])
		save_data()
		return true
	print("[SaveSystem] Not enough meta coins. Need %d, have %d" % [amount, player_data.meta_coins])
	return false


func is_class_unlocked(p_class_name: String) -> bool:
	# Case-insensitive check - convert to capitalized format for comparison
	var capitalized_name = p_class_name.capitalize()
	return capitalized_name in player_data.unlocked_classes


func unlock_class(p_class_name: String) -> void:
	# Convert to capitalized format for consistency
	var capitalized_name = p_class_name.capitalize()
	if not is_class_unlocked(capitalized_name):
		player_data.unlocked_classes.append(capitalized_name)
		print("[SaveSystem] Unlocked class: %s" % capitalized_name)
		save_data()


func get_unlocked_classes() -> Array:
	return player_data.unlocked_classes.duplicate()


func is_weapon_unlocked(p_weapon_name: String) -> bool:
	return p_weapon_name in player_data.unlocked_weapons


func unlock_weapon(p_weapon_name: String) -> void:
	if not is_weapon_unlocked(p_weapon_name):
		player_data.unlocked_weapons.append(p_weapon_name)
		print("[SaveSystem] Unlocked weapon: %s" % p_weapon_name)
		save_data()


func get_unlocked_weapons() -> Array:
	return player_data.unlocked_weapons.duplicate()


func save_loadout(p_class_name: String, p_weapon_name: String) -> void:
	player_data.last_loadout.class = p_class_name
	player_data.last_loadout.weapon = p_weapon_name
	print("[SaveSystem] Saving loadout: class=%s, weapon=%s" % [p_class_name, p_weapon_name])
	save_data()


func get_last_loadout() -> Dictionary:
	return player_data.last_loadout.duplicate()


func add_achievement(achievement_id: String) -> void:
	if achievement_id not in player_data.achievements:
		player_data.achievements.append(achievement_id)
		print("[SaveSystem] Achievement unlocked: %s" % achievement_id)
		save_data()


func has_achievement(achievement_id: String) -> bool:
	return achievement_id in player_data.achievements


func get_permanent_upgrade_level(upgrade_id: String) -> int:
	return player_data.permanent_upgrades.get(upgrade_id, 0)


func upgrade_permanent_stat(upgrade_id: String, max_level: int = -1) -> bool:
	var current_level = get_permanent_upgrade_level(upgrade_id)
	if max_level > 0 and current_level >= max_level:
		return false
	player_data.permanent_upgrades[upgrade_id] = current_level + 1
	print("[SaveSystem] Upgraded %s to level %d" % [upgrade_id, current_level + 1])
	save_data()
	return true


func get_selected_class() -> String:
	return player_data.selected_class


func set_selected_class(p_class_name: String) -> void:
	# Convert to capitalized format for consistency
	var capitalized_name = p_class_name.capitalize()
	
	# Always save the selected class, but warn if it's not unlocked
	if not is_class_unlocked(capitalized_name):
		print("[SaveSystem] WARNING: Setting selected class to %s which is not unlocked!" % capitalized_name)
		# Unlock it automatically to prevent issues
		unlock_class(capitalized_name)
	
	player_data.selected_class = capitalized_name
	print("[SaveSystem] Setting selected class to: %s" % capitalized_name)
	save_data()
	print("[SaveSystem] Selected class saved successfully")


func is_cosmetic_unlocked(cosmetic_name: String) -> bool:
	return cosmetic_name in player_data.unlocked_cosmetics


func unlock_cosmetic(cosmetic_name: String) -> void:
	if not is_cosmetic_unlocked(cosmetic_name):
		player_data.unlocked_cosmetics.append(cosmetic_name)
		print("[SaveSystem] Unlocked cosmetic: %s" % cosmetic_name)
		save_data()


func get_boss_kills() -> int:
	return player_data.boss_kills


func add_boss_kill() -> void:
	player_data.boss_kills += 1
	save_data()


func get_deaths() -> int:
	return player_data.deaths


func add_death() -> void:
	player_data.deaths += 1
	save_data()


func get_damage_dealt() -> int:
	return player_data.damage_dealt


func add_damage_dealt(damage: int) -> void:
	player_data.damage_dealt += damage
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
		"meta_coins": 0,
		"unlocked_classes": ["Archer", "Knight"],
		"unlocked_weapons": ["bow"],
		"unlocked_cosmetics": [],
		"permanent_upgrades": {},
		"achievements": [],
		"selected_class": "Archer",
		"boss_kills": 0,
		"deaths": 0,
		"damage_dealt": 0,
		"last_loadout": {
			"class": "Archer",
			"weapon": "bow"
		},
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
