# Harbor Sign menu preview

Run `res://scenes/main_menu_preview.tscn` with Godot 4.7. The project startup scene is not changed.

This scene inherits `res://scenes/water_test_scene.tscn`. Its Ocean prefab, wave resource, water material, generated geometry, sun, and environment are inherited without overrides. Only the preview camera is reframed, its free-look input is removed, and the ship and menu are added. The camera follows the sampled ship height and maintains at least six metres of clearance above its local sampled sea surface. The decorative ship samples the existing ocean height field for heave, pitch, and roll.

Play opens Single Player, Multiplayer, and Local. These modes remain preview placeholders. Ship color changes the visible model. Settings demonstrate key rebinding and inline graphics/display selection; these are session-only UI values, not persistent game settings or live graphics changes. Back and Escape replace pages rather than opening modal dialogs. The preview uses system fonts (DIN Condensed/Gill Sans on macOS); bundle a licensed font before cross-platform release.

## Art provenance

- `sign_board.png`: transparent ImageGen extraction from the user-selected Harbor Sign concept in `art-review/menu_design_2026_10_06/concepts/04_harbor_sign.png`. Generated 2026-10-06. Original output: `exec-a95442bd-511b-46fb-b489-0bdec8d33f01.png`. No raster postprocessing.
- `selection.svg`: native vector highlight, sized at runtime to fit the navy inset. All four main-menu highlights share the same 376×64 size; Back remains a smaller secondary action.
- `hover.svg`: matching pale-blue ribbon for hover and keyboard focus, distinct from the gold active-category ribbon.
- Ship: existing Kenney Pirate Kit asset, retaining its existing third-party provenance.

Exact extraction prompt:

> Edit target: this selected Harbor Sign main menu concept. Extract ONLY the complete hanging signboard and its timber support as a reusable game UI asset, on TRANSPARENT background. Keep the same handcrafted low-poly faceted orange wood, deep navy painted inset, ivory skull emblem, angled edges and silhouette. Remove all ocean, sky, ship, shadows on water. Remove ALL letters, ALL text, the gold PLAY ribbon, and the horizontal carved separators inside the board; leave the dark navy inset blank below the ivory skull, suitable for runtime menu labels. Preserve the skull in the top of the inset and preserve the top horizontal timber, left upright timber, and hanging wood straps. Do not restyle, embellish, add ropes, add text, or add photorealistic texture. Tight portrait composition, entire sign and support visible, approximately 650 wide by 1000 tall proportion, no clipping of board. This is the same selected sign made into a clean alpha cutout asset, not a new design.

## Verification

The preview fills the window without letterboxing. A vertical nine-patch preserves the sign's skull, crossbeam and bevel while extending the upright past the top and bottom of the viewport. Settings categories keep a gold ribbon while active; hovering or focusing another button shows pale blue without removing the gold category indicator. Clicking a category transfers the gold state. Key bindings, graphics arrows, display arrows and their value fields have permanent cream backgrounds and larger navy labels. Hover/focus on a settings input uses pale blue.

`check_harbor_settings_colors.gd` verifies the two simultaneous color states, active-category persistence, visible controls at rest, and in-place value changes. It passes headless and in native Metal with the actual cursor placed over each target. Keyboard reachability and activation also pass after the control layout changes.

WASD and arrows navigate all pages, including color swatches and settings values. Enter/Space activate, Tab/Shift-Tab traverse, and Escape goes back. During key rebinding, navigation keys are captured as bindings and Escape cancels. Focus stays on the selected color or settings arrow after activation, supporting repeated adjustments.

Hover now uses Godot's native hovered-control result after event dispatch, including window scaling, rather than a separate rectangle scan. Pointer and keyboard navigation share the same focused button and highlight. A stationary pointer cannot reclaim keyboard focus. Settings values and color selection update in place so clicks do not replace the focused controls. Rebinding keeps focus on the binding being captured.

`check_harbor_focus_sync.gd` is the current mouse/keyboard handoff regression harness. It verifies native hover, focus, highlight and actual click/Enter outcomes at four window sizes, including transformed window-space input, category fallback, settings arrows and color swatches. Headless and native Metal runs both pass. This supersedes the older harnesses' synchronous assumptions about hover updates.

The settings-selection and keyboard-navigation harnesses verify persistent categories, temporary hover, every control's reachability with both key sets, activation, keycap visibility, and rebinding. All checks pass. Current harnesses are `check_settings_selection.gd`, `check_harbor_navigation.gd`, and `check_harbor_equal_highlights.gd` in the review directory.

The follow-up interaction harness, `check_harbor_interaction.gd` in the review directory, verifies single selection, pointer exit, mouse-to-keyboard transition, and highlight containment at 1440×900, 1280×720 and 1024×768. Its isolated input checks pass; native Metal captures were also inspected for framing and hover appearance.

Godot ocean and buoyancy tests pass. Preview verification checks shared test-scene resources, all mode routes, page replacement, Back navigation, live ship recoloring, key input, and inline settings. Every sign-button highlight rectangle is sampled against the navy inset of the source art. Main menu, Play, Customization, Settings and Back all pass. Camera clearance was sampled over sixty seconds of the original wave motion, with a six metre minimum. Native Metal captures were inspected at four wave phases, plus hover/focus and subpage states. Visual captures and the verification harness are in `art-review/menu_design_2026_10_06/`.
