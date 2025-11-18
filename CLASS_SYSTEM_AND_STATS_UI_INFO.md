# Class System and Stats UI Information

## Class System Overview

### Class Definitions (`coop/scripts/player_class.gd`)

The class system is defined in `PlayerClass` (a RefCounted class). It provides static methods to access class data.

**Available Classes:**
1. **Archer** (default)
   - Health modifier: 1.0 (100 HP)
   - Damage modifier: 1.0
   - Speed modifier: 1.0
   - Attack speed modifier: 1.0
   - Combat type: ranged
   - Attack range: 0 (unlimited)

2. **Knight**
   - Health modifier: 1.5 (150 HP)
   - Damage modifier: 1.3 (~20 damage)
   - Speed modifier: 0.8 (slower)
   - Attack speed modifier: 0.9 (slightly slower)
   - Combat type: melee
   - Attack range: 60.0 pixels

3. **Mage**
   - Health modifier: 0.7 (70 HP)
   - Damage modifier: 1.5 (~23 damage)
   - Speed modifier: 1.0
   - Attack speed modifier: 1.4 (much faster)
   - Combat type: ranged
   - Attack range: 0 (unlimited)

4. **Tank**
   - Health modifier: 2.0 (200 HP)
   - Damage modifier: 0.8 (~12 damage)
   - Speed modifier: 0.7 (quite slow)
   - Attack speed modifier: 1.0
   - Combat type: ranged
   - Attack range: 0 (unlimited)

**Class Data Structure:**
Each class has the following properties:
- `name`: Display name (e.g., "Archer", "Knight")
- `description`: Class description
- `sprite_frames_path`: Path to sprite frames resource
- `combat_type`: "ranged" or "melee"
- `attack_range`: Range in pixels (0 for ranged)
- `health_modifier`: Multiplier for max health
- `damage_modifier`: Multiplier for base attack damage
- `speed_modifier`: Multiplier for movement speed
- `attack_speed_modifier`: Multiplier for attack speed (higher = faster)
- `color_tint`: Color tint for sprite (currently all WHITE)

**Key Functions:**
- `PlayerClass.get_class_by_name(class_id: String) -> Dictionary`: Get class data by ID (case-insensitive)
- `PlayerClass.get_all_classes() -> Dictionary`: Get all class definitions
- `PlayerClass.get_class_names() -> Array`: Get list of class IDs ["archer", "knight", "mage", "tank"]

### Class Application (`coop/scripts/player.gd`)

**Function: `apply_class_modifiers(selected_class: String)`** (lines 3142-3216)

This function applies class modifiers to the player:

1. **Health**: `max_health = int(max_health * class_data["health_modifier"])`
2. **Damage**: `attack_damage = int(attack_damage * class_data["damage_modifier"])`
3. **Speed**: `class_speed_modifier = class_data["speed_modifier"]`
4. **Attack Speed**: `weapon_stats.fire_cooldown = fire_cooldown * (1.0 / class_data["attack_speed_modifier"])`
5. **Combat Type**: Sets `combat_type` and `equipped_weapon` (sword for melee, bow for ranged)
6. **Melee Range**: Sets `melee_attack_range` if combat_type is "melee"
7. **Sprite Frames**: Loads and applies character sprite frames
8. **Color Tint**: Applies color tint to sprite

**Note:** The player does NOT store the `selected_class` as a variable. It's only used during initialization. To determine the current class, you would need to:
- Check player metadata: `player.get_meta("selected_class")` (if still set)
- Check LobbyManager: `LobbyManager.players[peer_id]["class"]`
- Check SaveSystem: `SaveSystem.get_selected_class()`
- Or infer from current stats (e.g., combat_type, health, damage)

### Player Stats Affected by Class

**Base Stats (before class modifiers):**
- `max_health`: 100 (default)
- `attack_damage`: Set in Inspector (typically 15)
- `walk_speed`: 100.0
- `run_speed`: 135.0
- `fire_cooldown`: 1.0 (1 shot per second)

