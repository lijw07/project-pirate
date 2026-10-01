# Project structure

| Folder | Contents |
| --- | --- |
| `assets/kenney_pirate-kit/` | Kenney Pirate Kit 2.1 (CC0). 3D filler art for test scenes until the custom assets are ready. |
| `assets/kenney_pirate-pack/` | Kenney Pirate Pack (CC0). 2D sprites, tiles and vector art. |
| `assets/boujie_water_shader/` | Water albedo, foam and refraction textures from the Boujie Water Shader (MIT, license included). |
| `assets/pirate/` | Approved custom assembly exports, provenance manifest, and imported textures. |
| `scenes/assets/` | 34 reusable collidable asset scenes. |
| `tools/` | Scene builder and island geometry generation. |
| `art-review/` | Blender review bundles. Local only: ignored by Godot through `.gdignore` and by git through `.gitignore`. |
| `scenes/ocean/` | `ocean.tscn`, the reusable sea. Drop one into any level. |
| `scenes/test/` | Ocean archipelago, asset gallery and ship movement test; the original filler ship remains available for ocean tests. |
| `scripts/ocean/` | Ocean, wave math, mesh builder, buoyancy, hull water masks and calm zones. |
| `scripts/ship/` | Ship movement, player input, sail furling, stuck detection and rescue. |
| `scripts/camera/` | Cameras. `OverheadCamera` is the player camera (fixed 45° angle above the ship, zoom only). `OrbitCamera` is the free debug camera in the ocean test. |
| `scripts/ui/` | HUDs and prompts. `ShipDebugHud` shows sail level, speed, heading and rudder; `StuckPrompt` shows the free-your-ship prompt. |
| `scenes/ui/` | Reusable UI scenes (`stuck_prompt.tscn`). |
| `resources/environment/` | Shared sky, light and fog (`sea_environment.tres`). |
| `shaders/` | `ocean.gdshader`. |
| `resources/ocean/` | `default_waves.tres` (wave set) and `ocean_material.tres` (look of the water). |
| `tests/` | Headless test scripts. |
| `docs/` | Notes like this one. |

## Ocean

