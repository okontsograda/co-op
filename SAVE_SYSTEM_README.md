# Save System Documentation

## Overview

A comprehensive save system has been implemented to persist player data locally on the user's machine. The system uses JSON file storage and Godot's built-in `user://` directory path for platform-specific data storage.

## Save File Location

The save file (`save_data.json`) is stored in a platform-specific directory:

- **Windows**: `%APPDATA%\Godot\app_userdata\Co-op\`
- **Linux**: `~/.local/share/godot/app_userdata/Co-op/`
- **macOS**: `~/Library/Application Support/Godot/app_userdata/Co-op/`

You can find the exact path by checking the console output when the game starts, or by calling `SaveSystem.get_save_file_path()`.

## Features Implemented

### 1. SaveSystem Singleton (`coop/scripts/save_system.gd`)

A global autoload script that handles all save/load operations. It's accessible from anywhere in the game via `SaveSystem`.

#### Player Data Stored

```gdscript
{
  "player_name": "Player",           # Player's custom name
  "total_playtime": 0.0,            # Total seconds played
  "games_played": 0,                # Number of games completed
  "total_kills": 0,                 # Lifetime enemy kills
  "highest_wave": 0,                # Highest wave reached
  "total_coins_earned": 0,          # Lifetime coins earned
  "settings": {
    "master_volume": 1.0,
    "music_volume": 1.0,
    "sfx_volume": 1.0
  }
}
```

#### Key Functions

##### Getters
- `get_player_name()` → String
- `get_total_playtime()` → float
- `get_games_played()` → int
- `get_total_kills()` → int
- `get_highest_wave()` → int
- `get_total_coins_earned()` → int
- `get_master_volume()` → float
- `get_music_volume()` → float
- `get_sfx_volume()` → float

##### Setters (automatically save after updating)
- `set_player_name(name: String)`
- `add_playtime(seconds: float)`
- `increment_games_played()`
- `add_kills(count: int)`
- `update_highest_wave(wave: int)`
- `add_coins_earned(coins: int)`
- `set_master_volume(volume: float)`
- `set_music_volume(volume: float)`
- `set_sfx_volume(volume: float)`

##### Utility Functions
- `save_data()` → bool - Manually save all data to disk
- `load_data()` → bool - Load data from disk (called automatically on startup)
- `reset_save_data()` → void - Reset all data to defaults
- `delete_save_file()` → bool - Delete the save file completely
- `save_file_exists()` → bool - Check if a save file exists
- `get_save_file_path()` → String - Get the full path to the save file

#### Signals
- `data_loaded` - Emitted when save data is loaded from disk
- `data_saved` - Emitted when data is saved to disk

### 2. Player Name Feature

#### Main Menu UI (`coop/scenes/main_menu.tscn`)

Added a name input field to the main menu:
- Players can enter their custom name (up to 20 characters)
- The name is automatically loaded when the menu opens
- Changes are saved in real-time as the player types
- Press Enter to confirm and release focus

#### Main Menu Script (`coop/scripts/main_menu.gd`)

- Loads the saved player name on startup
- Saves the name automatically when it changes
- Validates input (no empty names)

#### Player Integration (`coop/scripts/player.gd`)

- Added `player_name` variable to store the player's name
- Automatically loads the name from SaveSystem when the player spawns
- Only loads for the local player (multiplayer authority)

## Usage Examples

### Basic Usage

```gdscript
# Get player name
var name = SaveSystem.get_player_name()
print("Welcome back, ", name, "!")

# Set player name
SaveSystem.set_player_name("Warrior123")

# Track game statistics
SaveSystem.increment_games_played()
SaveSystem.add_kills(10)
SaveSystem.update_highest_wave(15)
SaveSystem.add_coins_earned(500)
SaveSystem.add_playtime(3600.0)  # 1 hour in seconds
```

### Check if First-Time Player

```gdscript
func _ready():
    if not SaveSystem.save_file_exists():
        show_tutorial()
    else:
        show_welcome_back_message()
```

### Display Player Stats

```gdscript
func show_player_stats():
    print("Player Name: ", SaveSystem.get_player_name())
    print("Games Played: ", SaveSystem.get_games_played())
    print("Total Kills: ", SaveSystem.get_total_kills())
    print("Highest Wave: ", SaveSystem.get_highest_wave())
    print("Total Coins: ", SaveSystem.get_total_coins_earned())
    
    var hours = SaveSystem.get_total_playtime() / 3600.0
    print("Play Time: %.1f hours" % hours)
```

### Wait for Save System to Load

If you need to access saved data very early in the game lifecycle:

```gdscript
func _ready():
    if not SaveSystem.is_loaded:
        await SaveSystem.data_loaded
    
    # Now safe to access saved data
    var name = SaveSystem.get_player_name()
```

## Future Expansion Ideas

The save system can easily be extended to store additional data:

1. **Character Progression**
   - Unlocked characters/classes
   - Character-specific stats
   - Skill trees or ability unlocks

2. **Game Preferences**
   - Graphics settings
   - Control keybindings
   - Accessibility options

3. **Achievements**
   - Track completed achievements
   - Progress toward achievements
   - Achievement timestamps

4. **Unlockables**
   - Unlocked weapons
   - Unlocked skins/cosmetics
   - Unlocked game modes

5. **Friends/Social**
   - Recent players list
   - Favorite servers
   - Friend codes

## Implementation Details

### Automatic Saving

The system automatically saves data whenever you call any setter function. This ensures that player progress is never lost unexpectedly.

### Data Merging

When loading save data, the system intelligently merges loaded data with the default structure. This means:
- New fields added in updates won't cause loading errors
- Existing player data is preserved
- Missing fields are filled with defaults

### Error Handling

The system includes comprehensive error handling:
- Gracefully handles missing save files (creates new ones)
- Handles corrupted JSON data
- Logs errors to the console for debugging
- Falls back to default values when needed

### Performance

- Save operations are fast (< 1ms typically)
- Loading happens once at startup
- No performance impact during gameplay
- All operations are synchronous and predictable

## Testing the Save System

1. **Run the game** - The save file will be created automatically
2. **Set your player name** in the main menu
3. **Close and reopen the game** - Your name should persist
4. **Check the console** for save system debug messages
5. **Locate the save file** using the path printed in the console

### Console Output Example

```
[SaveSystem] Initializing...
[SaveSystem] No save file found. Creating default save data.
[SaveSystem] Successfully saved data
[SaveSystem] Save file location: C:/Users/YourName/AppData/Roaming/Godot/app_userdata/Co-op
[MainMenu] Loaded player name: Player
[MainMenu] Player name updated to: Warrior123
[SaveSystem] Successfully saved data
```

## Troubleshooting

### Save file not persisting
- Check console for error messages
- Verify the save directory has write permissions
- Try running the game as administrator (Windows)

### Name not appearing in-game
- Verify SaveSystem is in the autoload list
- Check that `player.gd` has the `player_name` variable
- Ensure the player is calling `_load_player_name()`

### Corrupted save file
- Delete the save file manually from the save directory
- The game will create a new one with defaults

## Notes

- The save system is **completely local** - no cloud storage
- Data is stored in **plain text JSON** (could be encrypted in the future)
- **Automatic saving** prevents data loss from crashes
- The system is **extensible** - easy to add new data fields


