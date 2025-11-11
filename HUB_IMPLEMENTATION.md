# Hub Scene Implementation Guide

## Overview
The Hub is a central multiplayer village where players spawn, customize their characters, view progression stats, shop for permanent upgrades, and launch co-op missions.

## Features Implemented

### 1. Hub Scene (`scenes/hub.tscn`)
- **Basic layout** with 5 interactive zones:
  - Character Selection Station
  - Meta Shop
  - Statistics Display
  - Mission Board
  - Skill Tree (placeholder for future)
- **Spawn system** with 4 spawn points for multiplayer
- **MultiplayerSpawner** for network synchronization
- **Camera** that follows local player

### 2. Hub Manager (`scripts/hub_manager.gd`)
- **Autoload singleton** managing hub state
- **Player tracking**: Registers players entering/leaving hub
- **Ready system**: Coordinates when all players are ready to start mission
- **Mission transitions**: Handles moving from hub → mission scenes
- **Return to hub**: Awards meta currency after game over

### 3. Meta Progression System (Extended `scripts/save_system.gd`)
Added persistent progression fields:
- **meta_coins**: Currency earned from missions
- **unlocked_classes**: Array of unlocked character classes
- **unlocked_weapons**: Array of unlocked weapons
- **unlocked_cosmetics**: Future cosmetic items
- **permanent_upgrades**: Persistent stat boosts
- **achievements**: Achievement tracking
- **last_loadout**: Saved class/weapon preferences

New functions:
- `add_meta_currency(amount)` / `spend_meta_currency(amount)`
- `unlock_class(class_name)` / `is_class_unlocked(class_name)`
- `unlock_weapon(weapon_name)` / `is_weapon_unlocked(weapon_name)`
- `save_loadout(class, weapon)` / `get_last_loadout()`
- `add_achievement(id)` / `has_achievement(id)`
- `upgrade_permanent_stat(upgrade_id, max_level)`

### 4. Hub UI System (`scenes/ui/hub_ui.tscn` + `scripts/ui/hub_ui.gd`)

#### UI Components:
- **Meta Coins Display**: Shows current meta currency in top-right
- **Interaction Prompt**: Shows "Press E to interact" when near a zone
- **Ready Status**: Shows player ready count for multiplayer

#### Interactive UIs:
1. **Character Customization**
   - Select class (Archer, Knight, Mage, Tank)
   - Locked classes show as disabled
   - Auto-assigns appropriate weapon (Knight → sword, others → bow)
   - Saves loadout to SaveSystem

2. **Meta Shop**
   - Purchase unlockable classes and weapons with meta coins
   - Items show "Owned" when already unlocked
   - Current shop items:
     - Unlock Knight Class (500 MC)
     - Unlock Mage Class (1000 MC)
     - Unlock Tank Class (1000 MC)
     - Unlock Rocket Weapon (750 MC)

3. **Statistics Display**
   - Shows career statistics from SaveSystem:
     - Player Name
     - Games Played
     - Total Kills
     - Highest Wave
     - Coins Earned
     - Meta Coins
     - Playtime (formatted as hours/minutes)

4. **Mission Board**
   - Ready toggle for players
   - Start Mission button (host only, enabled when all ready)
   - Currently only supports "example" mission

### 5. Hub Scene Script (`scripts/hub_scene.gd`)
- **Zone detection**: Tracks which interactive zone player is in
- **Camera following**: Camera reparents to local player
- **Interaction handling**: Press E/Enter to interact with zones
- **Combat disabled**: Sets hub_mode metadata on players

### 6. NetworkHandler Hub Functions
Added to `scripts/network_handler.gd`:
- `start_server_to_hub()`: Host game and enter hub
- `start_client_to_hub(host_id)`: Join game and enter hub
- `start_solo_hub()`: Offline single-player hub
- `return_to_hub_after_game(wave, kills)`: Award currency and return after mission
- `_calculate_meta_currency_reward(wave, kills)`: Calculates rewards (50 MC per wave + 1 MC per 5 kills)

### 7. Game Flow Integration

#### Main Menu (`scripts/main_menu.gd`)
- **Play Local** → Solo Hub (offline)
- **Host Game** → Multiplayer Hub (as host)
- **Join Game** → Multiplayer Hub (as client)

#### Game Over Screen (`scripts/game_over_screen.gd`)
- **Restart** → Return to hub with meta currency rewards
- **Main Menu** → Return to hub with meta currency rewards
- Both buttons award currency based on performance

## Game Flow

