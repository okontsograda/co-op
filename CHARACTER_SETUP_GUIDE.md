# Character Sprite Setup Guide

This guide explains how to add new characters (Archer, Knight, Mage, Tank) to your game with unique sprites and animations.

## 📁 Folder Structure

Organize your character sprites like this:

```
assets/
└── Characters/
    ├── Archer/
    │   ├── Archer_Idle.png         (sprite sheet)
    │   ├── Archer_Walk.png         (sprite sheet)
    │   ├── Archer_Shoot.png        (sprite sheet)
    │   └── archer_sprite_frames.tres  (SpriteFrames resource)
    │
    ├── Knight/
    │   ├── Knight_Idle.png         (sprite sheet)
    │   ├── Knight_Walk.png         (sprite sheet)
    │   ├── Knight_Attack.png       (sprite sheet)
    │   └── knight_sprite_frames.tres  (SpriteFrames resource)
    │
    ├── Mage/
    │   ├── Mage_Idle.png
    │   ├── Mage_Walk.png
    │   ├── Mage_Cast.png
    │   └── mage_sprite_frames.tres
    │
    └── Tank/
        ├── Tank_Idle.png
        ├── Tank_Walk.png
        ├── Tank_Attack.png
        └── tank_sprite_frames.tres
```

## 🎨 Sprite Sheet Requirements

Each character needs **3 sprite sheets** with the following animations:

### Required Animations:
1. **idle** - Character standing still (6-8 frames recommended)
2. **walk** - Character walking (4-8 frames recommended)
3. **fire** or **attack** - Character attacking (6-10 frames recommended)

### Sprite Sheet Format:
- **Horizontal sprite sheets** (frames arranged left to right)
- All frames should be the **same size** (e.g., 192x192 pixels)
- PNG format with transparency
- Consistent frame size across all animations for a character

### Example Knight Sprite Sheet Layout:
```
Knight_Idle.png:   [Frame1][Frame2][Frame3][Frame4][Frame5][Frame6]
Knight_Walk.png:   [Frame1][Frame2][Frame3][Frame4]
Knight_Attack.png: [Frame1][Frame2][Frame3][Frame4][Frame5][Frame6][Frame7][Frame8]
```

---

## 🔧 Step-by-Step Setup Instructions

### Step 1: Move Existing Archer Sprites

1. **Create the folder structure**:
   - Right-click `assets` folder → Create Folder → Name it `Characters`
   - Inside `Characters`, create folder named `Archer`

2. **Move your existing archer sprites**:
   - Move `tileset/Archer_Idle.png` → `assets/Characters/Archer/Archer_Idle.png`
   - Move `tileset/Archer_Run.png` → `assets/Characters/Archer/Archer_Walk.png` (rename Run to Walk)
   - Move `tileset/Archer_Shoot.png` → `assets/Characters/Archer/Archer_Shoot.png`

3. **Godot will automatically update references** when you move files in the editor

---

### Step 2: Create Archer SpriteFrames Resource (Use as Template)

1. **In Godot Editor**:
   - Navigate to `assets/Characters/Archer/`
   - Right-click → Create New Resource
   - Search for and select `SpriteFrames`
   - Name it `archer_sprite_frames.tres`

2. **Open the SpriteFrames editor**:
   - Double-click `archer_sprite_frames.tres`
   - You'll see the SpriteFrames panel at the bottom

3. **Create the "idle" animation**:
   - In the Animations list, click the default animation and rename it to `idle`
   - Set FPS to `5` (or desired speed)
   - Check "Loop" checkbox
   - Click "Add frames from sprite sheet" button
   - Select `Archer_Idle.png`
   - Set Horizontal/Vertical frames (e.g., 6 horizontal, 1 vertical for 6 frames)
   - Click "Add X Frame(s)"

4. **Create the "walk" animation**:
   - Click "New Animation" button
   - Name it `walk`
   - Set FPS to `10`
   - Check "Loop"
   - Add frames from `Archer_Walk.png` sprite sheet

5. **Create the "fire" animation**:
   - Click "New Animation" button
   - Name it `fire`
   - Set FPS to `10`
   - Check "Loop"
   - Add frames from `Archer_Shoot.png` sprite sheet

6. **Save** (Ctrl+S)

---

### Step 3: Add Knight Sprites

