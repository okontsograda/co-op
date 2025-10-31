# Melee Combat System Documentation

## 🗡️ Overview

The knight character now uses **melee (close-range) combat** instead of ranged projectiles. When playing as a knight, clicking attacks enemies within sword range rather than firing arrows.

---

## 🎮 How It Works

### Combat Type System

Each character class now has a `combat_type` property:
- **"ranged"** - Archer, Mage, Tank (shoots projectiles)
- **"melee"** - Knight (close-range sword attacks)

### Knight Melee Attack Flow

```
Player clicks mouse
    ↓
handle_fire_action() checks combat_type
    ↓
If "melee" → handle_melee_attack()
    ↓
Play attack animation
    ↓
Wait 0.3 seconds (animation buildup)
    ↓
perform_melee_damage() - Check for enemies in range
    ↓
Damage all enemies within:
  - 60 pixel range (melee_attack_range)
  - ~60 degree cone in front of player
    ↓
Apply damage, lifesteal, crit chance
    ↓
Send RPC to sync with other clients
```

---

## ⚔️ Melee Attack Mechanics

### Range
- **Default**: 60 pixels from player center
- Configurable per class in `player_class.gd`
- Knight: 60 pixels (about 1.5 character widths)

### Attack Cone
- Attacks in a **cone** in front of the player
- ~60 degree spread (based on dot product > 0.3)
- Player faces the direction of mouse cursor
- Only hits enemies in the direction you're facing

### Damage Calculation
```gdscript
base_damage = attack_damage (from class)
bonus_damage = weapon_stats.damage (from upgrades)
multiplier = weapon_stats.damage_multiplier (from upgrades)

final_damage = (base_damage + bonus_damage) * multiplier

# Then apply crit if rolled
if crit:
    final_damage *= weapon_stats.crit_multiplier
```

### Multi-Target
- Can hit **multiple enemies** in a single swing
- All enemies within range and cone are damaged
- Great for crowd control!

---

## 🎯 Visual Feedback

