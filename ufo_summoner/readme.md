# UFO Summoner

> **On-demand UFO summoning & cattle abduction radar tracking system for Transport Fever 3**  
> **Mod ID**: `aliangliang_ufo_summoner`  
> **Author**: ALiangLiang  
> **Version**: 1.0.0 (Revision 1)

---

## Overview

Transport Fever 3 features an official UFO Easter Egg and the exclusive achievement **"Encounter of the 3rd Kind"** (`ach_ufo`). In the vanilla game, the UFO appears randomly only once every few in-game decades.

UFO Summoner provides a dedicated in-game control panel that allows players to summon the official UFO on demand, monitor its flight trajectory via radar, and smoothly track both the UFO and abducted cattle with the camera.

---

## Features

1. **Top-Left Quick Access Button**:
   - Click the **"UFO"** button in the top-left corner of the game screen to open the control window.
2. **On-Demand Official Summon**:
   - Immediately triggers the official UFO Easter Egg over detected cow pastures without waiting decades for random spawns.
3. **Airspace Radar Tracker**:
   - Real-time detection of active UFOs, target cattle entities, and flight abduction phases (Approaching, Targeting Cow, Abducting Cow!, Leaving Airspace, Despawning).
4. **Dual Smooth Camera Tracking**:
   - One-click smooth camera tracking for either the flying saucer or the targeted cow during beam abduction.
5. **Achievement Helper**:
   - Easily trigger, observe, and click the UFO entity in the game world to unlock the "Encounter of the 3rd Kind" achievement.
6. **Strictly Zero Emojis**:
   - Standard typography with clean brackets to guarantee compatibility with game fonts without missing glyph boxes `[]`.

---

## How to Use

1. **Open the Control Window**:
   - Click the **"UFO"** button in the top-left corner of the game screen.
2. **Summon a UFO**:
   - Click **"Summon UFO"** in the header, or click **"Summon Here"** next to any detected cow pasture in the "Livestock Farms" tab.
   - *Requirement*: Official UFO mechanics require at least one Livestock Farm with cattle on the map.
3. **Track & Observe**:
   - Click **"Follow UFO"** or **"Follow Cow"** to smoothly focus and follow the action.
   - *Tip*: Click directly on the UFO entity in the game world to unlock the achievement!

---

## Directory Structure

```text
ufo_summoner/
├── _metadata/
│   ├── 0.png                         # Mod preview cover image
│   └── modinfo.json                  # Workshop/ModHub metadata and descriptions
├── content/
│   ├── ufo_summoner_toolbar.res.lua  # React UI resource registering MainModButtonAreaExtension
│   ├── ufo_summoner.script.lua       # HUD toggle button and control window recipe
│   ├── ufo_summoner_sim.script.lua   # Background simulation thread script
│   ├── ufo_summoner.lua              # Core UFO summoning, detection, and camera controller
│   └── ufo_summoner.gs.lua           # GameScript engine dispatcher
├── _content.json                     # Resource and file index
├── mod.json                          # Core mod settings
├── strings.json                      # Multi-language translations (13 languages supported)
└── readme.md                         # Mod documentation
```
