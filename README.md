# Bloodbound

Sacrifice is survival. **Bloodbound** is a 2D action prototype built in Godot 4 for a game jam where your health doubles as currency. Spend HP to purchase weapons, hunt skeletons to farm blood, and reinvest that blood into abilities that push you deeper into the dungeon.

## Project Goals
- Deliver a fast loop built around meaningful sacrifices instead of traditional coin drops.
- Reward aggressive play with blood that unlocks weapons, abilities, and meta upgrades.
- Support quick iteration during the jam with clean scenes, scripts, and assets ready for drop-in art replacements.

## Getting Started
1. Install [Godot Engine 4.2+](https://godotengine.org/).
2. Clone or download this repository.
3. Open `project.godot` in Godot and run `scenes/game.tscn`.

> The repository currently includes a movement prototype (walk, jump, basic animations) that you can extend with combat, shops, and enemy encounters.

## Controls
- Move: `ui_left` / `ui_right` (Arrow keys or A/D by default)
- Jump: `ui_accept` (Space or Enter by default)

Rebind these actions in **Project > Project Settings > Input Map** if you need a different layout.

## Current Progress
- Side-scrolling player controller with gravity, jump, and animation state swaps.
- Simple test scene with camera framing and a world boundary to keep the player in view.
- Imported placeholder art under `assets/` for the hero and skeleton enemies.

## Upcoming Work
1. Add combat verbs (melee, ranged, dash) and enemy AI for the skeletons.
2. Implement the HP-as-currency sacrifice system and blood-based upgrade economy.
3. Build shop/altar interfaces, HUD readouts, and level progression cues.
4. Replace placeholders with final jam-ready art, audio, and VFX.
5. Polish moment-to-moment feel (screenshake, hit-stop, particles, accessibility options).

## Asset Notes
- Player placeholder sprites come from `assets/Jungle Asset Pack`.
- Skeleton sprites live in `assets/Skeleton/`.
- Replace any placeholder art with your own final assets before release and update credits accordingly.

## Contributing During the Jam
- Keep scenes modular (one mechanic per script when possible) to avoid merge conflicts.
- Document new input actions or exported properties directly in the relevant scripts.
- When adding assets, drop them under `assets/` in descriptive subfolders and commit metadata (`.import`) files.

## License
This project includes third-party art under their respective licenses. The code and original content in this repository are available under the MIT License (see `LICENSE`).
