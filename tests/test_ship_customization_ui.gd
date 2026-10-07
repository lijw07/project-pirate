extends SceneTree
## Native renderer smoke test. Routes real Godot input events through Control/PopupMenu.
var menu: Node
var failures := 0
var checks := 0
var input_window: Window
var footer_positions: Dictionary = {}
var output := "/tmp/pirate_customization_ui"

func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", caption)
func descendants(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children(true): out.append_array(descendants(child))
	return out
func button(caption: String) -> Button:
	for n in descendants(menu.ui):
		if n is Button and n.text == caption: return n
	return null
func choice(caption: String) -> Control:
	for n in descendants(menu.workshop.content):
		if n.has_meta("choice_caption") and n.get_meta("choice_caption") == caption: return n
	return null
func reveal(control: Control) -> void:
	var p := control.get_parent()
	while p:
		if p is ScrollContainer:
			p.ensure_control_visible(control)
			break
		p = p.get_parent()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func click(control: Control) -> void:
	assert(control != null)
	await reveal(control)
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame
	await process_frame
	await create_timer(0.12).timeout
func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		if is_instance_valid(input_window) and input_window.visible:
			event.window_id = input_window.get_window_id()
			Input.parse_input_event(event)
		else: root.push_input(event, true)
	await process_frame
	await process_frame
func select(caption: String, index: int) -> void:
	var item := choice(caption)
	var previous: int = item.get_meta("selected")
	for i in absi(index - previous):
		item = choice(caption)
		await click(item.find_child("NextChoice" if index > previous else "PreviousChoice", true, false))
	check(int(choice(caption).get_meta("selected")) == index, caption + " arrows select correctly")
func check_layout() -> void:
	var bounds: Rect2 = menu.workshop.content.get_global_rect()
	var contained := true
	var no_dropdowns := true
	var no_scrollbars := true
	for n in descendants(menu.workshop):
		if (n is ScrollContainer or n is ScrollBar) and n.is_visible_in_tree(): no_scrollbars = false
	for n in descendants(menu.workshop.content):
		if n is Control and not n.is_visible_in_tree(): continue
		if n is OptionButton: no_dropdowns = false
		if n is BaseButton:
			var rect: Rect2 = n.get_global_rect()
			contained = contained and bounds.grow(1).encloses(rect)
	var selected_tab: Button = menu.workshop.tabs[menu.workshop.section]
	check(selected_tab.get_theme_stylebox("pressed").bg_color == menu.workshop.GOLD, menu.workshop.section + " selected tab is gold")
	check(contained and no_dropdowns and no_scrollbars, menu.workshop.section + " controls fit without scrolling or dropdowns")
	var cancel_rect := button("Cancel").get_global_rect()
	var save_rect := button("Save & return").get_global_rect()
	var resolution := str(root.get_visible_rect().size)
	if not footer_positions.has(resolution): footer_positions[resolution] = [save_rect, cancel_rect]
	check(footer_positions[resolution] == [save_rect, cancel_rect], menu.workshop.section + " footer does not move between tabs")
	var safe_footer := Rect2(165, root.get_visible_rect().size.y - 265, 335, 65)
	check(safe_footer.encloses(cancel_rect) and safe_footer.encloses(save_rect), menu.workshop.section + " footer stays inside the sign border")
func check_keyboard() -> void:
	var expected: Array[Control] = []
	for n in descendants(menu.workshop):
		if n is BaseButton and n.is_visible_in_tree(): expected.append(n)
	var valid := true
	for keys in [[KEY_W, KEY_A, KEY_S, KEY_D], [KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]]:
		var reached: Array[Control] = [menu.workshop.tabs[menu.workshop.section]]
		var cursor := 0
		while cursor < reached.size():
			var origin := reached[cursor]
			for code in keys:
				origin.grab_focus()
				await key(code)
				var next := root.gui_get_focus_owner()
				if next == null or next not in expected: valid = false
				elif next not in reached: reached.append(next)
			cursor += 1
		valid = valid and reached.size() == expected.size()
	check(valid, menu.workshop.section + " every button is reachable with WASD and arrow keys")
	menu.workshop.tabs[menu.workshop.section].grab_focus()

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/" + name + ".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	menu = load("res://scenes/main_menu_preview.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await create_timer(0.2).timeout
	await click(button("SHIP CUSTOMIZATION"))
	check(menu.current_page == "customization", "main-menu entry opens workshop")
	menu.workshop.save_path = output + "/appearance.json"
	await create_timer(0.3).timeout
	var open_sea: Resource = menu.open_sea_waves
	menu.workshop.draft = ShipAppearance.defaults()
	menu.workshop._changed()
	menu.workshop._rebuild()
	await process_frame
	await process_frame
	await click(menu.workshop.content.find_child("NextPalette", true, false))
	await click(menu.workshop.content.find_child("NextPalette", true, false))
	check(menu.ship.appearance.hull == "#25585b", "paint arrows apply Teal directly")
	await click(menu.workshop.content.find_child("PreviousPalette", true, false))
	check(menu.ship.appearance.hull == "#642c2d", "left arrow moves back to Crimson")
	await click(menu.workshop.content.find_child("NextPalette", true, false))
	check_layout()
	await shot("ship")
	var title: Button = menu.workshop.ship_title
	var steady_title := true
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var title_style := title.get_theme_stylebox(state)
		steady_title = steady_title and title_style.get_margin(SIDE_TOP) == 0 and title_style.get_margin(SIDE_BOTTOM) == 0
	check(steady_title, "ship name has identical text positioning in all button states")
	title.grab_focus()
	await key(KEY_ENTER)
	check(menu.workshop.name_editor.visible, "Enter on the heading opens ship naming")
	menu.workshop.name_editor.select_all()
	for glyph in "The Wanderer":
		var typed := InputEventKey.new()
		typed.unicode = glyph.unicode_at(0)
		typed.pressed = true
		root.push_input(typed, true)
	await key(KEY_ENTER)
	check(menu.workshop.draft.ship_name == "The Wanderer" and title.text == "THE WANDERER", "ship name can be typed and applied without navigation stealing letters")
	await key(KEY_ENTER)
	menu.workshop.name_editor.text = "Discard this"
	await key(KEY_ESCAPE)
	check(menu.workshop.draft.ship_name == "The Wanderer" and menu.current_page == "customization", "Escape cancels name editing without leaving the workshop")
	await check_keyboard()
	for expected_tab in ["Sails", "Flags", "Decor", "Deck", "Ship"]:
		await key(KEY_E)
		check(menu.workshop.section == expected_tab and root.gui_get_focus_owner() == menu.workshop.tabs[expected_tab], "E selects and focuses " + expected_tab)
	await key(KEY_Q)
	check(menu.workshop.section == "Deck", "Q wraps from Ship to Deck")
	await click(button("Sails"))
	await select("Shape", 0)
	check(not menu.ship.appearance.main.enabled and not menu.ship.appearance.secondary.enabled, "Original preserves both original sail shapes")
	var original_locked := choice("Pattern") == null and choice("Emblem") == null
	for control in descendants(menu.workshop.content):
		if control.has_meta("color_choice"): original_locked = false
	check(original_locked and choice("Shape").find_child("ChoiceValue", true, false).text == "None", "None sail has no color or design controls")
	await select("Shape", 2)
	check(menu.ship.appearance.main.shape == "swallowtail", "main sail shape arrows works")
	check(choice("Pattern") != null and choice("Emblem") != null, "custom sail shapes restore design controls")
	check(choice("Sail") == null and button("Match main sail") == null, "shared sails need no selector or matching toggle")
	await select("Shape", 3)
	check(menu.ship.appearance.secondary.shape == "pointed" and menu.ship.appearance.main.shape == "pointed", "shape updates both sails together")
	await select("Pattern", 4)
	await select("Emblem", 7)
	check(menu.ship.appearance.secondary.pattern == "chevron" and menu.ship.appearance.secondary.emblem == "moon", "shared sail controls update pattern and emblem")
	check(menu.workshop.draft.secondary == menu.workshop.draft.main and menu.ship.appearance.secondary == menu.ship.appearance.main, "both sails share all appearance settings")
	check_layout()
	await shot("shared-sails")
	await check_keyboard()
	await click(button("Flags"))
	check(button("Match all pennants") == null and choice("Mast") == null and choice("Breeze") == null, "pennants need no matching toggle or mast selector")
	await select("Shape", 4)
	var shape_arrow: Control = choice("Shape").find_child("PreviousChoice", true, false)
	shape_arrow.grab_focus()
	await key(KEY_ENTER)
	await process_frame
	check(root.gui_get_focus_owner() != null and root.gui_get_focus_owner().get_meta("focus_key", "") == "Shape-1", "changing flag shape keeps keyboard focus")
	await select("Shape", 4)
	await select("Length", 2)
	check(menu.ship.appearance.fore_flag.shape == "streamer" and is_equal_approx(menu.ship.appearance.fore_flag.length, 1.35), "shared pennant shape and length controls work")
	check(menu.workshop.draft.match_pennants and menu.ship.appearance.fore_flag == menu.ship.appearance.main_flag and menu.ship.appearance.aft_flag == menu.ship.appearance.main_flag, "all pennants remain matched")
	await select("Shape", 0)
	check(not menu.ship.fittings.has_node("MainPennant") and not menu.ship.fittings.has_node("ForePennant") and not menu.ship.fittings.has_node("AftPennant"), "none removes all pennants together")
	await select("Shape", 2)
	check_layout()
	await shot("flags")
	await check_keyboard()
	await click(button("Decor"))
	await select("Figurehead", 0)
	check(menu.ship.base.get_node("Bowsprit").visible, "original bowsprit arrows restores beam")
	check(choice("Figurehead").find_child("ChoiceValue", true, false).text == "None", "no figurehead is labeled None")
	await select("Figurehead", 2)
	await select("Bunting", 1)
	check(menu.ship.fittings.has_node("Bunting"), "bunting color arrows create stern decoration")
	check_layout()
	await shot("stern")
	await check_keyboard()
	await click(button("Deck"))
	await select("Stern · Port", 4)
	check(menu.ship.fittings.get_node("aft_port").get_meta("cosmetic_id") == "flowers", "stern port arrows assigns correct prop")
	check_layout()
	await shot("deck")
	await check_keyboard()
	await click(button("Ship"))
	await click(menu.workshop.content.find_child("NextPalette", true, false))
	check(menu.ship.appearance.hull == "#263d59", "Navy paint preset works after other edits")
	var hull_row := choice("Hull")
	check(hull_row != null and hull_row.has_meta("color_choice"), "Hull uses inline color arrows")
	await click(hull_row.find_child("NextChoice", true, false))
	check(menu.ship.appearance.hull == "#3576a0", "next color arrow applies Ocean immediately")
	choice("Hull").find_child("PreviousChoice", true, false).grab_focus()
	await key(KEY_SPACE)
	check(menu.ship.appearance.hull == "#263d59", "Space on previous arrow restores Navy")
	await key(KEY_ENTER)
	check(menu.ship.appearance.hull == "#434568", "Enter cycles colors and retains arrow focus")
	var swatch: PanelContainer = choice("Hull").find_child("ColorSwatch", true, false)
	check(swatch.get_theme_stylebox("panel").bg_color.is_equal_approx(Color(menu.ship.appearance.hull)), "inline swatch displays applied color without a color name")
	check_layout()
	await shot("color-arrows")
	var yaw: float = menu.orbit_yaw
	var press := InputEventMouseButton.new()
	press.position = Vector2(980, 405)
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(1020, 420)
	drag.relative = Vector2(40, 15)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(drag, true)
	press.position = drag.position
	press.pressed = false
	root.push_input(press, true)
	check(not is_equal_approx(yaw, menu.orbit_yaw), "drag rotates the ship view")
	var distance: float = menu.orbit_distance
	var wheel := InputEventMouseButton.new()
	wheel.position = Vector2(1020, 420)
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	root.push_input(wheel, true)
	wheel.pressed = false
	root.push_input(wheel, true)
	await process_frame
	check(menu.orbit_distance < distance, "scroll zooms the ship view")
	# Save via the real button into a disposable test file, without replacing the user's look.
	var expected: Dictionary = menu.workshop.draft.duplicate(true)
	var test_path := output + "/appearance.json"
	menu.workshop.save_path = test_path
	await click(button("Save & return"))
	check(menu.current_page == "main" and ShipAppearance.read_saved(test_path) == expected, "Save button writes the full draft and returns to main menu")
	check(menu.ship.appearance == expected and menu.ship.visible, "main menu displays the exact saved design and name")
	await shot("saved-main-menu")
	check(menu.ocean.wave_set == open_sea, "leaving inspection restores original sea")
	await click(button("SHIP CUSTOMIZATION"))
	await click(button("Decor"))
	await select("Figurehead", 1)
	await click(button("Cancel"))
	check(menu.current_page == "main" and menu.ship.appearance == expected, "Cancel restores the design shown when customization opened")
	await click(button("PLAY"))
	await click(button("SINGLE PLAYER"))
	await click(button("SAILING TEST"))
	await create_timer(0.8).timeout
	check(current_scene.scene_file_path == "res://scenes/cosmetic_sailing_test.tscn", "Play launches cosmetic sailing scene")
	await key(KEY_ESCAPE)
	check(paused, "Escape pauses sailing test")
	if paused:
		menu = current_scene.get_node("PauseMenu")
		await click(button("MAIN MENU"))
		await process_frame
		await process_frame
		check(not paused and current_scene.scene_file_path == "res://scenes/main_menu_preview.tscn", "pause menu returns to harbor")
	print("CUSTOMIZATION UI: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
