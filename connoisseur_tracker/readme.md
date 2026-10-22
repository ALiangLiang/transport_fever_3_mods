# Connoisseur Tracker

> **Vehicle collection tracker and depot store badge integration for Transport Fever 3**  
> **Mod ID**: `aliangliang_connoisseur_tracker`  
> **Author**: ALiangLiang  
> **Version**: 1.0.0 (Revision 1)

---

## Overview

In Transport Fever 3, the official achievement **"Connoisseur"** (`ACH_ALL_VEHICLES`) requires players to use all official vehicles at least once in Free Game mode across games. With over 300 vehicles spanning multiple eras, keeping track of unused vehicles is challenging.

Connoisseur Tracker solves this by providing real-time progress tracking, availability era hints, and automatically tagging uncollected vehicles directly inside depot vehicle purchase menus.

---

## Features

1. **In-Store Vehicle Badges**:
   - In all train depots, road depots, tram depots, docks, and hangars, any official vehicle you have not yet used will automatically show an **`[Unused]`** badge next to its name.
2. **Top-Left Quick Access Button**:
   - Click the **"Connoisseur"** button in the top-left corner of the game screen to open the collection tracker window anytime.
3. **Real-Time Global Statistics**:
   - Live query of official achievement stats (e.g. `Collected 90 / 306 vehicles (29.4%)`), giving you exact progress toward completion.
4. **Category Tabs & Filters**:
   - Organized into Rail, Road, Tram, Water, and Aviation tabs, with a dedicated "Unused Only" toggle to filter out already collected vehicles.
5. **Availability Era Information**:
   - Displays introduction and retirement years for each vehicle (e.g. `1850 - 1925`), preventing you from missing time-limited historical models.
6. **Strictly Zero Emojis**:
   - Clean, native typography designed specifically to avoid missing glyph square boxes `[]`.

---

## How to Use

1. **Review Progress**:
   - Click the **"Connoisseur"** button in the top-left corner of the game screen to inspect which vehicles remain uncollected.
2. **Purchase Vehicles**:
   - Open any depot or station vehicle store.
   - Look for models labeled with the **`[Unused]`** badge.
   - Buy the vehicle and assign it to an active line with at least one stop. Once the vehicle stops at a station, it is permanently marked as collected!

---

## Directory Structure

```text
connoisseur_tracker/
├── _metadata/
│   ├── 0.png                              # Mod preview cover image
│   └── modinfo.json                       # Workshop/ModHub metadata and descriptions
├── _content.json                          # Asset and script index
├── mod.json                               # Core mod configuration
├── strings.json                           # Multi-language translations (en, zh_TW, zh_CN)
├── readme.md                              # Mod documentation
└── content/
    ├── connoisseur_tracker_toolbar.res.lua # React toolbar HUD button definition
    ├── connoisseur_tracker.script.lua      # GUI recipe, window wrapper, and store hook
    └── connoisseur_tracker.lua             # Core achievement statistics and model scanning
```
