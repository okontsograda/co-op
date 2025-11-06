# Knight Combo System - Dash & Multi-Strike

## Overview
The knight now features an exciting combo system that rewards consecutive attacks with a powerful dash and multiple strikes!

## How It Works

### Basic Attack (Single Click)
- Click once to perform a standard melee attack
- Deals normal damage to enemies in front of the knight
- Standard attack animation and cooldown

### Combo Attack (Double Click - Fast!)
When you click **twice quickly** within **0.8 seconds**, the knight unleashes a **Dash Combo**:

**Important**: You can click the second time even while the first attack is animating! The system will:
- Detect the combo intent immediately
- Cancel the first attack animation
- Launch directly into the dash combo
- This makes the combo very responsive to fast clicking!

1. **Dash Forward** 
   - Knight dashes 150 units in the attack direction
   - Duration: 0.4 seconds
   - **Dynamic animation system** with alternating directions
   - Visual effects: Blue tint + alternating attack animations

2. **Multiple Strikes with Alternating Animations**
   - Performs **3 rapid strikes** during the dash
   - **Strike 1**: Animation plays **forward** at 2.5x speed
   - **Strike 2**: Animation plays **in reverse** at 2.5x speed (slash back!)
   - **Strike 3**: Animation plays **forward** again at 2.5x speed
   - Each strike has a **15% damage bonus** (1.15x multiplier)
   - Wider attack range (120% of normal melee range)
   - Increased attack cone (hits more enemies to the sides)
   - Sound effects play for each strike
   - Creates a dynamic back-and-forth slashing effect

3. **Benefits**
   - Higher total damage output
   - Repositioning advantage
   - Crowd control with knockback
   - Shorter cooldown after combo (0.4s vs 0.6s)
   - Looks and feels awesome!

## Technical Details

### New Variables Added
```gdscript
var last_attack_time: float = 0.0
var combo_count: int = 0
const combo_window: float = 0.8  # Time to continue combo
var is_performing_combo: bool = false
const combo_dash_distance: float = 150.0
const combo_dash_duration: float = 0.4
```

### Combo Tracking & Click Detection
- Tracks time between attacks with millisecond precision
- Resets combo if more than 0.8 seconds pass
- **Special handling for fast clicks**: Melee attacks bypass the normal cooldown check if within combo window
- If second click arrives during first attack animation, it:
  - Immediately cancels the first attack
  - Starts the dash combo without waiting
- This allows for very responsive, fighting-game-style combos

### Combat Flow Protection
- Cannot dodge during combo
- Cannot start new attack during combo
- Movement input is ignored during combo dash
- Combo takes priority over all other movement

### Multiplayer Support
- Fully synchronized across all clients via RPC
- Visual effects and sounds play for all players
- Damage calculation is consistent

## Balance Notes

### Combo Stats
- **Damage Bonus**: +15% per strike (total 3 strikes)
- **Range Bonus**: +20% attack range during dash
- **Cone Bonus**: Wider attack angle (0.15 vs 0.3 dot product)
- **Knockback**: 150 (vs 200 for normal attacks)

### Cooldowns
- **Combo Attack Cooldown**: 5 seconds (special ability cooldown)
- **Normal attack**: 0.6 seconds
- **After combo**: 0.4 seconds (rewards combo usage!)
- **Combo window**: 0.8 seconds

### UI Display
- A special ability UI appears **fixed in the bottom-left corner** for melee characters
- **Stays fixed to camera** (doesn't move when player moves)
- Shows "Dash Combo" with "Double Click" instruction
- **Green background** when ready to use
- **Gray background** with countdown timer when on cooldown
- **Cooldown overlay** fills from bottom to top as ability recharges
- Only visible for local player and only for melee classes
- Positioned 20px from screen edges for clean look

## Tips for Players
1. **Watch the UI**: Keep an eye on the combo attack UI to know when the ability is ready
2. **Timing**: Click twice quickly (within 0.8s) to trigger the combo
3. **Positioning**: Aim toward groups of enemies for maximum effect
4. **Risk vs Reward**: Dashing into enemies can be risky but deals massive damage
5. **Cooldown Management**: Wait for the 5-second cooldown before attempting another combo
6. **Combo Flow**: After the dash, you can immediately start a new combo chain (once cooldown is ready)
7. **Mobility**: Use the dash to reposition quickly in combat or escape dangerous situations
8. **Failed Attempts**: If you try to combo while it's on cooldown, the system will reset your combo count

## Future Enhancements (Optional)
- Add combo counter UI indicator
- Add trail visual effect during dash
- Implement 3-hit or 4-hit combos with different effects
- Add stamina cost for combo moves
- Create different combo patterns based on timing
- Add finishing move for end of combo

## Code Locations

### Main Implementation: `coop/scripts/player.gd`
- Lines 59-68: Combo variables (including cooldown tracking)
- Lines 310-316: Combo cooldown update in `_physics_process()`
- Lines 379-401: `handle_fire_action()` - Allows melee combos to bypass cooldown
- Lines 449-560: `handle_melee_attack()` - Combo detection, cooldown check, and cancellation logic
- Lines 563-635: `perform_dash_combo()` - Main combo dash logic
- Lines 638-689: `perform_dash_strike_damage()` - Damage calculation with combo bonus
- Lines 692-712: `perform_dash_strike_network()` - RPC sync for multiplayer
- Lines 961-965: `update_combo_ui()` - Updates UI cooldown display
- Lines 968-986: `setup_combo_ui()` - Creates and initializes combo UI
- Lines 1297-1299: Hide combo UI in `hide_player_ui()` on death

### UI Files
- **Scene**: `coop/scenes/combo_attack_ui.tscn` - Visual layout
- **Script**: `coop/scripts/combo_attack_ui.gd` - UI update logic
  - `update_cooldown()` - Updates cooldown display and colors
  - Visual states: Green (ready) vs Gray (cooldown)

## Troubleshooting

### Combo Not Triggering?
1. **Check class**: Make sure you're playing as Knight (melee class)
2. **Check cooldown**: Look at the UI - if it's gray with a number, the ability is on cooldown
3. **Click faster**: Try clicking both clicks within 0.5 seconds
4. **Check console**: Look for "Combo attack #1" and "Combo attack #2" messages
5. **Wait for cooldown**: If you see "Combo attack on cooldown!" message, wait for the timer to reach 0
6. **Verify combat type**: Type should be "melee" (printed on character selection)

### No UI Showing?
1. **Class check**: UI only appears for melee classes (Knight)
2. **Local player**: UI only shows for your own character, not other players
3. **Scene reload**: Try restarting the game if UI doesn't appear

### Known Issues Fixed
- ✅ Second click being blocked by cooldown system (FIXED: Melee now bypasses cooldown in combo window)
- ✅ First attack animation delaying combo start (FIXED: Second click cancels first attack)
- ✅ Combo not working with fast clicks (FIXED: Special handling for rapid clicks)
- ✅ Spamming combo attacks (FIXED: 5-second cooldown prevents abuse)

