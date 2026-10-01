# Project Pirate

A single-player naval domination game made in Godot. You captain a modular pirate ship, sail an open sea, capture islands that each produce their own resource (food, gold, wood or metal), and win by destroying the enemy harbor while surviving rival pirate ships.

## Status

Working now:

- **Ocean**: stylized Gerstner-wave sea that stretches to the horizon, with foam, refraction and calm water around islands. Physics reads the same waves the player sees.
- **Buoyancy**: ships float, pitch and roll on the waves; hull masks keep water off the decks.
- **Ship movement**: sail levels, reverse, speed-dependent steering and heeling in turns.
- **Ship wakes**: moving ships leave a spreading V-shaped wake with small ripples, a churned trail and bow foam that grow with speed.
- **Camera**: overhead player camera that follows the ship at a fixed angle and zooms.
- **Stuck recovery**: if the ship is wedged against land, a prompt offers to free it.
- **Pirate assets**: islands, harbors, ships, modules and props as collidable Godot scenes.

Planned: island capture and resource production, modular ship upgrades, cannon combat, enemy AI, harbor siege and win/lose conditions.

## Requirements

- Godot 4.7 (Mobile renderer, Jolt Physics)

## Running

Open `project.godot` in Godot 4.7.

| Scene | What it shows | How to open |
| --- | --- | --- |
| `levels/sandbox/ocean_sandbox.tscn` | Archipelago with all ships and islands floating on the ocean | Main scene: press F5 |
| `levels/sandbox/ship_movement_sandbox.tscn` | Sail the player ship around the islands | Open it and press F6 |
| `levels/sandbox/asset_gallery.tscn` | Every pirate asset laid out for inspection | Open it and press F6 |

### Ship controls

| Key | Action |
| --- | --- |
| W / S | Raise / lower sails (S at a stop reverses) |
| A / D | Steer |
| R | Free the ship when the stuck prompt is showing |
| Mouse wheel, trackpad scroll or pinch | Zoom |

Arrow keys also raise, lower and steer.

## Project layout

Folders and files use snake_case. Game code is grouped by feature: each folder in `game/` holds the scenes, scripts and resources for one system.

| Folder | Contents |
| --- | --- |
| `assets/models/pirate/` | Custom pirate models (GLB), their textures and `manifest.json` |
| `assets/third_party/` | Outside art: Kenney Pirate Kit (3D) and Pirate Pack (2D), both CC0; Boujie water textures (MIT) |
| `game/ocean/` | Ocean scene, shader, wave set, water material, buoyancy, hull water masks, calm zones, wake emitters |
| `game/ships/` | Ship scenes (`ship_corsair.tscn`...) and ship behavior: movement, input, sails, stuck detection, rescue |
| `game/islands/` | Resource island and harbor scenes, each with its own calm zone |
| `game/props/` | Docks, buildings, crates and deck equipment |
| `game/modules/` | Ship fitting modules: cannons, armor, cargo, rigging |
| `game/camera/` | `OverheadCamera` (player) and `OrbitCamera` (free debug camera) |
| `game/ui/` | HUD, stuck prompt and minimap |
| `game/environment/` | Shared sky, light and fog |
| `levels/sandbox/` | Test levels: ocean sandbox (main scene), ship movement sandbox, asset gallery |
| `tests/` | Headless test scripts; generated reports go to `tests/reports/` (not in git) |
| `tools/` | Asset scene builder, island geometry and asset path helpers |
| `art-review/` | Blender sources and review bundles (local only, not in git) |
| `docs/` | Local design notes (not in git) |

## Tests

Each test exits with the number of failed checks.

```
godot --headless -s res://tests/test_ocean.gd
godot --headless --fixed-fps 60 -s res://tests/test_ship_movement.gd
godot --headless --fixed-fps 60 -s res://tests/test_ship_wake.gd
godot --headless --fixed-fps 60 -s res://tests/test_ship_stuck.gd
godot --headless --fixed-fps 60 -s res://tests/test_overhead_camera.gd
godot --headless -s res://tests/test_island_calm_zones.gd
godot --headless -s res://tests/test_island_placement.gd
godot --headless -s res://tests/test_minimap.gd
godot --headless -s res://tests/test_asset_integration.gd
```

`tests/capture_archipelago.gd` and `tests/capture_island_placement.gd` render review screenshots into `tests/reports/` and need a graphical session.

## Credits

- [Kenney](https://kenney.nl) Pirate Kit and Pirate Pack (CC0): `assets/third_party/kenney_pirate_kit/`, `assets/third_party/kenney_pirate_pack/`
- [Boujie Water Shader](https://github.com/Chrisknyfe/boujie_water_shader) textures by Zach Bernal (MIT): `assets/third_party/boujie_water/`
- Custom pirate assets built on the Kenney Pirate Kit: `assets/models/pirate/`
