# Ship cosmetics

Approved for game integration on 2026-10-06 after the local ship customization workshop review. Cosmetics do not affect movement, armor, cannons, inventory, or progression.

`manifest.json` records the 34 approved modules, SHA-256 checksums, approval, and reference provenance. The authored fittings and sail artwork were created locally for Project Pirate. `reference_ship.glb` derives from Kenney Pirate Kit's CC0 `ship-pirate-large.glb`; the original third-party model remains unchanged. See `REFERENCE_LICENSE.txt`.

The reference separates the bowsprit, original/cleared bow sail, and four timber paint regions. A figurehead replaces the bowsprit. Main and secondary sails share one shape, cloth color, pattern, and emblem. Older saved appearances inherit the main sail design for both sails. All mast pennants share one design and size setting; older saves inherit the main mast pennant settings. Flutter strength, speed, and direction follow the scene’s WindEffects conditions, including calm and pause, rather than a saved cosmetic breeze value. All models retain the approved unscaled Y-up ship coordinate system. Runtime prop mounts are in `CosmeticShip.PROP_POSITIONS`.

The workshop uses left/right arrow selectors for palettes, sail and pennant designs, and fittings. Individual colors come from 20 unlabeled swatches displayed directly on the sign. WASD/arrows move focus; Space or Enter applies a color without leaving the palette; Escape or Back returns to the controls. RGB fields and sliders are not exposed. Paint colors apply directly; original timber and sail shapes remain selectable. Each category fits on the Harbor sign without scrolling. Footer buttons have fixed anchors inset from the wooden border. All buttons support WASD, arrows, and Tab navigation, with focus retained after selection changes; drag/zoom inspection remains available beside the sign.

The main menu reads `user://ship_appearance.json`. Changes remain a draft until **Save & return**; **Cancel** or Escape restores the saved ship. The saved versioned dictionary is validated before applying it. Save keeps the chosen design and ship name on the main-menu ship immediately; Cancel restores the appearance present when the workshop opened. The sailing test uses the same visual component, scaled to the existing test hull; its movement and collision configuration are unchanged.

`SailPainter` renders the approved vector designs with arbitrary cloth/ink colors. Rebuild its export-safe templates with:

```sh
node tools/ship_cosmetics/build_paint_templates.cjs
```

All glTF animation tracks are combined into one looping animation per module so flutter and sway play together. Material edits retain those players and their timing. Model preloads and generated GDScript paint templates ensure scene-dependency exports include the visual assets.

Validation:

```sh
godot --headless --path . --script tests/test_ship_customization.gd
godot --path . --resolution 1440x900 --script tests/test_ship_customization_ui.gd
godot --path . --resolution 1280x720 --script tests/test_ship_customization_ui.gd
godot --path . --script tests/test_ship_customization_layout.gd
godot --headless --path . --script tests/test_pause_menu.gd
```

The UI test saves only to a temporary test path and captures native-rendered screenshots in `/tmp/pirate_customization_ui`. Headless rendering can report an engine dummy-material warning for the ocean; native Metal validation is the visual acceptance check.

Stern banners mount at the rear rail, bunting is sized to the stern rail endpoints, and braided trim follows the side hull. Each uses None/Crimson/Teal/Ivory arrow choices instead of a toggle.

The Flags camera frames all three mast pennants and adapts to the available preview width. Layout checks cover 1280×720, 1920×1080, and 1024×768, including maximum-length streamers.

The ship heading is editable (click it or focus it and press Enter). Names are saved with the appearance, capped at 24 characters, and default to Your Ship when empty. Escape cancels a name edit; Cancel discards the full draft. The active category is gold, while hover and keyboard focus remain cyan.
