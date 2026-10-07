class_name ShipCustomizationPanel
extends Control

signal appearance_changed(data: Dictionary)
signal finished(saved: bool)
signal inspect_requested(view: String)
signal orbit_requested(delta: Vector2)
signal zoom_requested(amount: float)

const COLORS := ["f3e3c5", "d8c7a0", "d3bd83", "bb966d", "aa6344", "78332d", "a95f65", "c97858", "665477", "434568", "263d59", "3576a0", "87c4cb", "25585b", "39735b", "534235", "713e2e", "52736b", "273d48", "282f34"]
const CREAM := Color("f3e3c5")
const GOLD := Color("d9b457")
const LABELS := {"original": "None", "none": "None", "square": "Square", "swallowtail": "Swallowtail", "pointed": "Pointed pennant", "streamer": "Long streamer", "lanterns": "Brass cage", "cobalt_lamps": "Cobalt glass", "paper_lamps": "Festival paper", "gull": "Gilded gull", "serpent": "Sea serpent", "lion": "Carved lion", "nautilus": "Nautilus", "leviathan": "Leviathan", "kraken": "Kraken", "compass_crest": "Compass rose", "sun_crest": "Sunburst", "chest": "Keepsake chest", "crates": "Painted crates", "rope_coil": "Rope coil", "flowers": "Wildflower planter", "bottles": "Glass bottles", "books": "Captain’s journals", "barrel": "Decorative barrel", "cushions": "Woven cushions"}
var save_path := ShipAppearance.SAVE_PATH
var draft: Dictionary
var section := "Ship"
var content: VBoxContainer
var status: Label
var dragging := false
var tabs: Dictionary = {}
var rebuild_pending := false
var navigation_rows: Array = []
var footer_actions: HBoxContainer
var ship_title: Button
var name_editor: LineEdit
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _theme()
	var preview := Control.new()
	preview.name = "ShipInspectionArea"
	add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.offset_left = 620
	preview.mouse_default_cursor_shape = Control.CURSOR_DRAG
	preview.gui_input.connect(_preview_input)
	var layout := VBoxContainer.new()
	add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	layout.offset_left = 155
	layout.offset_right = 505
	layout.offset_top = 210
	layout.offset_bottom = -294
	layout.add_theme_constant_override("separation", 8)
	ship_title = _button("", _edit_ship_name)
	ship_title.name = "ShipName"
	ship_title.tooltip_text = "Name your ship"
	ship_title.custom_minimum_size.y = 62
	ship_title.clip_text = true
	var display := SystemFont.new()
	display.font_names = PackedStringArray(["DIN Condensed", "sans-serif"])
	display.font_weight = 700
	ship_title.add_theme_font_override("font", display)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		style.border_color = GOLD if state == "focus" else Color("a4dfe3")
		style.border_width_bottom = 2 if state != "normal" else 0
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		ship_title.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]: ship_title.add_theme_color_override(state, CREAM)
	layout.add_child(ship_title)
	name_editor = LineEdit.new()
	name_editor.name = "ShipNameEditor"
	name_editor.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_editor.max_length = ShipAppearance.SHIP_NAME_LIMIT
	name_editor.placeholder_text = ShipAppearance.DEFAULT_SHIP_NAME
	name_editor.add_theme_font_override("font", display)
	name_editor.add_theme_color_override("font_color", CREAM)
	name_editor.add_theme_color_override("caret_color", CREAM)
	for state in ["normal", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("17374e")
		style.border_color = GOLD
		style.border_width_bottom = 2
		name_editor.add_theme_stylebox_override(state, style)
	ship_title.add_child(name_editor)
	name_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_editor.hide()
	name_editor.text_changed.connect(func(value): _fit_name_font(name_editor, value))
	name_editor.text_submitted.connect(func(_value): _finish_ship_name(true))
	name_editor.focus_exited.connect(func(): _finish_ship_name(true, false))
	name_editor.gui_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			name_editor.accept_event()
			_finish_ship_name(false))
	_refresh_ship_name()
	var row := HBoxContainer.new()
	layout.add_child(row)
	for category in ["Ship", "Sails", "Flags", "Decor", "Deck"]:
		var b := _button(category, func(): _select_section(category))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 38
		b.add_theme_font_size_override("font_size", 17)
		b.toggle_mode = true
		row.add_child(b)
		tabs[category] = b
	content = VBoxContainer.new()
	content.name = "CustomizationContent"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 3)
	layout.add_child(content)
	# Keep the footer independent of content minimum sizes and tab rebuilds.
	var footer := Control.new()
	footer.name = "CustomizationFooter"
	add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.offset_left = 167
	footer.offset_right = 493
	footer.offset_top = -278
	footer.offset_bottom = -210
	status = Label.new()
	footer.add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status.offset_bottom = 22
	status.text = ""
	status.add_theme_font_size_override("font_size", 16)
	footer_actions = HBoxContainer.new()
	footer_actions.name = "FooterActions"
	footer.add_child(footer_actions)
	footer_actions.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	footer_actions.offset_top = 26
	var done := _button("Save & return", _save)
	done.custom_minimum_size.y = 42
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_actions.add_child(done)
	var cancel := _button("Cancel", func(): finished.emit(false))
	cancel.custom_minimum_size.y = 42
	footer_actions.add_child(cancel)
	var hint := Label.new()
	add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 648
	hint.offset_top = -50
	hint.offset_right = 1100
	hint.offset_bottom = -18
	hint.text = "Drag to turn  ·  Scroll to zoom"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_outline_color", Color("17374e"))
	hint.add_theme_constant_override("outline_size", 4)
	_rebuild()

