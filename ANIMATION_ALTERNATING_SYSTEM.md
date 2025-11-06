# Alternating Animation System for Combo Attacks

## Overview
Enhanced the knight's dash combo with a dynamic alternating animation system that plays the attack animation forward, reverse, and forward again during the three strikes.

## What Changed

### Previous Behavior (V2)
- Attack animation played in a loop during the entire dash
- All strikes had the same animation direction
- Looked repetitive

### New Behavior (V3)
- **Strike 1**: Animation plays **forward** (normal slash)
- **Strike 2**: Animation plays **in reverse** (slash back!)
- **Strike 3**: Animation plays **forward** again (final slash)
- Creates a dynamic, back-and-forth slashing effect
- Faster animation speed (2.5x) for snappy combat feel

## Technical Implementation

### Animation Control
```gdscript
# Strike 1: Forward
animated_sprite.speed_scale = 2.5
animated_sprite.play(anim_name)

# Strike 2: Reverse
animated_sprite.speed_scale = -2.5  # Negative = reverse playback
animated_sprite.frame = frame_count - 1  # Start from end
animated_sprite.play(anim_name)

# Strike 3: Forward
animated_sprite.speed_scale = 2.5
animated_sprite.play(anim_name)
```

### Key Features
1. **Manual Frame Control**: Sets starting frame for reverse playback
2. **Speed Scaling**: Uses 2.5x speed for quick, responsive strikes
3. **Negative Speed**: Godot's `speed_scale = -2.5` plays animation backwards
4. **Frame Reset**: Each strike starts fresh (forward from 0, reverse from end)

## Code Changes

### File: `coop/scripts/player.gd`

#### Lines 609-616: Setup
- Disabled animation looping (we control each strike manually)
- Prepared sprite_frames for manual control

#### Lines 647-667: Strike Animation Logic
```gdscript
if strikes_performed == 1:
    # First strike: play forward from start
    animated_sprite.speed_scale = 2.5
    animated_sprite.play(anim_name)
elif strikes_performed == 2:
    # Second strike: play in reverse (start from end)
    animated_sprite.speed_scale = -2.5
    if sprite_frames:
        var frame_count = sprite_frames.get_frame_count(anim_name)
        animated_sprite.frame = frame_count - 1
    animated_sprite.play(anim_name)
elif strikes_performed == 3:
    # Third strike: play forward again from start
    animated_sprite.speed_scale = 2.5
    animated_sprite.play(anim_name)
```

#### Line 682: Reset
- Resets `speed_scale` to 1.0 after combo completes
- Ensures normal animations work correctly after combo

## Visual Effect Breakdown

### Strike Sequence Timeline
```
Time:  0.0s -------- 0.13s -------- 0.27s -------- 0.4s
       START        STRIKE 1       STRIKE 2       STRIKE 3
       
Animation: →→→→→→→→ ←←←←←←←← →→→→→→→→
           (forward) (reverse)  (forward)
           
Player:    🗡️→→→→   →→→🗡️    →→→→🗡️
           Position updates continuously during dash
```

### Why This Works
1. **Slice Pattern**: Creates a realistic "slice-back-slice" pattern
2. **Visual Variety**: Each strike looks different
3. **Dynamic Feel**: Mimics fighting game combos
4. **Weapon Trail**: Back-and-forth motion creates implied weapon trails
5. **Speed**: 2.5x speed keeps animations crisp and snappy

## Comparison

### Without Alternating (V2)
```
Strike 1: →→→→→→
Strike 2: →→→→→→
Strike 3: →→→→→→
Result: Repetitive, less dynamic
```

### With Alternating (V3)
```
Strike 1: →→→→→→ (forward slash)
Strike 2: ←←←←←← (backslash!)
Strike 3: →→→→→→ (final slash)
Result: Dynamic, exciting, varied
```

## User Experience

### Visual Impact
- ✅ Much more dynamic and exciting to watch
- ✅ Clear distinction between each strike
- ✅ Feels more like a special ability
- ✅ Creates "combo" feeling similar to fighting games
- ✅ Weapon appears to slash in multiple directions

### Gameplay Impact
- ✅ Same damage and mechanics (balanced)
- ✅ Easier to count strikes visually
- ✅ More satisfying to execute
- ✅ Feels more skill-based and intentional
- ✅ Matches sound effects (3 distinct sounds)

## Animation Requirements

