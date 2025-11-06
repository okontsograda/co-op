# Shop System Documentation

## Overview
The shop system allows players to spend coins they've collected to purchase weapons, armor, upgrades, and consumables. Players can walk up to a shop building and press **F** to open the shop interface.

## Files Created

### Scripts
- `coop/scripts/shop_manager.gd` - Autoload singleton that manages shop items, purchases, and player inventories
- `coop/scripts/shop_building.gd` - Script for the interactive shop building
- `coop/scripts/shop_ui.gd` - Script for the shop user interface

### Scenes
- `coop/scenes/shop_building.tscn` - The shop building scene (uses Barracks sprite)
- `coop/scenes/shop_ui.tscn` - The shop UI interface

## How to Use

### For Players
1. **Collect Coins**: Kill enemies to collect coins
2. **Find the Shop**: Look for the Barracks building in the game world
3. **Interact**: Walk up to the building and press **F** to open the shop
4. **Browse**: Click on category tabs (Weapon, Armor, Upgrade, Consumable) to see available items
5. **Purchase**: Click on an item to see details, then click "Purchase" if you can afford it
6. **Close**: Press **ESC** or click the **X** button to close the shop

### For Developers

#### Adding New Items
Edit `shop_manager.gd` in the `_initialize_items()` function:

```gdscript
items["my_item"] = ShopItem.new(
    "my_item",                  # Item ID (unique)
    "My Awesome Item",          # Display name
    "+50 damage, +10% speed",   # Description
    100,                        # Cost in coins
    "upgrade",                  # Category: weapon, armor, upgrade, consumable
    3,                          # Max purchases (-1 for unlimited)
    {                           # Stat bonuses dictionary
        "damage": 50,
        "speed_mult": 0.1
    }
)
```

#### Available Stat Bonuses
The following stat bonuses are automatically applied when purchased:

**Combat Stats:**
- `damage`: Flat damage increase to `attack_damage`
- `damage_mult`: Multiplier bonus to `weapon_stats.damage_multiplier`
- `fire_rate_mult`: Multiplier to `weapon_stats.fire_cooldown` (lower = faster)
- `pierce`: Increase `weapon_stats.pierce_count`
- `multishot`: Increase `weapon_stats.multishot_count`

**Defense Stats:**
- `max_health`: Increase `max_health` and `current_health`
- `damage_reduction`: Percentage damage reduction (not yet fully implemented)

**Mobility Stats:**
- `speed_mult`: Increase `class_speed_modifier`
- `max_stamina`: Increase `max_stamina` and `current_stamina`
- `stamina_regen_mult`: Multiplier to `stamina_regen_rate`

**Special Stats:**
- `lifesteal`: HP gained per enemy hit
- `crit_chance`: Critical hit chance (0.0 to 1.0)
- `crit_mult`: Additional critical damage multiplier
- `explosion_chance`: Chance for projectiles to explode
- `coin_mult`: Coin drop multiplier (not yet implemented)
- `xp_mult`: XP gain multiplier (not yet implemented)

**Consumable Stats:**
- `instant_heal`: Instantly heal HP (999999 for full heal)

#### Placing Shop Buildings
1. Open your level scene in Godot
2. Instance `res://coop/scenes/shop_building.tscn`
3. Position it where you want players to access the shop
4. The building automatically handles player interaction

## Current Shop Items

### Weapons
- **Superior Bow** (50 coins): +10 damage, +20% fire rate
- **War Bow** (150 coins): +25 damage, +30% fire rate, +1 pierce
- **Legendary Bow** (500 coins): +50 damage, +50% fire rate, +2 pierce, +1 multishot

### Armor
- **Leather Armor** (30 coins): +20 max HP
- **Chainmail Armor** (100 coins): +50 max HP, +5% damage reduction
- **Plate Armor** (300 coins): +100 max HP, +15% damage reduction

