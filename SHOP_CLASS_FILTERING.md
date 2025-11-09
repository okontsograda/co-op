# Shop Class-Based Filtering System

## Overview
The shop system has been updated to dynamically filter items based on the player's equipped weapon/class. Knights and other melee classes will now see melee-specific items, while archers and ranged classes see ranged-specific items.

## Changes Made

### 1. Shop Manager (`coop/scripts/shop_manager.gd`)

#### Added Weapon Compatibility System
- **New Field**: `compatible_weapons: Array` added to `ShopItem` class
  - Values: `["all"]`, `["bow"]`, `["sword"]`, `["rocket"]`, or combinations
  - Method: `is_compatible_with_weapon(weapon_id: String) -> bool`

#### New Items for Knights/Melee Classes

**Melee Weapons:**
- **Iron Sword** (50 coins): +10 damage, +10% attack speed
- **Battle Sword** (150 coins): +25 damage, +20% attack speed, +15% attack range
- **Legendary Blade** (500 coins): +50 damage, +40% attack speed, +30% attack range

**Melee-Specific Upgrades:**
- **Cleaving Blade** (50 coins): +20% attack range for melee (stackable 5x)
- **Berserker's Rage** (120 coins): +10% damage per enemy in range (max 50%)
- **Shield Bash** (80 coins): Melee attacks knock back enemies
- **Blade Mastery** (100 coins): +30% melee damage (stackable 5x)

#### Updated Existing Items

**Ranged-Only Items** (now properly filtered):
- Better Bow, War Bow, Legendary Bow → `["bow"]`
- Pierce Upgrade → `["bow", "rocket"]`
- Multishot Upgrade → `["bow"]`
- Explosion Upgrade → `["bow", "rocket"]`

**Universal Items** (available to all classes):
- All armor (Leather, Chainmail, Plate)
- All accessories (Ring of Power, Swift Boots, Amulet of Vitality, etc.)
- All consumables (Health Potions)
- Stamina Boost

#### New Filtering Function
```gdscript
func get_items_by_category_and_weapon(category: String, weapon_id: String) -> Array[ShopItem]
```
Returns only items compatible with the specified weapon type.

#### New Stat Handling
- Added `attack_range_mult` bonus handling for melee attack range scaling

### 2. Shop UI (`coop/scripts/shop_ui.gd`)

#### Updated Category Loading
- `load_category()` now gets player's `equipped_weapon`
- Uses `ShopManager.get_items_by_category_and_weapon()` for filtering
- Shows "No items available in this category for your class" when filtered list is empty

## How It Works

1. **Player Selection**: When a player opens the shop, the UI reads their `equipped_weapon` property
2. **Item Filtering**: Items are filtered based on their `compatible_weapons` array
3. **Dynamic Display**: Only compatible items are shown in each category
4. **Purchase Effects**: All stat bonuses are properly applied through `apply_item_effects()`

## Item Categories by Class

### Archer (bow)
- ✅ Bow weapons (Superior, War, Legendary)
- ✅ Bow-specific upgrades (Multishot, etc.)
- ✅ Ranged upgrades (Pierce, Explosion)
- ✅ Universal items (Armor, Accessories, Consumables)
- ❌ Sword weapons and melee upgrades

### Knight (sword)
- ✅ Sword weapons (Iron, Battle, Legendary)
- ✅ Melee-specific upgrades (Cleaving, Berserker, Shield Bash, Blade Mastery)
- ✅ Universal items (Armor, Accessories, Consumables)
- ❌ Bow/Rocket weapons and ranged upgrades

### Rocket Users (rocket)
- ✅ Rocket-compatible upgrades
- ✅ Ranged upgrades (Pierce, Explosion)
- ✅ Universal items
- ❌ Bow/Sword specific items

## Testing

To test the class-based filtering:

1. **As Archer**: 
   - Open shop → Should see bow weapons and ranged upgrades
   - Should NOT see sword weapons or melee upgrades

2. **As Knight**:
   - Open shop → Should see sword weapons and melee upgrades
   - Should NOT see bow weapons, multishot, or pierce upgrades

3. **Universal Items**:
   - All classes should see: Armor, Health Potions, Speed Boots, Ring of Power, etc.

## Future Enhancements

Potential additions:
- Class-specific abilities in shop
- Weapon swap items
- Class-exclusive legendary items
- Visual indicators for class compatibility
- Filter toggle to show "all items" vs "compatible items only"



