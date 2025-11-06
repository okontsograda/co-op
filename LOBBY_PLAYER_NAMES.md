# Lobby Player Names Feature

## Overview

Player names are now displayed in the game lobby and synchronized across all connected peers. Each player's custom name (set in the main menu) will appear in the lobby player list, making it easier to identify players in multiplayer games.

## Features Implemented

### 1. Player Name Storage in Lobby

**File: `coop/scripts/lobby_manager.gd`**

- Added `player_name` field to the player data dictionary
- Each player now has: `class`, `weapon`, `ready`, `is_host`, and `player_name`
- Default name is "Player [peer_id]" if no custom name is set

### 2. Player Name Synchronization

**New Signal:**
- `player_name_changed(peer_id: int, player_name: String)` - Emitted when any player's name changes

**New Functions:**
```gdscript
# Set the local player's name (broadcasts to all peers)
LobbyManager.set_player_name(player_name: String)

# Get any player's name by their peer ID
LobbyManager.get_player_name(peer_id: int) -> String
```

**RPC Functions:**
- `_broadcast_name_change(peer_id, player_name)` - Syncs name changes across all clients

### 3. Lobby UI Display

**File: `coop/scripts/lobby_ui.gd`**

#### Player List Display
- Player names are now shown instead of "Player [ID]"
- Host players have a crown emoji (👑) next to their name
- Names are truncated with ellipsis if too long (max width: 120px)

#### Chat Messages
- Chat messages now show player names instead of IDs
- Format: `"PlayerName: message"` instead of `"Player 12345: message"`

#### Auto-Loading Names
- When entering the lobby, the local player's name is automatically loaded from SaveSystem
- The name is sent to all other players immediately
- Other players see the name update in real-time

### 4. Integration with Save System

The lobby automatically loads the player's saved name from the SaveSystem:

```gdscript
func _set_local_player_name():
    # Wait for SaveSystem to load if needed
    if not SaveSystem.is_loaded:
        await SaveSystem.data_loaded
    
    # Get saved name and send to lobby
    var saved_name = SaveSystem.get_player_name()
    LobbyManager.set_player_name(saved_name)
```

## User Experience

### Setting Your Name

1. **Launch the game** → Main Menu appears
2. **Enter your name** in the "Player Name" field
3. **Name saves automatically** as you type
4. **Join or host a game** → Your name appears in the lobby

### In the Lobby

**Player List View:**
```
Players
─────────────────────────────
│ YourName 👑    │ Archer   │ ✅ Ready     │
│ FriendName     │ Knight   │ ⏳ Not Ready │
│ Player3        │ Mage     │ ✅ Ready     │
─────────────────────────────
```

**Chat View:**
```
💬 Chat
─────────────────────────
YourName: Ready to start!
FriendName: Let's go!
Player3: Wait for me
```

## Technical Details

### Name Synchronization Flow

1. **Player joins lobby:**
   - LobbyManager registers player with default name "Player [peer_id]"
   - Player list UI is created with default name

2. **Lobby UI loads:**
   - `_set_local_player_name()` is called
   - Waits for SaveSystem to load (if needed)
   - Gets saved name from SaveSystem
   - Calls `LobbyManager.set_player_name(saved_name)`

3. **Name is set:**
   - LobbyManager updates local player data
   - Emits `player_name_changed` signal locally
   - Calls `_broadcast_name_change.rpc()` to sync with peers

4. **Other clients receive update:**
   - `_broadcast_name_change()` is called on remote clients
   - LobbyManager updates that player's data
   - Emits `player_name_changed` signal
   - Lobby UI receives signal and updates the display

### Network Traffic

- Player names are sent via reliable RPC when:
  - A player first enters the lobby
  - A player changes their name (future feature)
- Names are included in the lobby state sync when new players join
- Minimal bandwidth usage (one-time send per name change)

### Error Handling

- If SaveSystem hasn't loaded yet, the lobby waits
- If no saved name exists, defaults to "Player [peer_id]"
- If a player disconnects, their name is removed from the lobby
- Missing or invalid player IDs fall back to default names

## Future Enhancements

### Possible Additions

1. **In-Lobby Name Editing**
   - Add a text field to change name while in lobby
   - Real-time updates for all players

2. **Name Validation**
   - Prevent duplicate names
   - Filter inappropriate language
   - Enforce character limits

3. **Name Styling**
   - Different colors for different players
   - Bold/italic styles for hosts or special roles
   - Custom fonts or sizes

4. **Player Avatars**
   - Small icons next to player names
   - Customizable avatars from save system

5. **Player Profiles**
   - Click on a name to see player stats
   - Show total games played, highest wave, etc.
   - Display from SaveSystem data

## Testing

### Test Scenarios

1. **Single Player (Host)**
   - Set name in main menu
   - Host a game
   - Verify name appears in lobby with crown emoji

2. **Two Players**
   - Both players set different names
   - One hosts, one joins
   - Verify both names appear correctly
   - Test chat to ensure names show properly

3. **Name Changes**
   - Change name in main menu
   - Rejoin lobby
   - Verify updated name appears

4. **Default Names**
   - Join lobby without setting a custom name
   - Should show "Player [peer_id]"

5. **Multiple Players**
   - 3+ players join same lobby
   - All players set different names
   - Verify no name conflicts or display issues

### Debug Output

The system prints debug messages:

```
[SaveSystem] Successfully loaded save data
[SaveSystem] Player name: YourName
[LobbyUI] Set local player name in lobby: YourName
[LobbyManager] Set local player name to: YourName
[LobbyManager] Updated player 2 name to: FriendName
[LobbyUI] Updated display name for peer 2 to: FriendName
```

## Code Examples

### Get a Player's Name in Any Script

```gdscript
# In any script that needs to access player names:
var peer_id = 12345
var player_name = LobbyManager.get_player_name(peer_id)
print("Player ", peer_id, " is named: ", player_name)
```

### Listen for Name Changes

```gdscript
func _ready():
    LobbyManager.player_name_changed.connect(_on_player_name_changed)

func _on_player_name_changed(peer_id: int, player_name: String):
    print("Player ", peer_id, " changed name to: ", player_name)
    # Update your UI or logic here
```

### Manually Update Player Name (Advanced)

```gdscript
# This would update both the save system and lobby
func change_player_name(new_name: String):
    SaveSystem.set_player_name(new_name)  # Save to disk
    if LobbyManager.is_in_lobby:
        LobbyManager.set_player_name(new_name)  # Broadcast to lobby
```

## Compatibility

- **Godot Version:** 4.5+
- **Multiplayer:** Works with NodeTunnel multiplayer system
- **Save System:** Requires SaveSystem autoload
- **Backward Compatible:** Old lobbies without names will show default "Player [ID]"

## Summary

The lobby now displays custom player names that are:
- ✅ Loaded from the save system
- ✅ Synchronized across all peers
- ✅ Displayed in the player list
- ✅ Shown in chat messages
- ✅ Marked with crown emoji for hosts
- ✅ Automatically updated in real-time

