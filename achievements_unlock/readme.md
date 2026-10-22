# Achievements Unlock

> **In-game achievement overview and one-click instant unlock utility for Transport Fever 2 & 3**  
> **Mod ID**: `aliangliang_achievements_unlock`  
> **Author**: ALiangLiang  
> **Version**: 1.0.0 (Revision 1)

---

## Overview

Achievements Unlock adds a clean, native in-game interface allowing players to view all official game achievements in real time and unlock any individual or remaining locked achievements with a single click.

It also includes a thoughtful confirmation dialog addressed to perfectionists, preventing accidental irreversible unlocks.

---

## Features

1. **Top-Left Quick Access Button**:
   - Access the achievement manager anytime via the dedicated "Achievements" button in the top-left corner of the game screen.
2. **Complete Achievement Overview**:
   - Displays all official achievements with their official icons, names, descriptions, and current completion status.
3. **One-Click Instant Unlock**:
   - Click "Unlock" next to any locked achievement to unlock it immediately via official game APIs.
4. **Unlock All**:
   - An "Unlock All" button unlocks all remaining locked achievements in one batch.
5. **Category Filter Tabs**:
   - Easily filter achievements by "All", "Locked", and "Unlocked".
6. **Perfectionist Confirmation Dialog**:
   - Before executing an unlock, a confirmation window appears with customizable copy for perfectionists, ensuring players do not accidentally unlock achievements.
7. **Strictly Zero Emojis**:
   - Uses plain text badges and standard typography to ensure clean rendering without missing font glyph boxes `[]`.

---

## How to Use

1. **Open the Window**:
   - Click the **"Achievements"** button in the top-left corner of the game screen.
2. **Browse & Filter**:
   - Use the "All", "Locked", and "Unlocked" tabs to review your progress.
3. **Unlock Achievements**:
   - Click **"Unlock"** next to a specific achievement, or **"Unlock All"** in the top header.
   - Confirm your choice in the popup confirmation dialog.

---

## Directory Structure

```text
achievements_unlock/
├── _metadata/
│   ├── 0.png                              # Mod preview cover image
│   └── modinfo.json                       # Workshop/ModHub metadata and descriptions
├── _content.json                          # Asset and script index
├── mod.json                               # Core mod configuration
├── strings.json                           # Multi-language translations (13 languages supported)
├── readme.md                              # Mod documentation
└── content/
    ├── achievements_unlock_toolbar.res.lua # React toolbar HUD button definition
    ├── achievements_unlock.script.lua      # GUI recipe, window wrapper, and confirmation dialog
    ├── achievements_unlock.lua             # Core achievement querying and unlocking APIs
    └── ui_util.lua                         # Shared UI layout helpers
```
