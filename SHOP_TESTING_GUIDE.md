# Shop Testing Guide

## What I Fixed

1. **Added F key input action** - Created `shop_interact` input action in `project.godot` mapped to F key
2. **Updated shop_building.gd** - Changed from `ui_focus_next` to `shop_interact` action
3. **Added collision layers** - Set Area2D to detect players on collision layer 1
4. **Added debug prints** - Added console output to help troubleshoot

## How to Test the Shop

1. **Start the game**
2. **Get some coins** - Press `Backspace` to add 100 coins (debug feature)
3. **Find the shop building** - It's located at position (400, 300) in the example scene (looks like a Barracks building)
4. **Walk close to it** - You should see "Press F to Shop" text appear above the building
5. **Press F** - The shop UI should open

## Console Debug Output

When testing, watch the console for these messages:
- `"Player X entered shop area"` - When you walk near the shop
- `"Showing shop interaction hint for local player"` - When the hint appears
- `"F key pressed near shop!"` - When you press F
- `"Opening shop for player X"` - When the shop opens

## If It Still Doesn't Work

### Check These Things:

1. **Player collision layer** - Make sure your player is on collision layer 1
   - Open `coop/scenes/Characters/player.tscn`
   - Select the player CharacterBody2D node
   - Check that collision layer 1 is enabled

2. **Shop building position** - Make sure the shop building is actually in the scene
   - Open `coop/scenes/example.tscn`
   - Look for the "ShopBuilding" node
   - It should be at position (400, 300)

3. **Area2D collision shape** - Make sure the collision area is large enough
   - The current size is 150x150 pixels
   - Try making it larger if players aren't detected

4. **Multiplayer mode** - Make sure you're testing as the local player
   - The shop only opens for the player with matching peer_id

## Common Issues

**"Press F to Shop" doesn't appear:**
- Player might not be on collision layer 1
- CollisionShape2D might be too small
- Walk directly into the center of the building

**F key doesn't work:**
- Make sure you're seeing the "Press F to Shop" text first
- Check console for "F key pressed near shop!" message
- If nothing appears in console, the input action might not be set up correctly

**Shop opens but is blank:**
- Check browser console for errors
- Make sure ShopManager autoload is registered
- Verify shop_ui.tscn exists and is valid

## Manual Testing Checklist

- [ ] Can see shop building in game
- [ ] "Press F to Shop" appears when near building
- [ ] Pressing F opens shop UI
- [ ] Can see categories (Weapon, Armor, Upgrade, Consumable)
- [ ] Can click on items to see details
- [ ] Can purchase items with coins
- [ ] Stats update after purchase
- [ ] ESC closes shop
- [ ] Can open shop multiple times

## Advanced Debugging

If you still have issues, you can add even more debug output:

```gdscript
# In shop_building.gd _process function, add at the top:
print("Players in range: ", players_in_range.size())
for player in players_in_range:
    print("  - Player: ", player.name, " peer_id: ", player.name.to_int())
```

This will help you see if players are being detected at all.

