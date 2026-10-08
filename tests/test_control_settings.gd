extends SceneTree

const SETTINGS := preload("res://scripts/ui/control_settings.gd")
const NEW_KEYS := [KEY_I, KEY_K, KEY_J, KEY_L, KEY_T]
const OLD_KEYS := [[KEY_W, KEY_UP], [KEY_S, KEY_DOWN], [KEY_A, KEY_LEFT], [KEY_D, KEY_RIGHT], [KEY_R]]
var failures := 0
var controls: Node
var menu: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, caption: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", caption)

func event_for(code: Key, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event

func key(code: Key, duration := 0.0) -> void:
	Input.parse_input_event(event_for(code))
	await process_frame
	if duration > 0: await create_timer(duration).timeout
	Input.parse_input_event(event_for(code, false))
	await process_frame

func binding_button(action: StringName) -> Button:
	for item in menu.menu_buttons:
		if item.get_meta("action", &"") == action: return item
	return null

func run() -> void:
	controls = root.get_node("ControlSettings")
	controls.settings_path = "/tmp/pirate-controls-%s.cfg" % OS.get_process_id()
	controls.overrides.clear()
	InputMap.load_from_project_settings()
	menu = load("res://scenes/main_menu_preview.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu.show_settings()
	await process_frame
	var actions: Array = SETTINGS.ACTIONS.values()
	for i in actions.size():
		var action: StringName = actions[i]
		binding_button(action).grab_focus()
		await key(KEY_ENTER)
		check(menu.pending_binding == binding_button(action), "Enter begins binding: " + action)
		await key(NEW_KEYS[i])
		check(menu.pending_binding == null and binding_button(action).text == OS.get_keycode_string(NEW_KEYS[i]), "settings displays chosen key: " + action)
		check(InputMap.event_is_action(event_for(NEW_KEYS[i]), action), "chosen key drives action: " + action)
		for old in OLD_KEYS[i]:
			check(not InputMap.event_is_action(event_for(old), action), "old key removed: " + OS.get_keycode_string(old))
	binding_button(&"sail_raise").pressed.emit()
	await key(KEY_ESCAPE)
	check(menu.current_page == "settings" and binding_button(&"sail_raise").text == "I", "Escape cancels without changing the binding")
	menu.show_main()
	menu.show_settings()
	check(binding_button(&"sail_raise").text == "I", "reopening settings retains bindings")
	menu.free()
	var level: Node3D = load("res://scenes/cosmetic_sailing_test.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	menu = level.get_node("PauseMenu")
	var movement := level.get_node("PlayerShip/ShipMovement") as ShipMovement
	await process_frame
	await key(KEY_W)
	await key(KEY_UP)
	check(movement.sail_level == 0, "old sail keys no longer move the ship")
	await key(KEY_I)
	check(movement.sail_level == 1, "new raise key moves the actual ship")
	await key(KEY_K)
	check(movement.sail_level == 0, "new lower key lowers the actual sails")
	await key(KEY_A, 0.2)
	await key(KEY_LEFT, 0.2)
	check(is_zero_approx(movement.rudder), "old steering keys no longer turn the ship")
	await key(KEY_J, 0.3)
	check(movement.rudder < -0.1, "new left key turns the actual rudder")
	movement.set_rudder(0)
	await key(KEY_L, 0.3)
	check(movement.rudder > 0.1, "new right key turns the actual rudder")
	check("I / K" in level.get_node("Hud/ShipDebugHud").text and "J / L" in level.get_node("Hud/ShipDebugHud").text, "gameplay hints show chosen keys")
	await key(KEY_ESCAPE)
	menu.show_settings()
	check(binding_button(&"sail_raise").text == "I", "pause menu reads the same bindings as the harbor")
	binding_button(&"sail_raise").pressed.emit()
	await key(KEY_U)
	check(paused and menu.current_page == "settings", "binding while paused does not resume gameplay")
	menu.resume_game()
	await key(KEY_I)
	check(movement.sail_level == 0, "previous custom key is removed after rebinding in pause")
	await key(KEY_U)
	check(movement.sail_level == 1, "pause binding takes effect on resume")
	level.free()
	# Rebuild the input map and load a fresh settings instance, as at startup.
	InputMap.load_from_project_settings()
	var reloaded := SETTINGS.new()
	reloaded.settings_path = controls.settings_path
	root.add_child(reloaded)
	check(reloaded.key_label(&"sail_raise") == "U" and reloaded.key_label(&"steer_right") == "L", "saved bindings restore in a fresh settings instance")
	check(not InputMap.event_is_action(event_for(KEY_W), &"sail_raise"), "loading saved controls removes defaults too")
	DirAccess.remove_absolute(controls.settings_path)
	reloaded.free()
	print("CONTROL SETTINGS FAILURES: ", failures)
	quit(failures)
