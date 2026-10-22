# Animal Radar

> **Full-map wildlife detection radar and smooth camera tracking system for Transport Fever 3**  
> **Mod ID**: `aliangliang_animal_radar`  
> **Author**: ALiangLiang  
> **Version**: 1.0.0 (Revision 1)

---

## Overview

Designed specifically for the official **"Animal Lover"** achievement, Animal Radar adds an in-game radar window that scans all wildlife across the map and organizes them into dynamic tabs grouped by species.

---

## Features

1. **Top-Left Quick Access Button**:
   - Click the "Animal Radar" button in the top-left corner of the game screen to toggle the radar window.
2. **Dynamic Species Tab Navigation**:
   - Automatically generates tabs based on animals actively roaming the current map (e.g. Deer, Brown Bear, Fox, Wolf, Cougar, Crane, Eagle, Seagull, Fish Schools, etc.), displaying entity counts and individual lists.
3. **Instant Camera Jump & Smooth Tracking**:
   - Click "Focus" next to any detected animal to smoothly glide the game camera directly to its position.
4. **Dual Camera Modes**:
   - Switch between **"Follow"** mode (camera dynamically follows the moving animal) and **"Focus"** mode (camera repositions once to the animal's location).
5. **Achievement Helper**:
   - Effortlessly track down and observe every wild animal species on the map to complete the "Animal Lover" achievement.
6. **Strictly Zero Emojis**:
   - Built with plain text formatting and native fonts to avoid missing glyph square boxes `[]`.

---

## How to Use

1. **Open the Radar**:
   - Click the **"Animal Radar"** button in the top-left corner of the game screen.
2. **Filter by Species**:
   - Click any species tab at the top (e.g. "All", "Deer", "Crane") to view only entities of that type.
3. **Observe & Follow**:
   - Click **"Focus"** next to any entry in the list to move your camera directly to that animal.
   - Use the toggle at the top of the window to switch between Follow and Focus camera behaviors.

---

## Directory Structure

```text
animal_radar/
├── _metadata/
│   ├── 0.png                         # Mod preview cover image
│   └── modinfo.json                  # In-game Mod Manager metadata and descriptions
├── content/
│   ├── animal_finder_toolbar.res.lua # React UI resource registering MainModButtonAreaExtension
│   ├── animal_finder.script.lua      # Toolbar toggle button and radar window recipe
│   ├── animal_finder_sim.script.lua  # Background simulation thread script
│   ├── animal_finder.lua             # Core radar scanning algorithms and camera controller
│   └── animal_finder.gs.lua          # GameScript engine dispatcher
├── _content.json                     # Resource and file index
├── mod.json                          # Core mod settings
├── strings.json                      # Multi-language translations (13 languages supported)
└── readme.md                         # Mod documentation
```
