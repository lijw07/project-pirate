# Approved pirate artwork

The 34 GLB files in `models/` are copies of the approved Blender art review exports. `manifest.json` records each source path, SHA-256 digest, and corresponding Godot scene. Godot-generated texture and import sidecars live alongside the GLBs.

Use `scenes/assets/*.tscn` for collidable game instances. Island scenes add enlarged land, underwater foundations, pier supports, and selected expansion models without changing the review source files. See `docs/asset-integration.md` for collision behavior and scene controls.

The original kit geometry is Kenney Pirate Kit 2.1, CC0; its license is included. Supplementary models were created for this project to match that art direction.