**Class-Modified Stats:**
- `max_health`: Modified by `health_modifier`
- `current_health`: Set to `max_health` after class application
- `attack_damage`: Modified by `damage_modifier`
- `class_speed_modifier`: Applied to movement speed calculations
- `weapon_stats.fire_cooldown`: Modified by `attack_speed_modifier`
- `combat_type`: "ranged" or "melee"
- `melee_attack_range`: Set for melee classes
- `equipped_weapon`: "sword" for melee, "bow" for ranged

---

## Stats Screen UI Overview

### Stats Screen Script (`coop/scripts/stats_screen.gd`)

**Key Functions:**

1. **`show_stats(p_player: Node2D)`** (line 13)
   - Sets the player reference
   - Updates display
   - Shows the screen

2. **`update_display()`** (line 20)
   - Calls all update functions:
     - `update_player_stats()`
     - `update_weapon_stats()`
     - `update_upgrades_list()`

3. **`update_player_stats()`** (line 34)
   - Updates **Level**: `TeamXP.get_team_level()`
   - Updates **Health**: `player.current_health + " / " + player.max_health`
   - Updates **XP**: `TeamXP.get_team_xp() + " / " + TeamXP.get_xp_to_next_level()`

4. **`update_weapon_stats()`** (line 57)
   - Updates weapon-related stats from `player.weapon_stats`:
     - **Damage**: `(player.attack_damage + ws.damage) * ws.damage_multiplier`
     - **Fire Rate**: `1.0 / ws.fire_cooldown` (shots per second)
     - **Multishot**: `ws.multishot_count` (number of arrows)
     - **Pierce**: `ws.pierce_count` (number of enemies)
     - **Crit Chance**: `ws.crit_chance * 100` (%)
     - **Arrow Speed**: `ws.arrow_speed`
     - **Explosion Chance**: `ws.explosion_chance * 100` (%)
     - **Lifesteal**: `ws.lifesteal` (HP per hit)
     - **Homing**: `ws.homing_strength * 100` (%)

5. **`update_upgrades_list()`** (line 143)
   - Displays active upgrades from `player.upgrade_stacks`
   - Shows upgrade name, level, and description

### Stats Screen Scene (`coop/scenes/stats_screen.tscn`)

**UI Structure:**
```
StatsScreen (CanvasLayer)
└── Background (ColorRect - black with 0.8 alpha)
└── MarginContainer
    └── VBoxContainer
        ├── Header (HBoxContainer)
        │   ├── TitleLabel: "CHARACTER STATS"
        │   └── CloseHint: "Press [TAB] to close"
        ├── HSeparator
        └── ScrollContainer
            └── Content (VBoxContainer)
                ├── PlayerStats (VBoxContainer)
                │   ├── SectionTitle: "PLAYER STATS"
                │   ├── HSeparator
                │   └── StatsGrid (GridContainer, 2 columns)
                │       ├── LevelLabel / LevelValue
                │       ├── HealthLabel / HealthValue
                │       └── XPLabel / XPValue
                ├── WeaponStats (VBoxContainer)
                │   ├── SectionTitle: "WEAPON STATS"
                │   ├── HSeparator
                │   └── StatsGrid (GridContainer, 2 columns)
                │       ├── DamageLabel / DamageValue
                │       ├── FireRateLabel / FireRateValue
                │       ├── MultishotLabel / MultishotValue
                │       ├── PierceLabel / PierceValue
                │       ├── CritChanceLabel / CritChanceValue
                │       ├── ArrowSpeedLabel / ArrowSpeedValue
                │       ├── ExplosionLabel / ExplosionValue
                │       ├── LifestealLabel / LifestealValue
                │       └── HomingLabel / HomingValue
                └── ActiveUpgrades (VBoxContainer)
                    ├── SectionTitle: "ACTIVE UPGRADES"
                    ├── HSeparator
                    └── UpgradesList (VBoxContainer)
```

