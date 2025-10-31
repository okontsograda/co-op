# 🚀 Quick Start: Adding Knight Character

## Immediate Next Steps

### 1. Reorganize Existing Archer Sprites (IN GODOT EDITOR)

**⚠️ IMPORTANT: Do this in Godot Editor to preserve references!**

Open Godot and do the following:

1. **In FileSystem panel, create folders**:
   ```
   Right-click on "assets" → Create Folder → Name it "Characters"
   Right-click on "Characters" → Create Folder → Name it "Archer"
   ```

2. **Move existing archer sprites** (drag and drop in Godot):
   ```
   tileset/Archer_Idle.png   → assets/Characters/Archer/Archer_Idle.png
   tileset/Archer_Run.png    → assets/Characters/Archer/Archer_Walk.png
   tileset/Archer_Shoot.png  → assets/Characters/Archer/Archer_Shoot.png
   ```

3. **Create Archer SpriteFrames**:
   - Navigate to `assets/Characters/Archer/`
   - Right-click → New Resource → Type "SpriteFrames" → Select it
   - Name it: `archer_sprite_frames.tres`
   - Save (Ctrl+S)

4. **Set up Archer animations**:
   - Double-click `archer_sprite_frames.tres` to open editor
   - **Idle Animation**:
     - Rename "default" to `idle`
     - FPS: `5`
     - Loop: ✓ ON
     - Click "Add frames from sprite sheet"
     - Select `Archer_Idle.png`
     - Horizontal: `6`, Vertical: `1`
     - Click "Add 6 Frame(s)"
   
   - **Walk Animation**:
     - Click "New Animation" (+ icon)
     - Name: `walk`
     - FPS: `10`
     - Loop: ✓ ON
     - Add frames from `Archer_Walk.png` (4 frames)
   
   - **Fire Animation**:
     - Click "New Animation"
     - Name: `fire`
     - FPS: `10`
     - Loop: ✓ ON
     - Add frames from `Archer_Shoot.png` (8 frames)
   
   - Save (Ctrl+S)

---

### 2. Find Knight Sprite Sheets

You need 3 PNG files with knight sprites:

**Recommended Free Sources:**
- [itch.io - Knight Sprite Sheets](https://itch.io/game-assets/free/tag-knight)
- [OpenGameArt - Knight](https://opengameart.org/content/knight-sprite-sheet)
- [Craftpix - Free Knight](https://craftpix.net/freebies/tag/knight/)

**What to look for:**
- ✅ Idle animation (standing still)
- ✅ Walk/Run animation (moving)
- ✅ Attack animation (swinging sword)
- ✅ PNG with transparency
- ✅ Horizontal sprite sheets (frames side by side)
- ✅ Similar size to archer (~192x192 pixels per frame)

---

### 3. Import Knight Sprites

1. **Create Knight folder**:
   - In Godot: `assets/Characters/` → Create Folder → Name it "Knight"

2. **Import your downloaded sprites**:
   - Copy/paste the 3 PNG files into this folder:
     ```
     assets/Characters/Knight/Knight_Idle.png
     assets/Characters/Knight/Knight_Walk.png
     assets/Characters/Knight/Knight_Attack.png
     ```

3. **Create Knight SpriteFrames**:
   - Right-click in Knight folder → New Resource → SpriteFrames
   - Name: `knight_sprite_frames.tres`
   - Set up same 3 animations: `idle`, `walk`, `fire`
   - Use same FPS and Loop settings as Archer

---

### 4. Test It!

1. **Run the game** (F5)
2. **Create or join lobby**
3. **Select "Knight" in class selection**
4. **Click Ready and Start Game**
5. **You should see the Knight sprite!**

---

## 📋 Current Status

✅ Code updated to support multiple character sprites
✅ PlayerClass system configured for 4 characters:
   - Archer (balanced)
   - Knight (high health/damage, slow)
   - Mage (high damage, low health)
   - Tank (very high health, very slow)

⏳ TODO:
- [ ] Move archer sprites to new folder structure
- [ ] Create archer_sprite_frames.tres
- [ ] Find/download knight sprite sheets
- [ ] Import knight sprites
- [ ] Create knight_sprite_frames.tres
- [ ] Test knight in-game
- [ ] (Optional) Add Mage sprites
- [ ] (Optional) Add Tank sprites

---

## 🎨 Sprite Sheet Frame Counts (From Your Archer)

Reference your existing archer sprites for consistency:

```
Archer_Idle.png:  6 frames (192x192 each)
Archer_Walk.png:  4 frames (192x192 each)
Archer_Shoot.png: 8 frames (192x192 each)
```

Try to find knight sprites with similar frame counts for consistency!

---

## 🆘 Quick Troubleshooting

**"Archer doesn't show sprite anymore"**
- You haven't created archer_sprite_frames.tres yet
- Create it following Step 1 above

**"Knight shows archer graphics"**
- Knight sprite_frames path is wrong or missing
- Check: `assets/Characters/Knight/knight_sprite_frames.tres` exists
- Verify animations are named exactly: `idle`, `walk`, `fire`

**"Can't find good knight sprites"**
- Use same archer sprites temporarily to test system works
- Just copy archer_sprite_frames.tres and rename to knight_sprite_frames.tres
- They'll both look the same but you can verify the system works

---

## 💡 Pro Tip: Test with Archer Clone First

Before finding knight sprites, test the system works:

1. Copy `archer_sprite_frames.tres`
2. Paste as `knight_sprite_frames.tres`
3. Test selecting Knight in lobby
4. Both characters will look identical, but you'll know the system works!
5. Then replace knight sprites when you find good ones

---

## 📄 Full Documentation

See `CHARACTER_SETUP_GUIDE.md` for complete detailed instructions.

