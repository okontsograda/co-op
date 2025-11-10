# Consumables System

## Overview
A complete consumables system has been implemented that allows players to purchase, store, and use healing items during gameplay. The system features a UI display with two consumable slots bound to keyboard keys 1 and 2.

## Features

### 1. Consumable UI Display
- **Location**: Upper left corner of the screen, below the wave display
- **Slots**: Two slots (bound to keys 1 and 2)
- **Display Shows**:
  - Key binding (1 or 2)
  - Item name
  - Quantity (x#)
  - Visual feedback (dimmed when empty, bright when filled)

### 2. Inventory System
- **Two Slots**: Players can hold up to 2 different consumable types
- **Stacking**: Multiple units of the same item stack in a single slot
- **Smart Assignment**: Items automatically assign to appropriate slots
  - If slot has same item: increases quantity
  - If slot is empty: assigns to that slot
  - If different items in both slots: replaces the current slot

### 3. Shop Integration
- **Consumable Items Available**:
  - **Health Potion**: Restores 50 HP (20 coins)
  - **Greater Health Potion**: Restores full HP (40 coins)
- **Unlimited Purchases**: Consumables can be purchased multiple times
- **Instant Inventory Add**: Purchased consumables go directly to inventory slots

### 4. Usage Mechanics
- **Input**: Press `1` or `2` to use consumable in that slot
- **Cooldown**: 0.5 second cooldown between uses (prevents spam)
- **Smart Healing**: Won't use healing items if already at full health
- **Server Authoritative**: All consumable usage is validated server-side for security
- **Multiplayer Synced**: Consumable inventory syncs across all clients

### 5. Visual Feedback
- **Key Indicators**: Yellow key labels (1 and 2) on each slot
- **Item Names**: Displayed clearly for each slot
- **Quantity Display**: Shows "x#" count
- **Empty State**: Shows "Empty" text and dimmed panel when no item
- **Full State**: Bright, fully visible panel when item is present

## Implementation Details

### Files Created
1. **coop/scripts/consumables_display.gd**
   - UI controller for the consumables display
   - Manages slot updates and visual state

2. **coop/scenes/consumables_display.tscn**
   - UI scene with two slot panels
   - Positioned below wave display (top-left)

### Files Modified
1. **coop/scripts/player.gd**
   - Added consumable inventory system (2 slots)
   - Added keyboard input handling (keys 1 and 2)
   - Added consumable usage functions with server validation
   - Added RPC functions for multiplayer sync
   - Added cooldown system
   - Integrated setup in _ready() function

2. **coop/scripts/shop_manager.gd**
   - Modified consumable handling to add to inventory instead of instant use
   - Changed `apply_item_effects()` for consumable category

## How to Use

### For Players
1. **Purchase Consumables**:
   - Open shop during rest wave (press B near shop building)
   - Navigate to "Consumable" category
   - Purchase Health Potion or Greater Health Potion
   - Items automatically go to your consumable slots

2. **Use Consumables**:
   - Press `1` to use item in slot 1
   - Press `2` to use item in slot 2
   - Healing occurs immediately (if not at full health)
   - Quantity decreases by 1
   - Empty slots auto-clear

3. **Check Inventory**:
   - Look at top-left corner of screen
   - See both consumable slots at all times
   - Monitor quantities

### For Developers

#### Adding New Consumable Types
1. Add new item to `shop_manager.gd` in `_initialize_items()`:
```gdscript
items["new_consumable"] = ShopItem.new(
    "new_consumable",
    "Consumable Name",
    "Description",
    cost,
    "consumable",
    -1,  # Unlimited purchases
    {"instant_heal": heal_amount}  # or other effects
)
```

2. Add effect handling in `player.gd` `_server_use_consumable()`:
```gdscript
if item.stat_bonuses.has("your_effect"):
    # Apply your effect here
    pass
```

#### Customizing UI
- Edit `coop/scenes/consumables_display.tscn` for positioning/styling
- Modify `consumables_display.gd` for display logic
- Current position: (10, 90) for slot 1, (10, 150) for slot 2

## Technical Architecture

### Security Features
- **Server-Authoritative**: All consumable usage validated on server
- **Sender Verification**: RPCs verify sender is the owning player
- **Inventory Validation**: Server checks slot contents before use
- **Synchronized State**: All clients receive authoritative updates

### Network Architecture
1. **Client Input**: Player presses 1 or 2
2. **Client Request**: Calls `use_consumable()` → RPC to server
3. **Server Validation**: `_server_use_consumable()` validates and applies
4. **Server Broadcast**: Syncs new slot state to all clients
5. **Client Update**: All clients update UI and local state

### Cooldown System
- Prevents spam usage
- Updates in `_physics_process()`
- 0.5 second duration (configurable)
- Applied after successful use

## Testing Checklist
- [x] UI displays correctly on screen
- [x] Purchasing consumables adds to inventory
- [x] Pressing 1 and 2 uses correct slot items
- [x] Healing works and respects max health
- [x] Quantity decrements after use
- [x] Empty slots display correctly
- [x] Cooldown prevents spam
- [x] Multiplayer sync works correctly
- [x] Server validation prevents cheating
- [x] Multiple item types work in different slots

## Known Limitations
1. Only 2 consumable slots (intentional design choice)
2. Currently only healing consumables implemented
3. No drag-and-drop or slot swapping (use shop to change)
4. No consumable persistence between game sessions

## Future Enhancements
- Additional consumable types (damage buffs, speed boosts, etc.)
- Visual effects on consumable use
- Sound effects for consumption
- Consumable cooldown visual indicator
- Per-consumable cooldowns
- Hotkey rebinding
- Consumable persistence in save system

