# Pirate art review 01

Art only, based on the supplied Kenney Pirate Kit 2.1. Prepared September 30, 2026.

Open `preview.html` to browse the overview, four resource islands, two harbors, ship lineup, warship detail, and fitting library. `Pirate_Art_Review.blend` is the editable source, with three named scenes and individual cameras. Textures are packed into the Blender file.

## Included artwork

- Food / Provision Cay: crop beds, food barrels, drying rack, thatched storehouse.
- Gold / Gilded Key: gold-bearing rocks, ingots, chests, fortified storehouse.
- Timber / Palmwood Isle: palm grove, log piles, stumps, planks, saw bench.
- Metal / Ironwake Mine: rocky entrance, ore cart and rails, forge, crane, ingots.
- Player and opposing harbors: fortifications, twin piers, stores, and teal/red banners.
- Scout, warship, trader, and opposing pirate ship visual assemblies.
- Separate cannon, rigging, armor, and cargo modules.

Fourteen GLB files in `models/` contain the visual assemblies. Their origins are centered on each asset; they use standard glTF Y-up coordinates. The Blender source is Z-up, meters. Existing Kenney hulls are intact; cannons, plates, and cargo are separate child objects. This is slot-based visual modularity, not a set of cut-apart hull sections. Ship bob/roll is authored in the Blender timeline over frames 1–60; exported GLBs and supplied PNGs are static.

## Review boundary

This directory is excluded from Godot import by `art-review/.gdignore`. No gameplay scenes, AI, capture rules, economy, combat, collision, or upgrade logic are included. Godot runtime rendering and performance have not been tested. The materials and presentation are Blender renders; an eventual Godot water shader and lighting pass will require separate integration. This is a review bundle, not a canonical Game Development Studio admission package.

## Source and provenance

Kenney source license is included in `License-Kenney.txt`. Original files remain untouched in `kenney_pirate-kit/`. Source GLB hashes are recorded in `source/source-hashes.json`, and hashes of assembly exports are in `manifest.json`. Custom crops, drying rack, mine equipment, timber, armor, banners, and presentation geometry were created for this project. The recolored sails preserve the source's wood fittings.

`source/build_art.py` builds the source scene and initial exports. `source/finish_review.py` isolates final exports, renders the views, and restores the complete scene. `source/finalize_module.py` adds the removable sailcloth and prepares the viewport for review. `source/refine_gold.py` completes the visible treasure stockpile. Run these four scripts in that order to reproduce the final bundle. All four run with Blender 5.1.1. `source/validate_art.py` performs file structure, embedded texture, geometry, origin, and hash checks without running a game.