```
Main Menu
    ├─ Play Local ──→ Solo Hub ──→ Mission Board ──→ Mission ──→ Game Over ──→ Hub (with rewards)
    ├─ Host Game ──→ Multi Hub ──→ Mission Board ──→ Mission ──→ Game Over ──→ Hub (with rewards)
    └─ Join Game ──→ Multi Hub ──→ Mission Board ──→ Mission ──→ Game Over ──→ Hub (with rewards)
```

## Meta Currency Rewards

Formula: `(wave * 50) + (kills / 5)`

Examples:
- Wave 5, 50 kills = 250 + 10 = **260 MC**
- Wave 10, 150 kills = 500 + 30 = **530 MC**
- Wave 20, 400 kills = 1000 + 80 = **1080 MC**

## Controls

- **WASD**: Move in hub
- **E / Enter**: Interact with zones
- **Tab**: Toggle stats screen (in mission)
- **Escape**: Close UI panels

## Technical Details

### Multiplayer Synchronization
- Player positions synced via MultiplayerSynchronizer (from player.tscn)
- Ready states synced via HubManager
- Mission start triggered via RPC from host

### Scene Hierarchy
```
Hub (Node2D)
├─ Camera2D (reparents to local player)
├─ PlayerSpawnPoints (Node2D)
│   ├─ SpawnPoint1-4 (Marker2D)
├─ MultiplayerSpawner
├─ InteractiveZones (Node2D)
│   ├─ CharacterStation (Area2D)
│   ├─ MetaShop (Area2D)
│   ├─ StatsDisplay (Area2D)
│   ├─ MissionBoard (Area2D)
│   └─ SkillTree (Area2D - placeholder)
├─ HubUI (CanvasLayer)
└─ Background (ColorRect)
```

### Autoload Order
```
1. SaveSystem
2. LobbyManager
3. NetworkHandler
4. HubManager ← NEW
5. UpgradeSystem
... (rest)
```

## Future Enhancements

### Immediate Priorities:
1. **Visual Polish**
   - Replace placeholder background with tilemap village
   - Add building sprites for interaction zones
   - Ambient NPCs/decorations
   - Particle effects for zone interactions

2. **Mission Selection**
   - Multiple mission types
   - Difficulty selection
   - Mission descriptions and rewards preview

3. **Skill Tree**
   - Permanent skill unlocks
   - Branching progression paths
   - Visual skill tree UI

### Long-term:
- **Cosmetic Shop**: Character skins, weapon skins, emotes
- **Achievement System**: Unlock achievements for rewards
- **Leaderboards**: Compare stats with other players
- **Social Features**: Friend lists, party invites
- **Hub Customization**: Player housing, decorations
- **Daily Quests**: Additional meta currency sources

## Testing Checklist

- [ ] Solo hub spawning
- [ ] Multiplayer hub (2+ players)
- [ ] Character selection saves loadout
- [ ] Meta shop purchases work
- [ ] Stats display shows correct data
- [ ] Mission board ready system works
- [ ] Mission start transitions correctly
- [ ] Game over awards meta currency
- [ ] Currency persists across sessions
- [ ] Locked classes show as disabled
- [ ] Camera follows player correctly

## Known Issues

1. **Player combat abilities**: Need to properly disable shooting/attacking in hub
2. **Visual placeholders**: Hub uses simple colored background instead of tilemap
3. **Single mission**: Only "example" mission available
4. **No progression feedback**: Need UI for "Earned X meta coins!" after game

## File References

### New Files:
- `scenes/hub.tscn` - Main hub scene
- `scenes/ui/hub_ui.tscn` - Hub UI layer
- `scripts/hub_scene.gd` - Hub scene logic
- `scripts/hub_manager.gd` - Hub state manager (autoload)
- `scripts/ui/hub_ui.gd` - Hub UI controller

### Modified Files:
- `scripts/save_system.gd` - Added meta progression fields
- `scripts/network_handler.gd` - Added hub networking functions
- `scripts/main_menu.gd` - Route to hub instead of lobby
- `scripts/game_over_screen.gd` - Return to hub with rewards
- `project.godot` - Added HubManager autoload

## Usage Examples

### Unlock a class via code:
```gdscript
SaveSystem.unlock_class("Mage")
```

### Award meta currency:
```gdscript
SaveSystem.add_meta_currency(500)
```

### Check if player can afford item:
```gdscript
if SaveSystem.get_meta_coins() >= item_cost:
    SaveSystem.spend_meta_currency(item_cost)
```

### Get player's loadout:
```gdscript
var loadout = SaveSystem.get_last_loadout()
print(loadout.class)  # "Archer"
print(loadout.weapon)  # "bow"
```
