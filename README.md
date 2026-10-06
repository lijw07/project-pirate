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
| `scenes/water_test_scene.tscn` | Deep-sea toon ocean with massive swells | Open it and press F6 |
| `scenes/gym_test_scene.tscn` | Filler ship floating on the ocean, for tuning ship movement | Open it and press F6 |

### Free-look camera (test scenes)

| Input | Action |
| --- | --- |
| Hold right mouse button | Look around |
| W / A / S / D | Fly |
| Q / E | Down / up |
| Shift | Boost |
| Mouse wheel | Change fly speed |

## Project layout

Folders and files use snake_case and are grouped by file type.

| Folder | Contents |
| --- | --- |
| `scenes/` | Playable and test scenes |
| `prefabs/` | Reusable scenes instanced into other scenes: ocean, ships |
| `scripts/` | GDScript, grouped by system (`scripts/ocean/`, `scripts/camera/`) |
| `shaders/` | Shader code |
| `materials/` | Material resources |
| `resources/` | Data resources: wave presets (`resources/waves/`), environments (`resources/environments/`) |
| `assets/third_party/` | Outside art: Kenney Pirate Kit (3D) and Pirate Pack (2D), both CC0; Boujie water textures (MIT) |
| `tests/` | Headless test scripts |
| `art-review/` | Blender sources and review bundles (local only, not in git) |
| `docs/` | Local design notes (not in git) |

## Tests

Each test exits with the number of failed checks.

```
godot --headless -s res://tests/test_ocean.gd
godot --headless -s res://tests/test_buoyancy.gd
```

## Credits

- [Kenney](https://kenney.nl) Pirate Kit and Pirate Pack (CC0): `assets/third_party/kenney_pirate_kit/`, `assets/third_party/kenney_pirate_pack/`
- [Boujie Water Shader](https://github.com/Chrisknyfe/boujie_water_shader) by Zach Bernal (MIT): Gerstner wave model and LOD ocean mesh adapted into `game/ocean/`; foam noise and other textures in `assets/third_party/boujie_water/`
- Custom pirate assets built on the Kenney Pirate Kit: `assets/models/pirate/`