func _fit_name_font(control: Control, value: String) -> void:
	var font := control.get_theme_font("font")
	var font_size := 60
	while font_size > 22 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > 330:
		font_size -= 1
	control.add_theme_font_size_override("font_size", font_size)

func _refresh_ship_name() -> void:
	ship_title.text = draft.ship_name.to_upper()
	_fit_name_font(ship_title, ship_title.text)

func _edit_ship_name() -> void:
	name_editor.text = draft.ship_name
	_fit_name_font(name_editor, name_editor.text)
	name_editor.show()
	name_editor.grab_focus()
	name_editor.select_all()

func _finish_ship_name(commit: bool, restore_focus := true) -> void:
	if not name_editor.visible: return
	var value := ShipAppearance.validate_name(name_editor.text)
	name_editor.hide()
	if commit and value != draft.ship_name:
		draft.ship_name = value
		_changed()
	_refresh_ship_name()
	if restore_focus: ship_title.grab_focus()

func _theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 18
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Gill Sans", "sans-serif"])
	result.default_font = font
	for type in ["Button", "OptionButton", "ColorPickerButton", "CheckButton"]:
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("a4dfe3") if state in ["hover", "pressed", "hover_pressed", "focus"] else CREAM
			style.border_color = Color("699da5") if state in ["pressed", "focus"] else Color("b6a588")
			style.set_border_width_all(2 if state == "focus" else 1)
			style.set_corner_radius_all(3)
			style.border_width_bottom = 4
			style.content_margin_left = 10
			style.content_margin_right = 10
			style.content_margin_top = 4
			style.content_margin_bottom = 4
			result.set_stylebox(state, type, style)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: result.set_color(state, type, Color("17374e"))
	result.set_color("font_color", "Label", CREAM)
	result.set_color("font_color", "CheckButton", Color("17374e"))
	var popup := StyleBoxFlat.new()
	popup.bg_color = CREAM
	popup.border_color = Color("b6a588")
	popup.set_border_width_all(2)
	popup.set_corner_radius_all(3)
	result.set_stylebox("panel", "PopupMenu", popup)
	var highlight := StyleBoxFlat.new()
	highlight.bg_color = Color("a4dfe3")
	result.set_stylebox("hover", "PopupMenu", highlight)
	result.set_color("font_color", "PopupMenu", Color("17374e"))
	result.set_color("font_hover_color", "PopupMenu", Color("17374e"))
	result.set_constant("v_separation", "PopupMenu", 10)
	return result

