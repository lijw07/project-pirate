# Approved island settlements

The 28 Blender models were approved for Godot integration on October 1, 2026.

- `assets/`: individual reusable scenes for every new model.
- `layouts/`: six reusable settlement compositions with the approved Blender positions, rotations, and scales.
- `../islands/`: complete islands containing those layouts, coastline scenery, terrain, docks, foundations, and calm zones.
- `../../levels/sandbox/ocean_sandbox.tscn`: the integrated ocean test scene.

## Collision behavior

Buildings, castle pieces, equipment, wells, fields, paths, and rocks use static mesh collision. The castle arch and gaps between shelter supports preserve their actual openings. Small visual details such as fire, cables, and fruit are excluded from collision. Citrus trees collide only at the trunk. Grass, flowering grass, ferns, and shrubs deliberately have no blocking collision.

These are static scenery scenes. Instance the `.tscn` files instead of the raw models to retain their collision behavior. Collision layer 1 matches existing world scenery; the collision mask includes existing ship layer 2.

## Sources and rebuilding

Imported models, license information, source hashes, scenery, and exact placement data are in `../../assets/models/settlements/`. Editable Blender sources remain in `../../art-review/island-settlements-v1/`.

After changing the Blender review, run `tools/export_settlement_layouts.py` with Blender and import the resulting files in Godot. Rebuild the new scenes with `tools/build_settlement_scenes.gd`, then run `tools/build_asset_scenes.gd -- --islands-only` with Godot. The original builder recognizes the approved layouts, so rebuilding islands retains the new settlements.

## Validation

- 82 settlement integration checks passed, including all 28 scenes, physics contacts, exact layout transforms, terrain placement, trunk-only tree collision, and a person-sized capsule passing through the castle arch.
- 24 existing island placement checks and 120 existing asset integration checks passed.
- Existing calm-zone checks passed.
- All six islands were rendered and visually inspected in Godot; captures are in `../../tests/reports/ground_placement_*.png`.
- Ocean, ship, and ocean sandbox files were verified unchanged by this integration.
