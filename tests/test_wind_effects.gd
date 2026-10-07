extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1


func run() -> void:
	var level = load("res://scenes/wind_test_scene.tscn").instantiate()
	root.add_child(level)
	level.set_process(false)
	var wind: WindEffects = level.wind
	check(wind.ocean == level.ocean and wind.camera == level.camera and wind.ship == level.ship, "test scene uses shared ocean, ship and camera")
	check(not level.ship.get_node("ship-pirate-medium/flag-b").visible, "original upper flag is hidden only in this scene")
	level._process(1.0 / 60.0)
	check(wind.ribbons.get_surface_count() == 1 and wind.pennant.get_surface_count() == 1, "breeze builds trails and pennant")
	level.direction_slider.value = 90
	check(wind.flow_direction().is_equal_approx(Vector3.RIGHT), "direction slider sends east wind toward +X")
	level.direction_slider.value = 270
	check(wind.flow_direction().is_equal_approx(Vector3.LEFT), "direction reversal sends west wind toward -X")
	level.pause_button.pressed.emit()
	var before_time := wind.time
	var before_position: Vector3 = level.ship.position
	level._process(1.0)
	check(wind.time == before_time and level.ocean.wave_time == before_time and level.ship.position == before_position, "pause freezes ocean, wind and ship together")
	level.pause_button.pressed.emit()
	level._process(0.1)
	check(wind.time > before_time, "resume advances animation")
	level.trail_button.pressed.emit()
	wind.refresh()
	check(wind.ribbons.get_surface_count() == 0 and wind.pennant.get_surface_count() == 1, "trail toggle removes trails but retains pennant")
	level.trail_button.pressed.emit()
	wind.refresh()
	check(wind.ribbons.get_surface_count() == 1, "trail toggle restores trails")
	level.preset_buttons[0].pressed.emit()
	for tick in 360:
		wind.advance(1.0 / 60.0)
	wind.refresh()
	check(wind.strength == 0 and wind.ribbons.get_surface_count() == 0, "calm fades all air trails out")
	level.preset_buttons[2].pressed.emit()
	for tick in 240:
		wind.advance(1.0 / 60.0)
	check(absf(wind.strength - 0.78) < 0.001, "strong preset reaches steady strength")
	level.preset_buttons[3].pressed.emit()
	var low := 1.0
	var high := 0.0
	for tick in 480:
		wind.advance(1.0 / 60.0)
		low = minf(low, wind.strength)
		high = maxf(high, wind.strength)
	check(low < 0.4 and high > 0.85, "gusts build and subside over time")
	# Verify real viewport event routing after a UI control takes focus.
	level.pause_button.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	root.push_input(key)
	check(wind.paused, "space shortcut pauses even with a focused button")
	wind.paused = false
	level.pause_button.text = "Pause  [Space]"
	root.size = Vector2i(960, 600)
	await process_frame
	level.fit_ui()
	var ui_bounds := Rect2(level.ui_layer.offset, Vector2(1440, 900) * level.ui_layer.scale)
	check(root.get_visible_rect().encloses(ui_bounds), "all controls fit inside the resized viewport")
	root.size = Vector2i(1296, 810)
	await process_frame
	level.fit_ui()
	if "--capture" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://tests/reports/wind")
		for index in range(4):
			level.preset_buttons[index].pressed.emit()
			level.direction_slider.value = 270 if index == 3 else 90
			for tick in 240:
				wind.advance(1.0 / 60.0)
			level._process(0.0)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/reports/wind/preset_%d.png" % index)
	level.free()
	print("wind effect test failures: ", failures)
	quit(failures)
