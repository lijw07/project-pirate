# Project Pirate

A single-player naval domination game made in Godot. You captain a modular pirate ship, sail an open sea, capture islands that each produce their own resource (food, gold, wood or metal), and win by destroying the enemy harbor while surviving rival pirate ships.

## Status

Working now:

- **Ocean**: stylized Gerstner-wave sea that stretches to the horizon, with foam, refraction and calm water around islands. Physics reads the same waves the player sees.
- **Buoyancy**: ships float, pitch and roll on the waves; hull masks keep water off the decks.
- **Ship movement**: sail levels, reverse, speed-dependent steering and heeling in turns.
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
| `scenes/test/ocean_test.tscn` | Archipelago with all ships and islands floating on the ocean | Main scene: press F5 |
| `scenes/test/ship_movement_test.tscn` | Sail the player ship around the islands | Open it and press F6 |
| `scenes/test/asset_gallery.tscn` | Every pirate asset laid out for inspection | Open it and press F6 |

### Ship controls

| Key | Action |
| --- | --- |
| W / S | Raise / lower sails (S at a stop reverses) |
| A / D | Steer |
| R | Free the ship when the stuck prompt is showing |
| Mouse wheel, trackpad scroll or pinch | Zoom |

Arrow keys also raise, lower and steer.

## Project layout

| Folder | Contents |
| --- | --- |
| `assets/` | Imported art: custom pirate models, Kenney packs, water textures |
| `art-review/` | Blender sources and review bundles; local only, ignored by Godot and git |
| `docs/` | Design and system notes |
| `resources/` | Shared resources: wave set, water material, environment |
| `scenes/` | Ocean, asset, UI and test scenes |
| `scripts/` | GDScript by system: `ocean/`, `ship/`, `camera/`, `ui/` |
| `shaders/` | Ocean shader |
| `tests/` | Headless test scripts |
| `tools/` | Asset scene builder and island geometry generator |

[docs/project-structure.md](docs/project-structure.md) explains each system and how to set up a new ship. [docs/asset-integration.md](docs/asset-integration.md) covers the pirate asset scenes, collision layers and the rebuild tools.

## Tests

Each test exits with the number of failed checks.

```
godot --headless -s res://tests/test_ocean.gd
godot --headless --fixed-fps 60 -s res://tests/test_ship_movement.gd
godot --headless --fixed-fps 60 -s res://tests/test_ship_stuck.gd
godot --headless -s res://tests/test_island_calm_zones.gd
godot --headless --fixed-fps 60 -s res://tests/test_overhead_camera.gd
godot --headless -s res://tests/test_asset_integration.gd
```

`tests/capture_archipelago.gd` renders review screenshots and needs a graphical session.

## Credits

- [Kenney](https://kenney.nl) Pirate Kit and Pirate Pack (CC0): `assets/kenney_pirate-kit/`, `assets/kenney_pirate-pack/`
- [Boujie Water Shader](https://github.com/Chrisknyfe/boujie_water_shader) textures by Zach Bernal (MIT): `assets/boujie_water_shader/`
- Custom pirate assets built on the Kenney Pirate Kit: `assets/pirate/`
