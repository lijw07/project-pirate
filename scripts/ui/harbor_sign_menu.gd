extends Node3D
## Shared Harbor Sign interface for the main-menu preview and pause overlay.

signal pause_started
signal pause_finished

@export var pause_overlay := false
@export_file("*.tscn") var main_menu_scene := "res://scenes/main_menu_preview.tscn"

const CREAM := Color("f3e3c5")
const INK := Color("17374e")
const GOLD := Color("d9b457")
const HOVER := Color("a4dfe3")
const COSMETIC_SHIP := preload("res://scripts/ships/cosmetics/cosmetic_ship.gd")
const CUSTOMIZATION_PANEL := preload("res://scripts/ui/ship_customization_panel.gd")
const BOARD := preload("res://assets/ui/harbor_sign/sign_board.png")
const BOARD_FACE := preload("res://shaders/harbor_sign_face.gdshader")
const SELECTION := preload("res://assets/ui/harbor_sign/selection.svg")
const HOVER_SELECTION := preload("res://assets/ui/harbor_sign/hover.svg")

@onready var ocean := get_node_or_null("Ocean") as Ocean
@onready var camera := get_node_or_null("FreeLookCamera") as Camera3D
var ship: Node3D
var ui: Control
var ui_layer: CanvasLayer
var pause_open := false
var previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var display_font: SystemFont
var body_font: SystemFont
var current_page := "main"
var workshop: ShipCustomizationPanel
var workshop_original: Dictionary = {}
var orbit_yaw := 2.47
var orbit_pitch := 0.30
var orbit_distance := 28.0
var orbit_target := Vector3(0, 4, 0)
var open_sea_waves: OceanWaveSet
var settings_tab := 0
var pending_binding: Button
var menu_buttons: Array[Button] = []
var highlighted_button: Button
var active_settings_button: Button
var pointer_navigation := false
var pointer_sync_queued := false
var sign_art: NinePatchRect
var bindings := {"Raise sails": "W", "Lower sails": "S", "Steer left": "A", "Steer right": "D", "Free ship": "R"}
var settings_values := {"Quality preset": 2, "Shadows": 1, "Anti-aliasing": 2, "Display mode": 0, "Resolution": 1, "Vertical sync": 1}

func _ready() -> void:
	get_window().gui_embed_subwindows = true
	if not pause_overlay:
		get_window().title = "Project Pirate — Harbor"
	get_window().content_scale_size = Vector2i(1440, 900)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	display_font = SystemFont.new()
	display_font.font_names = PackedStringArray(["DIN Condensed", "sans-serif"])
	display_font.font_weight = 700
	body_font = SystemFont.new()
	body_font.font_names = PackedStringArray(["Gill Sans", "sans-serif"])
	if not pause_overlay:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ship = COSMETIC_SHIP.new()
		ship.name = "MenuShip"
		ship.wind_source = get_node_or_null("WindEffects")
		ship.position = Vector3(5, 0, 0)
		add_child(ship)
		camera.current = true
		camera.fov = 45.0
		camera.far = 5000.0
		# Run after the inherited ocean advances its wave clock.
		process_priority = 1
		update_ship_and_camera()
	else:
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_process(false)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 100
	add_child(ui_layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui)
	get_viewport().size_changed.connect(resize_board)
	if pause_overlay:
		ui.hide()
	else:
		show_main()

func _process(_delta: float) -> void:
	update_ship_and_camera()

func update_ship_and_camera() -> void:
	var center := Vector2(ship.position.x, ship.position.z)
	var surface := ocean.height_sampler
	var height := surface.height_at(center)
	var slope_x := (surface.height_at(center + Vector2(1.5, 0)) - surface.height_at(center - Vector2(1.5, 0))) / 3.0
	var slope_z := (surface.height_at(center + Vector2(0, 3)) - surface.height_at(center - Vector2(0, 3))) / 6.0
	var up := Vector3(-slope_x, 1, -slope_z).normalized()
	ship.position.y = height - 0.5
	ship.basis = Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, -0.58)
	if current_page == "customization":
		var distance := orbit_distance
		if is_instance_valid(workshop) and workshop.section == "Flags":
			var viewport_size := get_viewport().get_visible_rect().size
			distance *= maxf(1.0, (viewport_size.y / maxf(1.0, viewport_size.x - 620.0)) / (900.0 / 820.0))
		var right := Vector3(cos(orbit_yaw), 0, -sin(orbit_yaw))
		var shift := 620.0 / get_viewport().get_visible_rect().size.y * distance * tan(deg_to_rad(camera.fov * 0.5))
		var target := ship.to_global(orbit_target) - right * shift
		camera.position = target + Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch)) * distance
		camera.position.y = maxf(camera.position.y, surface.height_at(Vector2(camera.position.x, camera.position.z)) + 1.5)
		camera.look_at(target)
		return
	# Match the ship's heave, keeping its waterline framed during the large test swells.
	var camera_surface := surface.height_at(Vector2(16, 27))
	camera.position = Vector3(16, maxf(height + 10, camera_surface + 6), 27)
	camera.look_at(Vector3(0, height + 3.3, 0))