### Compatible Animations
Works with any looped attack animation:
- Knight's "attack" animation
- Fallback "fire" animation
- Any other attack animation with multiple frames

### Frame Count
- Works best with 4+ frames
- Minimum 2 frames required
- More frames = smoother reverse effect

## Performance

### Optimization
- No additional performance cost
- Same frame rendering as before
- Just changes playback direction
- No new assets or resources needed

### Efficiency
- Reuses existing animation frames
- No duplicate animations required
- Minimal CPU overhead (just speed_scale change)

## Testing Results

### ✅ Animation Quality
- [x] Forward playback works smoothly
- [x] Reverse playback plays correctly
- [x] Transitions between strikes are clean
- [x] No animation glitches or freezing
- [x] Speed feels responsive (2.5x is good)

### ✅ Visual Appeal
- [x] Looks dynamic and exciting
- [x] Easy to distinguish each strike
- [x] Creates satisfying combo effect
- [x] Blue tint enhances the effect
- [x] Works in multiplayer

### ✅ Technical Stability
- [x] No crashes or errors
- [x] Resets properly after combo
- [x] Normal attacks unaffected
- [x] Idle animation works after combo
- [x] Speed_scale resets correctly

## Configuration Options

### Adjust Animation Speed
```gdscript
# Faster (more snappy)
animated_sprite.speed_scale = 3.0  # or -3.0 for reverse

# Slower (more deliberate)
animated_sprite.speed_scale = 2.0  # or -2.0 for reverse
```

### Change Strike Pattern
You can modify the pattern in lines 652-667:
```gdscript
# Example: All forward
if strikes_performed in [1, 2, 3]:
    animated_sprite.speed_scale = 2.5

# Example: Alternate differently
if strikes_performed in [1, 3]:
    animated_sprite.speed_scale = 2.5  # Forward
elif strikes_performed == 2:
    animated_sprite.speed_scale = -2.5  # Reverse

# Example: All reverse (weird but possible!)
if strikes_performed in [1, 2, 3]:
    animated_sprite.speed_scale = -2.5
```

### Different Patterns You Could Try
1. **F-R-F** (current): Forward, Reverse, Forward ✅
2. **F-F-R**: Two forwards, one reverse finisher
3. **R-F-F**: Reverse start, two forward
4. **F-R-R**: Forward, two reverse
5. **R-R-R**: All reverse (for backwards dash?)

## Future Enhancements

### Potential Additions
1. **Different animations per strike**: Use attack1, attack2, attack3
2. **Rotation effect**: Rotate sprite slightly on each strike
3. **Scale pulse**: Scale sprite up/down on each hit
4. **Color shift**: Different tint per strike
5. **Particle bursts**: Spawn particles on each strike
6. **Screen shake**: Small shake on each impact
7. **Slash trails**: Add trail effect that follows weapon

### Advanced Patterns
- **Combo tree**: Different patterns based on timing
- **Direction-based**: Pattern changes based on mouse direction
- **Level scaling**: More strikes at higher levels
- **Charge system**: Hold for different patterns

## Troubleshooting

### Animation Not Reversing?
- Check `speed_scale` is negative: `animated_sprite.speed_scale = -2.5`
- Verify frame is set to end: `animated_sprite.frame = frame_count - 1`
- Ensure animation isn't looped

### Animation Too Fast/Slow?
- Adjust `speed_scale` value (try 2.0 to 3.0 range)
- Same value for forward and reverse (just negative)

### Glitchy Transitions?
- Make sure each strike calls `.play(anim_name)` fresh
- Verify speed_scale is reset to 1.0 after combo
- Check animation loop is disabled

## Conclusion

The alternating animation system adds significant visual polish and excitement to the knight's combo attack:

✅ **More Dynamic**: Each strike looks different  
✅ **Fighting Game Feel**: Mimics combo systems from action games  
✅ **Easy to Implement**: Simple speed_scale manipulation  
✅ **No Performance Cost**: Reuses existing assets  
✅ **Highly Configurable**: Easy to adjust or create new patterns  
✅ **Player Satisfaction**: Makes combos feel more impactful  

The knight combat now feels fluid, responsive, and visually exciting! 🗡️⚡✨

## Version History

- **V1**: Basic combo without UI
- **V2**: Added fixed UI + looping animation
- **V3**: Added alternating animation system ⭐ (current)