func _button(caption: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size.y = 32
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(action)
	return b

func _select_section(category: String) -> void:
	section = category
	_rebuild()
	var views := {"Ship": "Full ship", "Sails": "Sails", "Flags": "Flags", "Decor": "Bow", "Deck": "Deck"}
	inspect_requested.emit(views[category])

func _heading(caption: String) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", GOLD)
	content.add_child(label)

func _changed() -> void:
	draft.match_sails = true
	draft.secondary = draft.main.duplicate(true)
	draft.match_pennants = true
	draft.fore_flag = draft.main_flag.duplicate(true)
	draft.aft_flag = draft.main_flag.duplicate(true)
	status.text = "Unsaved changes"
	appearance_changed.emit(draft)

func _choice(caption: String, values: Array, selected: String, callback: Callable, names: Array = []) -> void:
	var row := HBoxContainer.new()
	row.set_meta("choice_caption", caption)
	row.set_meta("selected", maxi(0, values.find(selected)))
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 128 if section == "Deck" else 105
	if section == "Deck": label.add_theme_font_size_override("font_size", 16)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var selector := HBoxContainer.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.add_theme_constant_override("separation", 4)
	row.add_child(selector)
	var value := Label.new()
	value.name = "ChoiceValue"
	value.text = names[row.get_meta("selected")] if not names.is_empty() else LABELS.get(selected, selected.capitalize())
	value.tooltip_text = value.text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.clip_text = true
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", Color("17374e"))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(value)
	for direction in [-1, 1]:
		var arrow := _button("‹" if direction < 0 else "›", func():
			var index := posmod(int(row.get_meta("selected")) + direction, values.size())
			row.set_meta("selected", index)
			value.text = names[index] if not names.is_empty() else LABELS.get(values[index], String(values[index]).capitalize())
			value.tooltip_text = value.text
			callback.call(values[index]))
		arrow.name = "PreviousChoice" if direction < 0 else "NextChoice"
		arrow.set_meta("focus_key", caption + str(direction))
		arrow.tooltip_text = ("Previous " if direction < 0 else "Next ") + caption.to_lower()
		arrow.custom_minimum_size.x = 34
		arrow.add_theme_font_size_override("font_size", 20)
		selector.add_child(arrow)
		if direction < 0: selector.add_child(panel)

func _palette_arrows(selected: String) -> void:
	var row := HBoxContainer.new()
	row.name = "PaintPalette"
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	var values: Array = ShipAppearance.PALETTES.keys()
	var state := {"index": values.find(selected)}
	var label := Label.new()
	label.text = "Natural timber" if selected == "natural" else selected.capitalize()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color("17374e"))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(label)
	for direction in [-1, 1]:
		var arrow := _button("‹" if direction < 0 else "›", func():
			state.index = posmod(state.index + direction, values.size()) if state.index >= 0 else (values.size() - 1 if direction < 0 else 0)
			var value: String = values[state.index]
			label.text = "Natural timber" if value == "natural" else value.capitalize()
			ShipAppearance.choose_palette(draft, value)
			_changed()
			_rebuild())
		arrow.name = "PreviousPalette" if direction < 0 else "NextPalette"
		arrow.set_meta("focus_key", "palette" + str(direction))
		arrow.tooltip_text = "Previous paint palette" if direction < 0 else "Next paint palette"
		arrow.custom_minimum_size.x = 44
		arrow.add_theme_font_size_override("font_size", 20)
		row.add_child(arrow)
		if direction < 0: row.add_child(panel)