- `Ocean` builds a camera-following grid that is dense near the camera and sparse toward the horizon, so the sea reaches the fog line without a huge vertex count.
- Waves are summed Gerstner waves defined in a `WaveSettings` resource (up to 8 `GerstnerWave` entries: direction, steepness, wavelength). The same resource drives the shader and the CPU, so `Ocean.height_at(position)` returns the height of the water that is actually drawn.
- Keep the total steepness of all waves under 1.0, or crests fold over themselves.
- The water look lives on `ocean_material.tres` and follows the stylized style of the [Boujie Water Shader](https://github.com/Chrisknyfe/boujie_water_shader) (Wind Waker-inspired):
  - a cell-pattern albedo texture that tints our shallow/deep colors and drifts and wobbles over the surface
  - screen-space refraction, so islands and hulls under shallow water are visible and wobble
  - water opacity from depth (Beer's law absorption) and a fresnel tint at grazing angles
  - cell-line foam texture that shows on wave crests, in large slowly drifting patches, and around anything that pierces the water
  - texture detail fades out between `detail_fade_start` and `detail_fade_end` to hide tiling near the horizon
- The waves themselves are still ours (Gerstner), so buoyancy, hull masks and calm zones all keep working.

## Buoyancy

- Add a `Buoyancy` node as a direct child of a `RigidBody3D` and give it `Marker3D` children as float probes.
- Each probe carries an equal share of the body's weight when it sits `draft` meters under the surface. Water damping blends in by how many probes are submerged.
- A lowered custom center of mass on the body keeps ships upright.
- Place the body origin where the waterline should be and offset the model so the keel sits below it. The filler ship's keel is 0.6 m below the origin and its deck is 1.4 m above, which leaves about 1.1 m of freeboard in the default waves.

## Keeping water off decks

- Add a `HullWaterMask` node to a ship, centered on the hull footprint, with `half_width` and `half_length` slightly inside the hull walls.
- The ocean shader skips drawing water inside that ellipse, so a wave crest that rises above the deck stays outside the hull instead of flooding it.
- Up to 16 masks are active at once (the ones nearest the camera).

## Calm water around islands

- Add a `CalmZone` node at an island's center. Waves fade from full height at `outer_radius` down to the ocean's `calm_residual` (15% by default) at `inner_radius`.
- The fade applies to both the drawn water and `Ocean.height_at`, so ships near an island float on the same calmer water you see.
- Up to 16 zones are active at once. Overlapping zones use the calmest value.
- Every island and harbor scene in `scenes/assets/` carries its own `CalmZone`, centered on its footprint: fully calm from 1.25 times its half-width (about 8 to 10 m past the shore) and back to full waves 45 m further out. `tools/build_asset_scenes.gd` adds them on rebuild (`CALM_ZONE_INNER_SCALE`, `CALM_ZONE_FALLOFF`).

## Ship movement

A ship is a `RigidBody3D` with `Buoyancy` plus these children:

- `ShipMovement` drives the ship. It takes over the body's linear damping (sets it to 0) because it models water drag itself.
  - Sails: discrete levels, each with a top speed (`sail_speeds`, m/s; default 0 / 6 / 11 / 17, about 0 / 12 / 21 / 33 knots). Thrust is sized so each level settles exactly at its speed; dropping sails lets drag coast the ship to a stop.
  - Reverse: lowering sails at a stop selects the reverse level (`REVERSE_LEVEL`, -1), which backs the ship up at `reverse_speed` (4 m/s). Set `reverse_speed` to 0 to remove reverse. While moving backwards the rudder works the other way, like a real boat.
  - Keel: sideways sliding is cancelled by `lateral_grip`, so the ship carves turns instead of drifting. That force acts `keel_depth` below the center of mass; deeper means more lean in turns (0.12 m gives about 7° at full speed).
  - Steering: the rudder eases toward the input at `rudder_speed`. Turn rate scales with speed up to `full_steerage_speed`, with `minimum_steerage` left when stopped.
  - `local_bow_direction` is the bow in the ship's local space. The pirate ship scenes face +Z.
  - Other scripts (AI later) call `raise_sails()`, `lower_sails()`, `set_sail_level()`, `steer(-1..1)` and `halt()`.
- `ShipPlayerInput` maps the `sail_raise`, `sail_lower`, `steer_left` and `steer_right` input actions (W/S/A/D and arrow keys) to `ShipMovement`, and `ship_unstuck` (R) to `ShipRescue`.
- `ShipSails` furls every mesh under `rig` whose name starts with `sail` toward its yard as the sail level drops (fully furled in reverse).
- `ShipStuckDetector` flags the ship as stuck after `seconds_until_stuck` (3 s) of touching land (`land_layers`, layer 1) while trying to move (sails set or rudder past half) and moving slower than `progress_speed`. A capsized ship also counts. It turns on the body's contact monitoring itself.
- `ShipRescue` frees a stuck ship: it searches for open water 15 to 90 m away, starting directly away from the land it is touching, places the ship there facing away with sails lowered, and resets the detector. `rescue_if_stuck()` does nothing unless the detector says stuck.
- `StuckPrompt` (`scenes/ui/stuck_prompt.tscn`) appears while the detector says stuck and names the key bound to the `ship_unstuck` action (R).

`Buoyancy` only works vertically: lift plus `heave_damping` at each probe. The default `draft` is 0.95 m, so a ship whose probes sit at its keel line floats with the keel 0.95 m under the surface. Raise `draft` to sit a ship lower. Horizontal drag belongs to `ShipMovement`, or to the body's own damping for ships without one.

## Test scenes

`scenes/test/ocean_test.tscn` (main scene): the ocean with all pirate assets.

- Right mouse drag: orbit
- Mouse wheel: zoom
- Tab: cycle between ships and islands
- Home: archipelago overview
- Home: overview
- Esc: free camera, then WASD to pan

`scenes/test/ship_movement_test.tscn`: sail the corsair around the islands. Open it and press F6.

- W / S: raise / lower sails (S at a stop reverses)
- A / D: steer
- R: free the ship when the stuck prompt is showing
- Mouse wheel, trackpad scroll or pinch: zoom

The `OverheadCamera` stays at a fixed angle (`pitch_degrees`, `yaw_degrees`) above its `target` and never rotates with the ship. Zoom is smoothed and clamped between `min_distance` and `max_distance`.

## Running tests

```
godot --headless -s res://tests/test_ocean.gd
godot --headless --fixed-fps 60 -s res://tests/test_ship_movement.gd
godot --headless --fixed-fps 60 -s res://tests/test_overhead_camera.gd
godot --headless --fixed-fps 60 -s res://tests/test_ship_stuck.gd
godot --headless -s res://tests/test_island_calm_zones.gd
```

`--fixed-fps 60` lets the ship test simulate a minute of sailing in a few seconds. The exit code is the number of failed checks.

See [Asset integration](asset-integration.md) for enlarged islands, underwater foundations, asset collisions, and validation.
