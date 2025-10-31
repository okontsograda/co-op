#!/usr/bin/env python3
import re

# Patterns to remove (verbose debug prints)
remove_patterns = [
    r'^\s*print\("Player.*melee attacking.*$',
    r'^\s*print\("Player.*firing.*$',
    r'^\s*print\("Player.*finished.*$',
    r'^\s*print\("Player.*can.*again.*$',
    r'^\s*print\("Player.*rapid fire.*$',
    r'^\s*print\("Player.*cannot attack.*$',
    r'^\s*print\("Player.*handling chat.*$',
    r'^\s*print\("This is our own message.*$',
    r'^\s*print\("Message from another.*$',
    r'^\s*print\("Chat bubble found.*$',
    r'^\s*print\("Found.*player.*$',
    r'^\s*print\("Network spawn request.*$',
    r'^\s*print\("Network melee attack.*$',
    r'^\s*print\("Ignoring RPC.*$',
    r'^\s*print\("=== MELEE DAMAGE.*$',
    r'^\s*print\("Base attack_damage.*$',
    r'^\s*print\("Weapon bonus damage.*$',
    r'^\s*print\("Damage multiplier.*$',
    r'^\s*print\("Calculated damage.*$',
    r'^\s*print\("Final damage.*$',
    r'^\s*print\("CRITICAL HIT!.*$',
    r'^\s*print\("==.*$',
    r'^\s*print\("Melee hit enemy.*$',
    r'^\s*print\("Melee attack missed.*$',
    r'^\s*print\("Melee attack hit.*$',
    r'^\s*print\("Playing.*animation.*$',
    r'^\s*print\("Returned to idle.*$',
    r'^\s*print\("Attached camera.*$',
    r'^\s*print\("Created camera.*$',
    r'^\s*print\("Player.*took.*damage.*$',
    r'^\s*print\("Synced health.*$',
    r'^\s*print\("Player.*healed.*$',
    r'^\s*print\("Player.*collected.*coin.*$',
    r'^\s*print\("Coin display created.*$',
    r'^\s*print\("Wave display created.*$',
    r'^\s*print\("Player.*received chat.*$',
    r'^\s*print\("Sender player not found.*$',
    r'^\s*print\("Player ', name, " \(peer.*$',
]

files_to_clean = ['player.gd', 'enemy.gd', 'network_handler.gd', 'arrow.gd']

for filename in files_to_clean:
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        new_lines = []
        for line in lines:
            should_keep = True
            for pattern in remove_patterns:
                if re.match(pattern, line):
                    should_keep = False
                    break
            if should_keep:
                new_lines.append(line)
        
        with open(filename, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        
        removed_count = len(lines) - len(new_lines)
        print(f"Cleaned {filename}: removed {removed_count} debug prints")
    except FileNotFoundError:
        print(f"Skipping {filename} (not found)")

print("Cleanup complete!")