func _color(caption: String, data: Dictionary, key: String, timber := false) -> void:
	var colors: Array = []
	for hex in COLORS: colors.append("#" + hex)
	var current: String = data[key]
	# Keep older saved colors available when cycling away and back.
	if current not in colors: colors.push_front(current)
	var names: Array = []
	names.resize(colors.size())
	names.fill("")
	_choice(caption, colors, current, func(value):
		data[key] = value
		if timber: draft.paint = true
		elif key in ["cloth", "ink"]: _enable_cloth(data)
		_changed()
		_rebuild(), names)
	var row := content.get_child(-1)
	row.set_meta("color_choice", true)
	var swatch := row.find_child("ChoiceValue", true, false).get_parent() as PanelContainer
	swatch.name = "ColorSwatch"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(current)
	style.border_color = Color(current).lightened(0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	swatch.add_theme_stylebox_override("panel", style)

func _enable_cloth(data: Dictionary) -> void:
	if data.has("enabled"):
		data.enabled = true
		for row in content.get_children():
			if row.get_meta("choice_caption", "") == "Shape":
				row.set_meta("selected", 1 + ShipAppearance.SHAPES.find(data.shape))
				var value := row.find_child("ChoiceValue", true, false) as Label
				if value:
					value.text = LABELS.get(data.shape, data.shape.capitalize())
					value.tooltip_text = value.text
	else: draft.pennants = true

func _cloth(data: Dictionary) -> void:
	_color("Cloth", data, "cloth")
	_color("Design", data, "ink")
	_choice("Pattern", ShipAppearance.PATTERNS, data.pattern, func(v): data.pattern = v; _enable_cloth(data); _changed())
	_choice("Emblem", ShipAppearance.EMBLEMS, data.emblem, func(v): data.emblem = v; _enable_cloth(data); _changed())

func _rebuild() -> void:
	# Native popups must finish closing before their owning controls are replaced.
	if rebuild_pending: return
	rebuild_pending = true
	_build_content.call_deferred()

func _build_content() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var restore_key: String = focused.get_meta("focus_key", "") if focused and content.is_ancestor_of(focused) else ""
	rebuild_pending = false
	_refresh_ship_name()
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for category in tabs:
		var tab: Button = tabs[category]
		var selected: bool = category == section
		tab.button_pressed = selected
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			if selected:
				var style := theme.get_stylebox(state, "Button").duplicate() as StyleBoxFlat
				style.bg_color = GOLD
				style.border_color = Color("a38342")
				tab.add_theme_stylebox_override(state, style)
			else: tab.remove_theme_stylebox_override(state)
	match section:
		"Ship":
			_heading("Timber & paint")
			var palette := "custom"
			if not draft.paint: palette = "natural"
			else:
				for key in ShipAppearance.PALETTES:
					var colors: Array = ShipAppearance.PALETTES[key]
					if [draft.hull, draft.trim, draft.deck, draft.masts] == colors: palette = key
			_palette_arrows(palette)
			for i in ShipAppearance.REGIONS.size(): _color(["Hull", "Rails & trim", "Deck", "Masts & yards"][i], draft, ShipAppearance.REGIONS[i], true)
		"Sails":
			var data: Dictionary = draft.main
			_choice("Shape", ["original"] + ShipAppearance.SHAPES, data.shape if data.enabled else "original", func(v):
				data.enabled = v != "original"
				if data.enabled: data.shape = v
				_changed()
				_rebuild())
			if data.enabled: _cloth(data)
		"Flags":
			var data: Dictionary = draft.main_flag
			_choice("Shape", ["none"] + ShipAppearance.SHAPES, data.shape, func(v): data.shape = v; _enable_cloth(data); _changed(); _rebuild())
			if data.shape != "none":
				_cloth(data)
				for key in ["length", "height"]:
					var sizes: Array = [0.75, 1.0, 1.35] if key == "length" else [0.75, 1.0, 1.2]
					_choice(key.capitalize(), [str(sizes[0]), str(sizes[1]), str(sizes[2])], str(float(data[key])), func(v): data[key] = float(v); _enable_cloth(data); _changed(), ["Short", "Standard", "Long"] if key == "length" else ["Narrow", "Standard", "Wide"])
		"Decor":
			_choice("Figurehead", ShipAppearance.FIGURES, draft.figurehead, func(v): draft.figurehead = v; _changed(); inspect_requested.emit("Bow"), ["None", "Gilded gull", "Sea serpent", "Carved lion", "Nautilus"])
			_choice("Stern lanterns", ShipAppearance.LAMPS, draft.lamps, func(v): draft.lamps = v; _changed(); inspect_requested.emit("Stern"))
			_choice("Stern trophy", ShipAppearance.TROPHIES, draft.trophy, func(v): draft.trophy = v; _changed(); inspect_requested.emit("Stern"))
			_choice("Colors", ["crimson", "teal", "ivory"], draft.decoration_color, func(v): draft.decoration_color = v; _changed())
			for pair in [["Banners", "banners"], ["Bunting", "bunting"], ["Braided trim", "tassels"]]:
				var id: String = pair[1]
				_choice(pair[0], ["none", "crimson", "teal", "ivory"], draft[id + "_color"] if draft[id] else "none", func(v):
					draft[id] = v != "none"
					if v != "none": draft[id + "_color"] = v
					_changed()
					inspect_requested.emit("Full ship" if id == "tassels" else "Stern"))
		"Deck":
			_heading("Deck decorations")
			for i in ShipAppearance.SLOTS.size():
				var slot: String = ShipAppearance.SLOTS[i]
				_choice(["Bow · Port", "Bow · Starboard", "Stern · Port", "Stern · Starboard"][i], ShipAppearance.PROPS, draft[slot], func(v): draft[slot] = v; _changed(); inspect_requested.emit("Deck"))

	_wire_navigation.call_deferred(restore_key)

func _save() -> void:
	_finish_ship_name(true, false)
	var error := ShipAppearance.save(draft, save_path)
	if error == OK: finished.emit(true)
	else: status.text = "Could not save. Your changes are still here. Try again."

func _preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom_requested.emit(-1)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom_requested.emit(1)
	elif event is InputEventMouseMotion:
		dragging = (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		if dragging: orbit_requested.emit(event.relative)

func _row_buttons(node: Node) -> Array[Control]:
	var buttons: Array[Control] = []
	if node is BaseButton:
		buttons.append(node)
		return buttons
	for child in node.get_children(): buttons.append_array(_row_buttons(child))
	return buttons

func _nearest_button(row: Array, from: Control) -> Control:
	var nearest: Control = row[0]
	var x := from.get_global_rect().get_center().x
	for candidate in row:
		if absf(candidate.get_global_rect().get_center().x - x) < absf(nearest.get_global_rect().get_center().x - x): nearest = candidate
	return nearest

func _wire_navigation(restore_key: String) -> void:
	await get_tree().process_frame
	if not is_inside_tree(): return
	navigation_rows = [[ship_title], tabs.values()]
	for row in content.get_children():
		var buttons := _row_buttons(row)
		if not buttons.is_empty(): navigation_rows.append(buttons)
	navigation_rows.append(_row_buttons(footer_actions))
	var ordered: Array[Control] = []
	for row in navigation_rows: ordered.append_array(row)
	for i in navigation_rows.size():
		var row: Array = navigation_rows[i]
		for j in row.size():
			var control: Control = row[j]
			control.focus_mode = Control.FOCUS_ALL
			control.focus_neighbor_left = control.get_path_to(row[posmod(j - 1, row.size())])
			control.focus_neighbor_right = control.get_path_to(row[(j + 1) % row.size()])
			control.focus_neighbor_top = control.get_path_to(_nearest_button(navigation_rows[posmod(i - 1, navigation_rows.size())], control))
			control.focus_neighbor_bottom = control.get_path_to(_nearest_button(navigation_rows[(i + 1) % navigation_rows.size()], control))
			var index := ordered.find(control)
			control.focus_next = control.get_path_to(ordered[(index + 1) % ordered.size()])
			control.focus_previous = control.get_path_to(ordered[posmod(index - 1, ordered.size())])
			if not restore_key.is_empty() and control.get_meta("focus_key", "") == restore_key: control.grab_focus()
	if get_viewport().gui_get_focus_owner() == null: tabs[section].grab_focus()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit: return
	if event.keycode in [KEY_Q, KEY_E]:
		var categories := tabs.keys()
		var direction := -1 if event.keycode == KEY_Q else 1
		_select_section(categories[posmod(categories.find(section) + direction, categories.size())])
		tabs[section].grab_focus()
		get_viewport().set_input_as_handled()
		return
	var directions := {KEY_W: SIDE_TOP, KEY_UP: SIDE_TOP, KEY_S: SIDE_BOTTOM, KEY_DOWN: SIDE_BOTTOM, KEY_A: SIDE_LEFT, KEY_LEFT: SIDE_LEFT, KEY_D: SIDE_RIGHT, KEY_RIGHT: SIDE_RIGHT}
	if event.keycode not in directions: return
	if focused and is_ancestor_of(focused):
		var next := focused.find_valid_focus_neighbor(directions[event.keycode])
		if next: next.grab_focus()
	else: tabs[section].grab_focus()
	get_viewport().set_input_as_handled()