func _input(event: InputEvent) -> void:
	if current_page == "customization": return
	if pause_overlay:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and not is_instance_valid(pending_binding):
			if not pause_open:
				open_pause()
			elif current_page == "pause":
				resume_game()
			else:
				go_back()
			get_viewport().set_input_as_handled()
			return
		if not pause_open:
			return
	# Let Godot resolve hover after it has transformed and dispatched the event.
	if event is InputEventMouseMotion and not event.relative.is_zero_approx():
		pointer_navigation = true
		queue_pointer_sync()
	elif event is InputEventMouseButton and event.pressed:
		pointer_navigation = true
		queue_pointer_sync()
	elif event is InputEventKey and event.pressed:
		pointer_navigation = false
	if is_instance_valid(pending_binding) and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode != KEY_ESCAPE:
			bindings[pending_binding.get_meta("action")] = OS.get_keycode_string(event.keycode)
		pending_binding.text = bindings[pending_binding.get_meta("action")]
		pending_binding.add_theme_font_size_override("font_size", 36)
		pending_binding = null
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not is_instance_valid(pending_binding):
		var directions := {KEY_W: SIDE_TOP, KEY_UP: SIDE_TOP, KEY_S: SIDE_BOTTOM, KEY_DOWN: SIDE_BOTTOM, KEY_A: SIDE_LEFT, KEY_LEFT: SIDE_LEFT, KEY_D: SIDE_RIGHT, KEY_RIGHT: SIDE_RIGHT}
		if event.keycode in directions:
			move_focus(directions[event.keycode])
			get_viewport().set_input_as_handled()

func queue_pointer_sync() -> void:
	if not pointer_sync_queued:
		pointer_sync_queued = true
		sync_pointer_focus.call_deferred()

func sync_pointer_focus() -> void:
	pointer_sync_queued = false
	if not is_inside_tree(): return
	if current_page == "customization" or not pointer_navigation or (pause_overlay and not pause_open):
		return
	var hovered := get_viewport().gui_get_hovered_control()
	while hovered and not hovered is Button:
		hovered = hovered.get_parent_control()
	var target := hovered as Button
	if target not in menu_buttons:
		target = active_settings_button if is_instance_valid(active_settings_button) else null
	if is_instance_valid(pending_binding):
		target = pending_binding
	if target:
		target.grab_focus()
	else:
		var focused := get_viewport().gui_get_focus_owner()
		if focused:
			focused.release_focus()
	set_highlight(target)

func move_focus(direction: Side) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var target: Control
	if focused:
		target = focused.find_valid_focus_neighbor(direction)
		if target == null:
			target = focused.find_next_valid_focus() if direction in [SIDE_BOTTOM, SIDE_RIGHT] else focused.find_prev_valid_focus()
	else:
		for child in ui.get_children():
			if child is Button and not child.disabled:
				target = child
				break
	if target:
		target.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		go_back()

func go_back() -> void:
	if current_page == "customization":
		close_customization(false)
		return
	if pause_overlay:
		show_pause()
	elif current_page == "mode":
		show_play()
	elif current_page != "main":
		show_main()

func open_pause() -> void:
	if pause_open or get_tree().paused:
		return
	previous_mouse_mode = Input.mouse_mode
	pause_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pointer_navigation = false
	ui.show()
	show_pause()
	pause_started.emit()

func resume_game() -> void:
	if not pause_open:
		return
	clear_page("closed")
	ui.hide()
	pause_open = false
	get_tree().paused = false
	Input.mouse_mode = previous_mouse_mode
	pause_finished.emit()

