# Development Setup — Sabbath - among life and death

## Prerequisites

- **Godot 4.6** (or later 4.x)
- **Operating System:** macOS, Windows, Linux
- **Code Editor:** VS Code (recommended) + GDScript extension

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/AndriiDiabolus/Concept-Dark-Fantasy-.git
cd "Concept-Dark-Fantasy-"
```

### 2. Open in Godot 4.6

1. Launch **Godot 4.6**
2. Click **Open Project**
3. Navigate to `/Users/andriidiablo/Documents/Dark Fantasy concept/`
4. Select `project.godot` and click **Open**

Godot will:
- Scan the project structure
- Load the autoload `C` (constants.gd)
- Initialize the project

### 3. Run the Project

Press **F5** or click the ▶ button in the top-right to start the game.

---

## Project Structure

```
.
├── project.godot              # Godot project config
├── scenes/
│   ├── main.tscn             # Main game scene (TODO: create in editor)
│   ├── player/
│   │   └── player.tscn       # Player character scene (TODO)
│   └── enemies/
│       ├── pehota.tscn       # Footman enemy (TODO)
│       ├── musketeer.tscn    # Ranged enemy (TODO)
│       └── piker.tscn        # Tank enemy (TODO)
├── scripts/
│   ├── constants.gd          # ✅ Global autoload
│   ├── main.gd               # ✅ Game controller
│   ├── player.gd             # TODO: Player controller
│   ├── enemy.gd              # TODO: Base enemy class
│   ├── enemies/
│   │   ├── pehota.gd         # TODO: Footman behavior
│   │   ├── musketeer.gd      # TODO: Ranged behavior
│   │   └── piker.gd          # TODO: Tank behavior
│   └── boss_prince.gd        # TODO: Boss fight controller
├── assets/
│   ├── sprites/              # TODO: Enemy & player sprites (buy from itch.io)
│   ├── sfx/                  # TODO: Sound effects (CC0 from kenney.nl)
│   └── music/                # TODO: Background music
├── gdd/
│   ├── overview.md           # ✅ Game overview
│   ├── gameplay.md           # ✅ Mechanics & controls
│   └── combat_system.md      # ✅ Enemies & boss specs
├── CLAUDE.md                 # ✅ Project rules & history
├── context.md                # ✅ Full game design
└── README.md                 # (this file)
```

---

## Next Steps (Current Priority)

### Phase 1: Player Controller (Week 1-2)

- [ ] Create `scenes/player/player.tscn` (node structure)
- [ ] Implement `scripts/player.gd`:
  - WASD movement (speed: 150 px/sec)
  - Animation state machine (idle → run → attack → block)
  - Basic attack (3-hit combo, 5/5/8 damage)
  - Block mechanic (R key, 50% damage reduction)
  - Dodge passive system (5% per hit chance)

### Phase 2: First Enemy Type (Week 2-3)

- [ ] Create `scenes/enemies/pehota.tscn`
- [ ] Implement `scripts/enemies/pehota.gd`:
  - Spawn & movement (120 px/sec)
  - Chase player when in range (150 px)
  - 3-hit attack combo (0.8 sec cycle)
  - Take damage & death animation
  - XP loot on death

### Phase 3: Game Loop (Week 3-4)

- [ ] Implement level loading in `main.gd`
- [ ] Wave spawning system
- [ ] Score/progress tracking
- [ ] Death/restart screen

### Phase 4: Obsession Mechanic (Week 4-5)

- [ ] Implement obsession scale (0-300 points)
- [ ] V key activation (20 sec duration, 2 min CD)
- [ ] Visual degrade (purple tint progression)
- [ ] Claw damage (2x), speed (1.5x), dash ability
- [ ] Post-activation vulnerability (2 sec on knees)

### Phase 5: Boss Fight (Week 5-6)

- [ ] Implement boss 4-phase fight
- [ ] Each phase with unique mechanics
- [ ] Final berserker moment (uncontrolled obsession)
- [ ] Cutscene/ending

---

## Controls (Final)

| Action | Key | Function |
|--------|-----|----------|
| Move Up | W | Move up |
| Move Down | S | Move down |
| Move Left | A | Move left |
| Move Right | D | Move right |
| Attack | (configurable) | Combo attack |
| Block | R | Reduce damage by 50% |
| Obsession | V | Activate if scale full (20 sec) |
| Interact | I | Open doors, talk to NPCs |
| Pause | ESC | Pause game |

---

## Audio Strategy

All audio will be **CC0 or CC-BY** (free, no commercial restrictions).

**Sources:**
- **Music:** [Kenney.nl](https://kenney.nl) or [Eric Matyas](https://soundimage.org)
- **SFX:** [Kenney.nl](https://kenney.nl), [Freesound.org](https://freesound.org), [ZapSplat](https://www.zapsplat.com)

Example files needed:
- `attack_hit.wav` — slash sound
- `block.wav` — shield impact
- `dodge.wav` — woosh sound
- `obsession_activate.wav` — dark magic sound
- `enemy_die.wav` — enemy death
- `level_complete.wav` — victory sting
- `bg_music_level1.ogg` — atmospheric background loop

---

## Sprites & Art

**Strategy:** Buy ready-made 32-bit pixel art from [itch.io](https://itch.io/game-assets/pixel-art).

**Search terms:**
- "Castlevania-like pixel art sprite sheet"
- "32-bit fantasy character sprites"
- "anime pixel art slasher"
- "dark fantasy warrior sprites"

**Once purchased:**
1. Extract sprite sheets
2. Create atlases in Godot
3. Reference in enemy/player scenes

---

## Testing Checklist

### Manual Testing (per phase)

- [ ] Player moves smoothly (WASD)
- [ ] Attack combo works (3 hits, 5/5/8 damage)
- [ ] Block reduces damage (50%)
- [ ] Dodge fires randomly (5% per enemy attack)
- [ ] Enemy spawns and chases player
- [ ] Enemy takes damage and dies
- [ ] Level completes when enemies defeated
- [ ] Obsession fills from attacks & damage taken
- [ ] V activates obsession (20 sec, 2x damage)
- [ ] Recovery works (2 sec on knees after)

---

## Commands

```bash
# Open project in Godot (from command line)
/Applications/Godot.app/Contents/MacOS/Godot --path "/Users/andriidiablo/Documents/Dark Fantasy concept"

# Run headless export (testing without GUI)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "/Users/andriidiablo/Documents/Dark Fantasy concept" --play

# Export to web (when ready)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "/Users/andriidiablo/Documents/Dark Fantasy concept" --export-release "Web" "export/web/index.html"
```

---

## Common Issues

### Issue: Project doesn't load

**Solution:** Make sure `project.godot` exists and is in the root directory.

### Issue: Constants not loading

**Solution:** Check that `scripts/constants.gd` exists and `autoload` in `project.godot` points to it:
```
[autoload]
C="*res://scripts/constants.gd"
```

### Issue: Scene doesn't exist

**Solution:** Create `scenes/main.tscn` in Godot editor (Scene → New Scene → Save as `main.tscn`).

---

## Quick Start (TL;DR)

1. Open Godot 4.6
2. Open this project (`project.godot`)
3. Press F5 to run
4. Work on `scripts/player.gd` first
5. Create scenes in editor, reference in code

---

**Status:** Alpha Development (v0.1.0)
**Last Updated:** 2026-03-21