### Upgrades
- **Ring of Power** (80 coins, max 3): +15% damage
- **Swift Boots** (60 coins, max 2): +20% movement speed
- **Amulet of Vitality** (120 coins, max 2): +50 max HP, +3 HP regen per hit
- **Critical Pendant** (200 coins): +20% crit chance, +50% crit damage
- **Lucky Coin** (100 coins, max 3): +50% coin drops
- **Tome of Knowledge** (150 coins, max 3): +30% XP gain
- **Piercing Upgrade** (50 coins, max 5): +1 pierce count
- **Multishot Upgrade** (100 coins, max 3): +1 arrow per shot
- **Explosive Ammo** (150 coins, max 5): +20% explosion chance
- **Stamina Boost** (80 coins, max 3): +50 max stamina, +50% stamina regen

### Consumables
- **Health Potion** (20 coins, unlimited): Instantly restore 50 HP
- **Greater Health Potion** (40 coins, unlimited): Instantly restore to full HP

## Shop Manager API

### Check Affordability
```gdscript
if ShopManager.can_afford(player, "item_id"):
    print("Player can afford this item")
```

### Check Purchase Limit
```gdscript
if ShopManager.has_max_purchases(player_name, "item_id"):
    print("Player has reached max purchases")
```

### Purchase Item
```gdscript
var success = ShopManager.purchase_item(player, "item_id")
if success:
    print("Purchase successful!")
```

### Get Purchase Count
```gdscript
var count = ShopManager.get_purchase_count(player_name, "item_id")
print("Player has purchased this item ", count, " times")
```

### Reset Purchases
```gdscript
# Reset specific player
ShopManager.reset_player_purchases(player_name)

# Reset all players
ShopManager.reset_all_purchases()
```

## Multiplayer Support
The shop system is fully multiplayer-compatible:
- Each player has their own coin balance
- Purchases are tracked per player
- Coin syncing is handled automatically via RPC
- Shop UI only shows for the player who opened it

## Future Enhancements
- Add item icons/sprites
- Implement coin and XP multipliers in collection code
- Add purchase sound effects
- Add visual feedback when purchasing
- Add "sell back" functionality
- Add item tooltips with detailed stat breakdowns
- Add item rarity system with color coding
- Add daily/rotating shop items
- Add shop keeper NPC with dialogue

## Integration Notes

### Input Actions
The shop uses the `ui_focus_next` action (F key) for interaction. If this doesn't work, add a custom input action in `project.godot`:

```
shop_interact={
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":70,"key_label":0,"unicode":102,"location":0,"echo":false,"script":null)]
}
```

Then update `shop_building.gd` line 51 to use `"shop_interact"` instead of `"ui_focus_next"`.

### Autoload Registration
The ShopManager is registered as an autoload in `project.godot`. If it's not working, ensure this line exists:

```
ShopManager="*res://coop/scripts/shop_manager.gd"
```

## Troubleshooting

**Shop doesn't open when pressing F:**
- Ensure you're standing close to the shop building
- Check if the player has authority (only local player can open their shop)
- Verify the collision shape on the shop building is large enough

**Items don't affect player stats:**
- Check the console for "Applying effects for [item name]" messages
- Ensure the stat bonus keys match the available bonuses in `apply_item_effects()`
- Verify the player has the stats you're trying to modify

**Purchase button is disabled:**
- Check if player has enough coins
- Check if item has reached max purchases
- Verify the item exists in ShopManager

**UI doesn't display correctly:**
- Ensure `shop_ui.tscn` nodes are properly connected
- Check if the CanvasLayer is at a high enough layer (100)
- Verify all Label and Button references exist

## Testing
To test the shop system:
1. Start the game
2. Use console commands to give yourself coins (or kill enemies)
3. Walk up to the shop building
4. Press F to open the shop
5. Try purchasing different items
6. Verify stats are applied correctly
7. Test max purchase limits
8. Test consumables
9. Test with multiple players in multiplayer

## Credits
Shop system designed for a co-op survival game with upgrade mechanics.