func show_pause() -> void:
	clear_page("pause")
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.06, 0.09, 0.40)
	ui.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board()
	text("PAUSED", Vector2(125, 256), Vector2(437, 94), 78)
	menu_button("RESUME", 376, resume_game, true, 44, 155, 376, 64)
	menu_button("SETTINGS", 458, show_settings, false, 40, 155, 376, 64)
	menu_button("MAIN MENU", 540, return_to_main_menu, false, 40, 155, 376, 64)
	menu_button("QUIT", 622, func(): get_tree().quit(), false, 40, 155, 376, 64)

func return_to_main_menu() -> void:
	# Validate before ending the paused session so a missing destination can recover.
	var destination := load(main_menu_scene) as PackedScene
	if destination == null:
		push_error("Cannot open main menu: " + main_menu_scene)
		return
	resume_game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_packed(destination)

func _exit_tree() -> void:
	if pause_overlay and pause_open:
		get_tree().paused = false
		Input.mouse_mode = previous_mouse_mode

func clear_page(page: String) -> void:
	pending_binding = null
	menu_buttons.clear()
	highlighted_button = null
	active_settings_button = null
	sign_art = null
	current_page = page
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	if pointer_navigation:
		queue_pointer_sync()

func board() -> void:
	sign_art = NinePatchRect.new()
	sign_art.texture = BOARD
	var face_material := ShaderMaterial.new()
	face_material.shader = BOARD_FACE
	sign_art.material = face_material
	# Preserve the skull, beam and lower bevel; stretch only the blank middle.
	sign_art.patch_margin_top = 450
	sign_art.patch_margin_bottom = 420
	sign_art.position = Vector2(-32, -80)
	sign_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(sign_art)
	resize_board()

func resize_board() -> void:
	if not is_instance_valid(sign_art):
		return
	var art_scale := 650.0 / BOARD.get_width()
	sign_art.scale = Vector2.ONE * art_scale
	sign_art.size = Vector2(BOARD.get_width(), (get_viewport().get_visible_rect().size.y + 140.0) / art_scale)

func text(value: String, pos: Vector2, extent: Vector2, font_size: int, color := CREAM, display := true, centered := true) -> Label:
	var item := Label.new()
	item.text = value
	item.position = pos
	item.size = extent
	item.add_theme_font_override("font", display_font if display else body_font)
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(item)
	return item

func menu_button(value: String, y: float, action: Callable, primary := false, font_size := 40, x := 145.0, width := 396.0, height := 80.0) -> Button:
	var item := Button.new()
	item.text = value
	item.position = Vector2(x, y)
	item.size = Vector2(width, height)
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.add_theme_font_override("font", display_font)
	item.add_theme_font_size_override("font_size", font_size)
	var highlight := StyleBoxTexture.new()
	highlight.texture = HOVER_SELECTION
	var selected_style := StyleBoxTexture.new()
	selected_style.texture = SELECTION
	var pressed := highlight.duplicate() as StyleBoxTexture
	pressed.modulate_color = Color(0.88, 0.82, 0.68)
	item.set_meta("highlight", highlight)
	item.set_meta("selected_style", selected_style)
	item.set_meta("pressed_highlight", pressed)
	item.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	item.focus_entered.connect(func(): set_highlight(item))
	item.mouse_entered.connect(func():
		if pointer_navigation: queue_pointer_sync())
	item.mouse_exited.connect(func():
		if pointer_navigation: queue_pointer_sync())
	item.pressed.connect(action)
	ui.add_child(item)
	menu_buttons.append(item)
	set_highlight(highlighted_button)
	if primary and x < 600:
		item.grab_focus()
	return item

func set_highlight(selected: Button) -> void:
	highlighted_button = selected
	for item in menu_buttons:
		var active := item == selected
		var current_category := item == active_settings_button
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var style: StyleBox = item.get_meta("pressed_highlight" if state.ends_with("pressed") else "highlight") if active else item.get_meta("rest_style", StyleBoxEmpty.new())
			if current_category:
				style = item.get_meta("selected_style")
			item.add_theme_stylebox_override(state, style)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			item.add_theme_color_override(state, INK if active or current_category else item.get_meta("rest_color", CREAM))