1. **Find or create Knight sprite sheets**:
   - You need PNG files with knight animations
   - Must have the same 3 animations: Idle, Walk, Attack
   - Recommended sources:
     - [itch.io](https://itch.io/game-assets/free/tag-sprite-sheet) (search "knight sprite sheet")
     - [OpenGameArt.org](https://opengameart.org/)
     - [Kenney.nl](https://kenney.nl/assets)

2. **Import Knight sprites**:
   - Create folder: `assets/Characters/Knight/`
   - Import your PNG files:
     - `Knight_Idle.png`
     - `Knight_Walk.png`
     - `Knight_Attack.png`

3. **Create Knight SpriteFrames**:
   - Right-click in Knight folder → Create New Resource → SpriteFrames
   - Name it `knight_sprite_frames.tres`
   - Follow the same steps as Step 2 to create animations
   - **IMPORTANT**: Use the same animation names:
     - `idle`
     - `walk`
     - `fire` (even though it's a melee attack)

4. **Verify animations work**:
   - Test by previewing in the SpriteFrames editor

---

### Step 4: Update Player Scene (If Needed)

Your `player.tscn` should already work, but verify:

1. Open `coop/scenes/player.tscn`
2. Select the `AnimatedSprite2D` node
3. Make sure it's using the Archer sprite frames by default
4. The code will automatically swap sprites based on class selection

---

### Step 5: Test in Lobby

1. **Run the game**
2. **Join lobby**
3. **Select "Archer" class** - Should show archer sprites
4. **Select "Knight" class** - Should show knight sprites
5. **Start game** - Character should spawn with correct sprites
6. **Test animations**:
   - Standing still → plays "idle"
   - Moving → plays "walk"
   - Attacking → plays "fire"

---

## 🎯 Quick Checklist for Adding New Characters

For each character (Knight, Mage, Tank):

- [ ] Create folder: `assets/Characters/[CharacterName]/`
- [ ] Add 3 sprite sheets:
  - [ ] `[CharacterName]_Idle.png`
  - [ ] `[CharacterName]_Walk.png`
  - [ ] `[CharacterName]_Attack.png`
- [ ] Create SpriteFrames resource:
  - [ ] Name: `[character_name]_sprite_frames.tres` (lowercase)
  - [ ] Animation: `idle` (looping, 5-8 FPS)
  - [ ] Animation: `walk` (looping, 8-10 FPS)
  - [ ] Animation: `fire` (looping, 8-10 FPS)
- [ ] Verify the path matches in `player_class.gd`
- [ ] Test in lobby and in-game

---

## 🔍 Troubleshooting

### "Failed to load sprite frames" Error
- Check the path in `player_class.gd` matches your file exactly
- Verify the `.tres` file exists at the specified path
- Make sure you saved the SpriteFrames resource

### Animations Not Playing
- Verify animation names are exactly: `idle`, `walk`, `fire`
- Check that Loop is enabled for all animations
- Ensure sprite sheets were imported correctly

### Sprites Appear Stretched or Wrong Size
- Check that all frames in your sprite sheet are the same size
- Verify you entered correct horizontal/vertical frame counts
- Adjust the `scale` property on the AnimatedSprite2D in player.tscn if needed

### Knight Sprite Shows Archer Graphics
- Make sure the SpriteFrames path is correct in `player_class.gd`
- Verify `knight_sprite_frames.tres` exists and has animations
- Check the class selection is being applied (watch console logs)

---

## 📝 Example: Converting a Sprite Sheet

If you download a sprite sheet like this:
```
knight_all.png (one big image with all animations)
```

You need to **split it** into separate files:

### Option 1: Use Image Editor (GIMP, Photoshop, etc.)
1. Open `knight_all.png`
2. Crop out the idle animation frames
3. Save as `Knight_Idle.png`
4. Repeat for walk and attack animations

### Option 2: Use Godot AtlasTexture (Advanced)
- Instead of separate PNG files, you can use one large sprite sheet
- Create AtlasTexture resources for each frame
- Add AtlasTextures to SpriteFrames instead of sprite sheets
- See existing player.tscn for reference (uses AtlasTexture)

---

## 🎨 Recommended Sprite Sheet Resources

### Free Sprite Sheets Compatible with Your Game:
- **itch.io Character Packs**: Many have Idle, Walk, Attack animations
- **Pixel Adventure Assets**: Similar style to your archer
- **Kenny Character Assets**: Simple, clean pixel art
- **OpenGameArt Character Sprites**: Various styles

### What to Look For:
- ✅ Horizontal sprite sheets (frames side-by-side)
- ✅ Transparent background (PNG)
- ✅ At least 3 animations (Idle, Walk, Attack)
- ✅ Similar size to your archer sprites (~192x192 per frame)
- ✅ Top-down or side view perspective

---

## 💡 Pro Tips

1. **Consistent Frame Sizes**: Make all characters use the same frame size for easier management

2. **Sprite Scale**: If knight sprites are bigger/smaller, adjust in code:
   ```gdscript
   # In player_class.gd, add sprite_scale:
   "knight": {
       "sprite_scale": Vector2(0.8, 0.8)  # 80% size
   }
   ```

3. **Animation Speed**: Adjust FPS in SpriteFrames to make animations faster/slower

4. **Test Early**: Create one character fully before adding others

5. **Backup**: Save copies of your sprite sheets before editing

---

## ✅ You're Done!

Once you complete these steps for Knight, Mage, and Tank, players will be able to:
- Select their character class in the lobby
- See unique sprites for each character
- Play with different character visuals that match their class stats

Need help? Check the Godot documentation for SpriteFrames:
https://docs.godotengine.org/en/stable/classes/class_spriteframes.html

