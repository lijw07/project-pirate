extends SceneTree

var failures := 0
var level: Node3D
var menu: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, caption: String) -> void:
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", caption)

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame

func button(caption: String) -> Button:
	for item in menu.menu_buttons:
		if item.text == caption:
			return item
	return null

func run() -> void:
	level = load("res://scenes/bouyancy_test_scene.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	menu = load("res://prefabs/ui/pause_menu.tscn").instantiate()
	level.add_child(menu)
	await create_timer(0.3).timeout
	check(not paused and not menu.ui.visible, "overlay starts hidden and gameplay runs")
	check(menu.ocean == null and menu.ship == null, "overlay does not duplicate the gameplay ocean or ship")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var initial_mouse_mode := Input.mouse_mode
	if DisplayServer.get_name() != "headless":
		check(initial_mouse_mode == Input.MOUSE_MODE_CAPTURED, "native gameplay can capture the mouse")
	await key(KEY_ESCAPE)
	# Keep the physical cursor aligned with the injected input in native runs.
	if DisplayServer.get_name() != "headless":
		root.warp_mouse(button("RESUME").get_global_rect().get_center())
		await process_frame
	check(paused and menu.pause_open and menu.ui.visible, "Escape opens pause")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "pause releases the mouse")
	var ocean: Ocean = level.get_node("Ocean")
	var ship: RigidBody3D = level.get_node("FillerShip")
	var camera: Camera3D = level.get_node("FreeLookCamera")
	var wave_time := ocean.wave_time
	var ship_pose := ship.transform
	var camera_pose := camera.transform
	await create_timer(0.15).timeout
	check(ocean.wave_time == wave_time, "ocean animation stops while paused")
	check(ship.transform.is_equal_approx(ship_pose), "ship physics stops while paused")
	check(camera.transform.is_equal_approx(camera_pose), "game camera stops while paused")
	check(root.gui_get_focus_owner() == button("RESUME"), "Resume starts focused")
	await key(KEY_S)
	check(root.gui_get_focus_owner() == button("SETTINGS"), "WASD works while paused")
	await key(KEY_ENTER)
	check(paused and menu.current_page == "settings", "Settings stays inside the paused session")
	if menu.current_page != "settings":
		quit(failures)
		return
	button("GRAPHICS").grab_focus()
	await key(KEY_SPACE)
	check(menu.settings_tab == 1, "Space opens a settings category")
	button("›").grab_focus()
	var previous: int = menu.settings_values["Quality preset"]
	await key(KEY_ENTER)
	check(menu.settings_values["Quality preset"] == (previous + 1) % 3, "settings controls respond while paused")
	await key(KEY_ESCAPE)
	check(paused and menu.current_page == "pause", "Escape from Settings returns to Pause")
	button("SETTINGS").grab_focus()
	await key(KEY_ENTER)
	button("CONTROLS").grab_focus()
	await key(KEY_ENTER)
	button("W").grab_focus()
	await key(KEY_ENTER)
	await key(KEY_ESCAPE)
	check(paused and menu.current_page == "settings" and menu.pending_binding == null, "Escape cancels rebinding without resuming gameplay")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	check(not paused and not menu.ui.visible, "Escape resumes and hides the overlay")
	check(Input.mouse_mode == initial_mouse_mode, "resume restores prior mouse mode")
	await create_timer(0.15).timeout
	check(ocean.wave_time > wave_time, "ocean resumes advancing")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await key(KEY_ESCAPE)
	await key(KEY_ENTER)
	check(not paused and not menu.pause_open, "Resume button works with Enter")
	await key(KEY_ESCAPE)
	button("MAIN MENU").grab_focus()
	await key(KEY_ENTER)
	await process_frame
	check(not paused and current_scene.scene_file_path == "res://scenes/main_menu_preview.tscn", "Main Menu changes scenes without leaving the tree paused")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Main Menu keeps the pointer visible")
	print("PAUSE MENU FAILURES: ", failures)
	quit(failures)