func style_setting_button(item: Button) -> void:
	item.add_theme_font_override("font", body_font)
	var keycap := StyleBoxFlat.new()
	keycap.bg_color = CREAM
	keycap.border_color = Color("b6a588")
	keycap.border_width_bottom = 4
	keycap.set_corner_radius_all(3)
	var hovered := keycap.duplicate() as StyleBoxFlat
	hovered.bg_color = HOVER
	hovered.border_color = Color("699da5")
	var pressed := hovered.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("87c4cb")
	item.set_meta("rest_style", keycap)
	item.set_meta("rest_color", INK)
	item.set_meta("highlight", hovered)
	item.set_meta("pressed_highlight", pressed)
	set_highlight(highlighted_button)

func show_main() -> void:
	clear_page("main")
	board()
	text("P R O J E C T", Vector2(140, 218), Vector2(413, 50), 46)
	text("PIRATE", Vector2(125, 266), Vector2(440, 138), 142)
	menu_button("PLAY", 400, show_play, true, 48, 155, 376, 64)
	menu_button("SHIP CUSTOMIZATION", 474, show_customization, false, 35, 155, 376, 64)
	menu_button("SETTINGS", 548, show_settings, false, 40, 155, 376, 64)
	menu_button("QUIT", 622, func(): get_tree().quit(), false, 40, 155, 376, 64)

func page_header(title: String) -> void:
	board()
	text(title, Vector2(125, 256), Vector2(437, 94), 70)
	menu_button("‹  BACK", 640, go_back, false, 32, 193, 300, 64)

func show_play() -> void:
	clear_page("play")
	page_header("PLAY")
	var modes := ["Single Player", "Multiplayer", "Local"]
	for i in modes.size():
		var mode: String = modes[i]
		menu_button(mode.to_upper(), 362 + i * 92, func(): show_mode(mode), i == 0)

func show_mode(mode: String) -> void:
	clear_page("mode")
	page_header(mode.to_upper())
	if mode == "Single Player":
		text("Take your ship for a sail", Vector2(135, 380), Vector2(420, 60), 32)
		menu_button("SAILING TEST", 462, start_cosmetic_sailing_test, true, 40, 155, 376, 64)
		text("Your saved appearance comes aboard.", Vector2(139, 548), Vector2(413, 70), 22, CREAM, false)
	else:
		text("Coming aboard soon", Vector2(135, 402), Vector2(420, 60), 33)
		text("This mode is not connected in the preview.", Vector2(139, 478), Vector2(413, 90), 22, CREAM, false)

func show_customization() -> void:
	clear_page("customization")
	board()
	# A sheltered inspection berth prevents deep-sea swells from hiding close-ups.
	open_sea_waves = ocean.wave_set
	var sheltered := open_sea_waves.duplicate(true) as OceanWaveSet
	for wave in sheltered.height_waves: wave.steepness *= 0.018
	sheltered.whitecap_strength *= 0.2
	ocean.wave_set = sheltered
	inspect_ship("Full ship")
	workshop = CUSTOMIZATION_PANEL.new()
	workshop_original = ship.appearance.duplicate(true)
	workshop.draft = workshop_original.duplicate(true)
	workshop.appearance_changed.connect(ship.apply)
	workshop.finished.connect(close_customization)
	workshop.inspect_requested.connect(inspect_ship)
	workshop.orbit_requested.connect(func(delta: Vector2):
		orbit_yaw -= delta.x * 0.008
		orbit_pitch = clampf(orbit_pitch + delta.y * 0.006, 0.02, 1.3))
	workshop.zoom_requested.connect(func(amount: float): orbit_distance = clampf(orbit_distance + amount * 1.2, 7, 42))
	ui.add_child(workshop)

func close_customization(saved: bool) -> void:
	if open_sea_waves: ocean.wave_set = open_sea_waves
	ship.apply(workshop.draft if saved else workshop_original)
	show_main()

