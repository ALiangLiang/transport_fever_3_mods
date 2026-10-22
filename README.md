# Transport Fever 3 Mods

A collection of quality-of-life (QoL) and achievement assistant mods for **Transport Fever 3** developed by [ALiangLiang](https://github.com/ALiangLiang). All mods are built on the game's native React UI framework, integrate directly into the top-left corner of the game screen, support multi-language localization (13 languages), and adhere strictly to zero emoji usage for clean font rendering.

---

## Mod Overview

| Mod Name | Mod ID | Summary | Target Achievement |
| :--- | :--- | :--- | :--- |
| **[Achievements Unlock](achievements_unlock/readme.md)** | `aliangliang_achievements_unlock` | Live achievement list with filters, one-click single/batch unlock, and perfectionist safety confirmation dialog. | All Official Achievements |
| **[Animal Radar](animal_radar/readme.md)** | `aliangliang_animal_radar` | Full-map wildlife radar scanning with dynamic species tabs and smooth camera jump/tracking. | Animal Lover |
| **[Connoisseur Tracker](connoisseur_tracker/readme.md)** | `aliangliang_connoisseur_tracker` | Depot vehicle store integration tagging uncollected models with `[Unused]` badges and availability era hints. | Connoisseur |
| **[UFO Summoner](ufo_summoner/readme.md)** | `aliangliang_ufo_summoner` | On-demand official UFO Easter Egg summoning, airspace radar status, and dual camera tracking. | Encounter of the 3rd Kind |

---

## Installation & Usage

### 1. Manual Installation
Copy the desired mod folder(s) into your Transport Fever 3 local staging area:
```text
C:\Program Files (x86)\Steam\userdata\<YourSteamID>\3493540\local\staging_area\
```

### 2. Enabling in Game
1. Launch Transport Fever 3.
2. When starting a New Game or loading an existing Savegame, click **Mod Settings**.
3. Enable the desired mod(s).
4. In-game, click each mod's dedicated button in the **top-left corner of the game screen** to open its window.

---

## Design Standards

1. **Strictly Zero Emojis**:
   - The game engine font lacks Unicode emoji glyphs, which causes square box artifacts `[]` or crashes. All UI text and documentation strictly use plain text and clean typography.
2. **Native React UI Architecture**:
   - Integrates seamlessly with official UI extensions (`MainModButtonAreaExtension`, `react.RegisterWrapperRecipe`, `builtin.Window`) for native look, feel, and performance.
3. **Multi-Language Localization**:
   - Full localization support for all 13 official languages: English, Deutsch, Español, Français, Italiano, Nederlands, Polski, Português, Русский, 日本語, 简体中文, 繁體中文, and 한국어.

---

## License & Author

* **Author**: [ALiangLiang](https://github.com/ALiangLiang)
* **GitHub Repository**: [ALiangLiang/transport_fever_3_mods](https://github.com/ALiangLiang/transport_fever_3_mods)
