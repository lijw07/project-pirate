# Pirate assets in Godot

The art review was approved for Godot scene integration on October 1, 2026. All 34 reviewed assemblies have reusable native scenes in `scenes/assets/`: six islands/harbors, four ships, four fitting modules, and twenty expansion assets. The approved GLBs were copied, hash-checked, and recorded in `assets/pirate/manifest.json`. The Blender review sources remain separate and unchanged by the integration.

## Ocean test layout

`scenes/test/ocean_test.tscn` is still the project main scene. It uses the six-island, four-ship arrangement from the Blender archipelago, with horizontal island spacing enlarged by three. Land footprints are three times their reviewed width and length (nine times the area). Ships, individual trees, buildings, and fittings retain their original size. Additional buildings and scenery occupy the expanded islands; all twenty expansion assets are also available separately.

The original floating island shells now have faceted underwater foundations that match their irregular wet-sand outlines and extend to a shared seabed at -18 metres. Pier piles extend down to the ground. Land and dock artwork is raised 2.8 metres to keep the former low plateau above the existing wave crests. The foundation top follows the raised shoreline, while its base overlaps the seabed to avoid gaps.

The ocean node instances `scenes/ocean/ocean.tscn` using the project's `default_waves.tres` and original mesh settings. No custom wave preset remains. Each island and harbor scene carries a `CalmZone` sized from its footprint, so waves drop to 15% near every shore. The ocean shader, wave math, buoyancy implementation, and water material were not edited for this integration. Ships consume the project's existing buoyancy and hull-water-mask components.

## Collision contracts

| Asset | Body and collision |
|---|---|
| Islands and harbors | Static bodies; mesh collisions for solid scenery and terrain, separate foundation and pier-pile collisions |
| Resource buildings, docks, harbor props, equipment | Static mesh collision preserving doorways, gantry openings, and dock cutouts |
| Ships | Rigid bodies with convex lower-hull and aft-cabin shapes, six buoyancy probes, lowered center of mass, continuous collision detection |
| Standalone fitting modules | Animatable bodies with convex shapes for solid parts; suitable for positioning with a moving parent |
| Seabed | Static ground mesh and box collision, surface at -18 metres |

Foam, sailcloth, flags, pennants, ropes, leaves named as separate meshes, and small rivets do not create solid obstacles. Ship collisions approximate the main hull and cabin; they are not an interior walking/navigation model or per-cannon projectile hitboxes. The same applies to assembled hull modules: fitting sockets and upgrade behavior are not implemented.

Solid scenery uses physics layer 1; ships use layer 2. Ship masks include both layers. There is no flat water-plane collider: the existing wave height and buoyancy systems supply ship flotation.

## Review and controls

- `scenes/test/ocean_test.tscn`: archipelago, original water system, floating ships.
- `scenes/test/asset_gallery.tscn`: all 34 asset scenes in a labeled inspection layout; gallery ships are frozen.
- Right mouse drag orbits; wheel zooms; Tab changes focus; Esc releases the camera for WASD panning; Home returns to the archipelago overview.
- `docs/validation/` contains native Godot screenshots and check results.

## Rebuild and verify

`tools/build_asset_scenes.gd` builds the native asset scenes, ocean layout, and gallery from the imported GLBs. `tools/island_geometry.gd` defines the enlarged terrain, foundations, seabed, and pier supports. `tools/blender-layout.json` records the source placement data. Run the build through Godot after importing the project assets.

`tests/test_asset_integration.gd` checks all scene collisions through physics queries, dock and gantry openings, underwater perimeter continuity, seabed contact, ship flotation, camera focus, and a physical landing on an island. `tests/capture_archipelago.gd` renders overview, ship, island, waterline, and underwater views in a graphical Godot session. `tests/test_ocean.gd` remains the existing ocean-system test suite.

The static-versus-moving collision choices follow the [Godot collision shape guidance](https://docs.godotengine.org/en/4.4/tutorials/physics/collision_shapes_3d.html). This is a project-native integration, not a canonical Game Development Studio vendoring receipt.

## Verification result

120 integration checks passed in Godot 4.7.2 with Jolt Physics. Native Metal / Forward Mobile renders were inspected for the archipelago, floating ships, enlarged island, waterline, and underwater foundation. All 34 copied GLBs still match their approved source hashes. The ocean's original preset and mesh settings are checked explicitly.

The earlier existing ocean test suite returned zero failed assertions but emitted off-tree transform diagnostics in its calm-zone tests. Its code was left unchanged.