func inspect_ship(view: String) -> void:
	# Local bow is +Z. Cosmetic assembly follows the same harbor rotation as the hull.
	var presets := {
		"Full ship": [Vector3(0, 4, 0), 32.0, 2.47, 0.38],
		"Bow": [Vector3(0, 2.8, 5.8), 11.0, 0.65, 0.18],
		"Stern": [Vector3(0, 3.6, -5.5), 13.0, 2.55, 0.3],
		"Deck": [Vector3(0, 3.2, 0), 24.0, 2.5, 1.05],
		"Sails": [Vector3(0, 5.8, -1), 20.0, 0.6, 0.2],
		"Secondary sail": [Vector3(0, 6.1, -5.3), 14.0, 2.4, 0.15],
		"Flags": [Vector3(0, 7.5, -0.6), 25.0, 1.48, 0.12],
		"main flag": [Vector3(0, 9.5, -0.5), 10.0, 1.5, 0.1],
		"fore flag": [Vector3(0, 6.4, 3.8), 9.0, 1.5, 0.1],
		"aft flag": [Vector3(0, 8.9, -5.5), 10.0, 1.5, 0.1]
	}
	var selected: Array = presets.get(view, presets["Full ship"])
	orbit_target = selected[0]
	orbit_distance = selected[1]
	orbit_yaw = selected[2] - 0.58
	orbit_pitch = selected[3]

func start_cosmetic_sailing_test() -> void:
	get_tree().change_scene_to_file("res://scenes/cosmetic_sailing_test.tscn")

func show_settings() -> void:
	clear_page("settings")
	var background := ColorRect.new()
	background.color = INK
	ui.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board()
	text("SETTINGS", Vector2(125, 256), Vector2(437, 94), 70)
	var tabs := ["CONTROLS", "GRAPHICS", "RESOLUTION"]
	for i in tabs.size():
		var tab := menu_button(tabs[i], 362 + i * 92, func(): settings_tab = i; show_settings(), i == settings_tab)
		if i == settings_tab:
			active_settings_button = tab
	menu_button("‹  BACK", 640, go_back, false, 32, 193, 300, 64)
	text(tabs[settings_tab], Vector2(672, 121), Vector2(688, 90), 66, CREAM, true, false)
	match settings_tab:
		0:
			var actions := bindings.keys()
			for i in actions.size():
				var action: String = actions[i]
				text(action, Vector2(672, 289 + i * 84), Vector2(430, 65), 26, CREAM, false, false)
				var key := menu_button(bindings[action], 290 + i * 84, func(): pass, false, 36, 1177, 158, 64)
				style_setting_button(key)
				key.set_meta("action", action)
				key.pressed.connect(func():
					if is_instance_valid(pending_binding):
						pending_binding.text = bindings[pending_binding.get_meta("action")]
						pending_binding.add_theme_font_size_override("font_size", 36)
					pending_binding = key
					key.add_theme_font_size_override("font_size", 21)
					key.text = "Press key…")
			text("Select a key to rebind it. Esc cancels.", Vector2(672, 763), Vector2(688, 40), 22, CREAM, false, false)
		1:
			choice_row("Quality preset", ["Low", "Medium", "High"], 290)
			choice_row("Shadows", ["Off", "On"], 412)
			choice_row("Anti-aliasing", ["Off", "2×", "4×", "8×"], 534)
		2:
			choice_row("Display mode", ["Windowed", "Borderless", "Fullscreen"], 290)
			choice_row("Resolution", ["1280 × 720", "1920 × 1080", "2560 × 1440"], 412)
			choice_row("Vertical sync", ["Off", "On"], 534)
	text("Preview choices are kept for this session only.", Vector2(672, 818), Vector2(688, 40), 20, Color("abbcc1"), false, false)

func choice_row(key: String, values: Array, y: float) -> void:
	text(key, Vector2(672, y), Vector2(310, 80), 28, CREAM, false, false)
	var value_panel := Panel.new()
	value_panel.position = Vector2(1070, y + 8)
	value_panel.size = Vector2(224, 64)
	value_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = CREAM
	panel_style.set_corner_radius_all(3)
	value_panel.add_theme_stylebox_override("panel", panel_style)
	ui.add_child(value_panel)
	var value_label := text(values[settings_values[key]], Vector2(1070, y + 8), Vector2(224, 64), 28, INK, false)
	style_setting_button(menu_button("‹", y + 8, func(): cycle_setting(key, values, -1, value_label), false, 46, 1000, 64, 64))
	style_setting_button(menu_button("›", y + 8, func(): cycle_setting(key, values, 1, value_label), false, 46, 1300, 64, 64))

func cycle_setting(key: String, values: Array, step: int, value_label: Label) -> void:
	settings_values[key] = posmod(settings_values[key] + step, values.size())
	value_label.text = values[settings_values[key]]