### Attack Animation
- Uses the "fire" animation (same as archer's attack)
- For knight, this should be a sword swing animation
- Animation timing:
  - 0.0s: Start animation
  - 0.3s: Damage is applied (mid-swing)
  - 0.9s: Animation completes

### Damage Numbers
- Spawns damage numbers above enemies
- Shows actual damage dealt
- Different appearance for critical hits

### Audio
- Plays weapon sound on attack
- Uses the same sound system as ranged weapons
- Synced across multiplayer

---

## 🔧 Technical Details

### Key Variables (player.gd)
```gdscript
var combat_type: String = "ranged"      # Set by class
var melee_attack_range: float = 60.0    # Attack reach
```

### Key Functions

#### `handle_fire_action(mouse_position)`
- Main entry point for all attacks
- Checks combat_type and routes to appropriate handler

#### `handle_melee_attack(mouse_position)`
- Handles knight's melee attack
- Plays animation, turns to face target
- Calls perform_melee_damage after delay

#### `perform_melee_damage(target_pos)`
- Finds enemies in range
- Checks cone/direction
- Applies damage with crits and lifesteal
- Spawns damage numbers

#### `perform_melee_damage_network(target_pos)` [RPC]
- Syncs melee attacks across network
- Other clients see the attack happen
- Ensures all clients calculate damage

---

## 🎨 Class Configuration

### Adding Melee to a New Class

In `player_class.gd`:
```gdscript
"your_melee_class": {
    "name": "Your Class",
    "combat_type": "melee",        # Enable melee combat
    "attack_range": 60.0,          # Sword reach (pixels)
    "health_modifier": 1.5,
    "damage_modifier": 1.3,
    // ... other stats
}
```

### Configuring Melee Range

Adjust `attack_range` to change sword reach:
- **40**: Short dagger range
- **60**: Standard sword range (knight default)
- **80**: Long spear/halberd range
- **100**: Very long reach (polearm)

---

## 🌐 Multiplayer Synchronization

### How It Syncs
1. **Local player** performs melee attack
2. Damage calculated locally (authority)
3. RPC sent to all other clients
4. Other clients play animation & sound
5. Server validates damage (if authority)

### Network Functions
- `perform_melee_damage_network()` - RPC for syncing attacks
- Damage calculated on each client for responsiveness
- Server has final authority on enemy health

---

## ⚡ Upgrades & Melee Combat

All weapon upgrades work with melee attacks:

### Damage Upgrades
- ✅ **Damage Boost** - Increases melee damage
- ✅ **Crit Chance** - Can crit on melee hits
- ✅ **Crit Multiplier** - Higher crit damage

### Utility Upgrades
- ✅ **Lifesteal** - Heal per enemy hit (great for melee!)
- ✅ **Attack Speed** - Faster sword swings
- ✅ **Fire Rate** - Reduces attack cooldown

### NOT Applicable to Melee
- ❌ **Pierce** - Only for projectiles
- ❌ **Multishot** - Only for projectiles
- ❌ **Arrow Speed** - Only for projectiles
- ❌ **Homing** - Only for projectiles
- ❌ **Explosive Arrows** - Only for projectiles
- ❌ **Poison Arrows** - Only for projectiles

---

## 🎮 Gameplay Tips

### Playing as Knight

**Strengths:**
- High health and damage
- Can hit multiple enemies at once
- Lifesteal upgrades are very powerful
- No projectile travel time

**Weaknesses:**
- Must get close to enemies
- Vulnerable to ranged attacks
- Slower movement speed
- Can't attack at range

**Strategies:**
- Dive into enemy groups
- Use lifesteal to sustain
- Tank damage for archer teammates
- Block enemy paths with your body

### Co-op Synergy
- **Knight + Archer**: Knight tanks, archer shoots from behind
- **Knight + Mage**: Knight holds aggro, mage nukes
- **Multiple Knights**: Surround enemy groups

---

## 🔍 Cone Attack Visualization

```
        Enemy (hit)
           ↑
      60° cone
         ↗ ↑ ↖
        Player → facing direction (mouse)
         ↘   ↙
           
    Enemy        Enemy
    (hit)        (missed - behind player)
```

The knight attacks in a forward cone. Enemies behind or far to the sides won't be hit even if in range.

---

## 🐛 Debugging

### Common Issues

**"Melee attacks don't hit anything"**
- Check `melee_attack_range` is set (default 60.0)
- Verify enemies have `take_damage()` method
- Ensure enemies are in "enemies" group
- Check console for "Melee attack missed" message

**"Archer suddenly does melee"**
- Check `combat_type` in player_class.gd
- Archer should be "ranged", not "melee"
- Verify apply_class_modifiers() is called

**"Knight attacks too slowly"**
- Adjust `attack_speed_modifier` in class data
- Modify `fire_cooldown` in weapon_stats
- Check rapid fire count isn't blocking

### Debug Console Output

When melee attacking, you should see:
```
Player [id] melee attacking!
Melee hit enemy at distance: [X]
Melee attack hit [N] enemies
```

---

## 📊 Comparison: Ranged vs Melee

| Feature | Ranged (Archer) | Melee (Knight) |
|---------|----------------|----------------|
| **Attack Range** | Unlimited | 60 pixels |
| **Multi-Target** | Pierce upgrade | Built-in cone |
| **Safety** | High (distance) | Low (close range) |
| **Damage Window** | Travel time | Instant |
| **Best Against** | Single targets | Groups |
| **Synergy With** | Distance, evasion | Health, lifesteal |

---

## 🚀 Future Enhancements

### Possible Additions
- [ ] Melee-specific upgrades (sweep attack, dash attack)
- [ ] Different attack patterns per melee weapon
- [ ] Charge attacks (hold mouse to charge)
- [ ] Knockback on melee hits
- [ ] Melee combo system (3-hit combos)
- [ ] Block/parry mechanic
- [ ] Melee critical animations
- [ ] Sword trail visual effects

### Balance Tweaks
- Adjust melee range per feedback
- Tune damage multipliers
- Add melee-specific sounds per weapon
- Differentiate knight from potential future melee classes

---

## 📝 Code Examples

### Checking Combat Type in Upgrades
```gdscript
func apply_upgrade(upgrade_id: String) -> void:
    match upgrade_id:
        "pierce":
            if combat_type == "ranged":
                weapon_stats.pierce_count += 1
            else:
                print("Pierce doesn't apply to melee!")
```

### Custom Melee Range
```gdscript
"spearman": {
    "combat_type": "melee",
    "attack_range": 80.0,  # Longer reach than knight
    // ...
}
```

### Adding Melee Visual Effect
```gdscript
func perform_melee_damage(target_pos: Vector2) -> void:
    # ... existing damage code ...
    
    # Spawn slash effect
    var slash_effect = preload("res://effects/sword_slash.tscn").instantiate()
    slash_effect.global_position = global_position
    get_tree().current_scene.add_child(slash_effect)
```

---

## ✅ Testing Checklist

- [ ] Knight attacks when clicking (no arrows spawn)
- [ ] Damage numbers appear above enemies
- [ ] Multiple enemies hit in single swing
- [ ] Enemies behind player aren't hit
- [ ] Lifesteal works on melee hits
- [ ] Critical hits work on melee
- [ ] Attack cooldown prevents spam
- [ ] Animation plays correctly
- [ ] Sound plays on attack
- [ ] Works in multiplayer (both host and client)
- [ ] Archer still shoots arrows normally

---

## 🎓 Related Files

- `coop/scripts/player_class.gd` - Class combat type definitions
- `coop/scripts/player.gd` - Combat logic implementation
- `coop/scenes/player.tscn` - Player scene setup
- `coop/scripts/enemy.gd` - Enemy take_damage() method

---

## 💡 Design Philosophy

**Why separate ranged and melee?**
- Creates distinct playstyles
- Encourages team composition variety
- Balances risk vs reward (close = dangerous but powerful)
- Enables class-specific upgrades in future
- Makes character choice meaningful beyond just stats

**Why instant damage instead of hitboxes?**
- Simpler to implement
- Better network performance
- More responsive feel
- Easier to balance
- Can add visual effects later without changing logic

---

## 🎉 Benefits

1. **Gameplay Variety** - Different playstyles for different characters
2. **Team Synergy** - Knights tank, archers DPS from range
3. **Risk/Reward** - Melee is riskier but can hit multiple enemies
4. **Upgrade Diversity** - Some upgrades favor melee, others ranged
5. **Replayability** - Try different classes for different experiences

Now your knight character has a complete melee combat system! 🗡️⚔️