**Node Paths for Updates:**
- Level: `"MarginContainer/VBoxContainer/ScrollContainer/Content/PlayerStats/StatsGrid/LevelValue"`
- Health: `"MarginContainer/VBoxContainer/ScrollContainer/Content/PlayerStats/StatsGrid/HealthValue"`
- XP: `"MarginContainer/VBoxContainer/ScrollContainer/Content/PlayerStats/StatsGrid/XPValue"`
- Damage: `"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/DamageValue"`
- Fire Rate: `"MarginContainer/VBoxContainer/ScrollContainer/Content/WeaponStats/StatsGrid/FireRateValue"`
- (Similar pattern for other weapon stats)

### Stats Screen Toggle (`coop/scripts/player.gd`)

**Function: `toggle_stats_screen()`** (line 2744)
- Triggered by `stats_toggle` input action (TAB key)
- Creates/instantiates stats screen if it doesn't exist
- Calls `show_stats(self)` to display current player's stats
- Closes when TAB is pressed again

---

## Available Player Properties for Stats Display

### Core Stats
- `player.current_health`: Current health
- `player.max_health`: Maximum health (modified by class)
- `player.attack_damage`: Base attack damage (modified by class)
- `player.class_speed_modifier`: Speed modifier from class
- `player.combat_type`: "ranged" or "melee"
- `player.equipped_weapon`: "bow", "sword", "rocket", etc.
- `player.melee_attack_range`: Range for melee attacks (if melee)

### Movement Stats
- `player.walk_speed`: 100.0 (base)
- `player.run_speed`: 135.0 (base)
- `player.current_speed`: Current movement speed
- `player.max_stamina`: 100.0
- `player.current_stamina`: Current stamina

### Weapon Stats (`player.weapon_stats`)
- `damage`: Additional flat damage
- `damage_multiplier`: Multiplicative damage bonus
- `fire_cooldown`: Cooldown between shots (modified by class)
- `pierce_count`: Number of enemies arrow can pierce
- `multishot_count`: Number of arrows fired per shot
- `arrow_speed`: Base arrow speed
- `crit_chance`: Critical hit chance (0.0 to 1.0)
- `crit_multiplier`: Critical hit damage multiplier
- `explosion_chance`: Chance for arrows to explode
- `explosion_radius`: Radius of explosion damage
- `explosion_damage`: Explosion damage
- `lifesteal`: HP gained per enemy hit
- `poison_damage`: Damage per second from poison
- `poison_duration`: Duration of poison effect
- `homing_strength`: Strength of homing effect (0.0 to 1.0)

### Other Stats
- `player.coins`: Currency collected
- `player.upgrade_stacks`: Dictionary of active upgrades
- `player.player_name`: Player's name
- `TeamXP.get_team_level()`: Team level
- `TeamXP.get_team_xp()`: Team XP
- `TeamXP.get_xp_to_next_level()`: XP needed for next level

---

## Recommendations for UI Enhancement

To display class information in the stats screen, you could:

1. **Add Class Name Display:**
   - Get class from player metadata or infer from stats
   - Display class name and description in PlayerStats section

2. **Add Class Modifiers Display:**
   - Show base stats vs. modified stats
   - Display modifiers (e.g., "Health: 150 (1.5x)", "Speed: 0.8x")

3. **Add Movement Stats:**
   - Display movement speed (walk/run with class modifier)
   - Display stamina information

4. **Add Combat Type Display:**
   - Show combat type (ranged/melee)
   - Show attack range for melee classes

5. **Calculate Effective Stats:**
   - Show final calculated values (e.g., effective movement speed = walk_speed * class_speed_modifier)
   - Show effective fire rate (already calculated in weapon stats)

---

## File Locations

- **Class System**: `coop/scripts/player_class.gd`
- **Class Application**: `coop/scripts/player.gd` (function `apply_class_modifiers`)
- **Stats Screen Script**: `coop/scripts/stats_screen.gd`
- **Stats Screen Scene**: `coop/scenes/stats_screen.tscn`
- **Stats Toggle**: `coop/scripts/player.gd` (function `toggle_stats_screen`, line 2744)

