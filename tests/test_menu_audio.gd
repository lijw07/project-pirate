extends SceneTree

var failures := 0
var audio: Node
var menu: Node
var heard: Array[StringName] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, caption: String) -> void:
	if not ok: failures += 1
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
		if item.text == caption: return item
	return null

func run() -> void:
	audio = root.get_node("MenuAudio")
	audio.settings_path = "/tmp/project-pirate-test-audio.cfg"
	audio.cue_played.connect(func(cue): heard.append(cue))
	check(AudioServer.get_bus_index("Music") > 0 and AudioServer.get_bus_index("SFX") > 0, "independent audio buses load")
	check(audio.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "imported music loops forward")
	check(is_equal_approx(audio.music.stream.get_length(), 80.0), "complete 80 second pirate shanty imported")
	for cue in audio.CUES:
		check(audio.CUES[cue].loop_mode == AudioStreamWAV.LOOP_DISABLED, "one-shot cue: " + cue)
	menu = load("res://scenes/main_menu_preview.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await create_timer(.3).timeout
	check(audio.music.playing, "main menu starts music")
	check(heard.is_empty(), "initial focus is silent")
	await key(KEY_S)
	check(heard == [&"hover"], "keyboard navigation sounds exactly once")
	await create_timer(.2).timeout
	button("SETTINGS").grab_focus()
	heard.clear()
	await key(KEY_ENTER)
	check(menu.current_page == "settings" and heard == [&"click"], "activation sounds once; new page focus is silent")
	var position_before: float = audio.music.get_playback_position()
	await create_timer(.15).timeout
	check(audio.music.get_playback_position() > position_before, "menu navigation does not restart the score")
	button("AUDIO").pressed.emit()
	await process_frame
	var slider := menu.ui.get_node("MusicVolume") as HSlider
	var effects_slider := menu.ui.get_node("SFXVolume") as HSlider
	await key(KEY_D)
	check(root.gui_get_focus_owner() == slider, "D enters Music from the Audio tab")
	var previous := slider.value
	await key(KEY_LEFT)
	check(root.gui_get_focus_owner() == button("AUDIO") and slider.value == previous, "left returns to Audio without changing an inactive slider")
	await key(KEY_D)
	await key(KEY_A)
	check(root.gui_get_focus_owner() == button("AUDIO") and slider.value == previous, "A returns to Audio without changing an inactive slider")
	await key(KEY_RIGHT)
	await key(KEY_ENTER)
	check(menu.editing_audio_slider == slider and slider.self_modulate == menu.GOLD, "Enter activates slider adjustment with a gold highlight")
	await key(KEY_LEFT)
	check(slider.value == previous - 5, "left arrow adjusts an activated volume slider")
	await key(KEY_D)
	check(slider.value == previous, "D raises volume without moving focus")
	await key(KEY_A)
	check(slider.value == previous - 5, "A lowers volume without moving focus")
	await key(KEY_RIGHT)
	check(slider.value == previous, "right arrow raises volume exactly one step")
	await key(KEY_ESCAPE)
	check(menu.editing_audio_slider == null and menu.current_page == "settings" and root.gui_get_focus_owner() == slider, "Escape releases the slider without leaving Settings")
	await key(KEY_SPACE)
	check(menu.editing_audio_slider == slider, "Space also activates slider adjustment")
	await key(KEY_DOWN)
	check(slider.value == previous - 5 and root.gui_get_focus_owner() == slider, "arrow keys adjust the value while editing")
	await key(KEY_UP)
	await key(KEY_SPACE)
	check(menu.editing_audio_slider == null, "Space finishes adjustment")
	await key(KEY_S)
	check(root.gui_get_focus_owner() == effects_slider, "S moves from Music to Effects")
	await key(KEY_W)
	check(root.gui_get_focus_owner() == slider, "W moves from Effects to Music")
	await key(KEY_DOWN)
	check(root.gui_get_focus_owner() == effects_slider, "down arrow moves from Music to Effects")
	await key(KEY_DOWN)
	check(root.gui_get_focus_owner() == button("‹  BACK"), "down from Effects reaches Back without trapping focus")
	await key(KEY_RIGHT)
	check(root.gui_get_focus_owner() == effects_slider, "right from Back re-enters Effects")
	await key(KEY_UP)
	await key(KEY_UP)
	check(root.gui_get_focus_owner() == button("AUDIO"), "up from Music returns to the Audio tab")
	await key(KEY_TAB)
	check(root.gui_get_focus_owner() == slider, "Tab also enters the audio controls")
	await key(KEY_ENTER)
	slider.value = 0
	await key(KEY_A)
	check(slider.value == 0, "volume stops at zero")
	slider.value = 100
	await key(KEY_D)
	check(slider.value == 100, "volume stops at full")
	await key(KEY_ENTER)
	check(menu.editing_audio_slider == null, "Enter finishes adjustment")
	audio.set_volume("Music", 0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "zero music volume mutes only music")
	audio.set_volume("SFX", 0.65)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "effects remain independent of muted music")
	await create_timer(.45).timeout
	var saved := ConfigFile.new()
	check(saved.load(audio.settings_path) == OK and is_equal_approx(saved.get_value("volume", "SFX", -1.0), .65), "audio settings persist to disk")
	audio.set_volume("Music", .75)
	await create_timer(.2).timeout
	heard.clear()
	await key(KEY_ESCAPE)
	check(menu.current_page == "main" and heard == [&"back"], "Escape back sounds once")
	var disabled := button("QUIT")
	disabled.disabled = true
	heard.clear()
	audio.pointer_ms = Time.get_ticks_msec()
	disabled.mouse_entered.emit()
	check(heard.is_empty(), "disabled buttons remain silent")
	disabled.disabled = false
	await create_timer(.2).timeout
	var play := button("PLAY")
	audio.pointer_ms = Time.get_ticks_msec()
	audio.navigation_ms = Time.get_ticks_msec()
	play.mouse_entered.emit()
	play.focus_entered.emit()
	check(heard == [&"hover"], "overlapping mouse and focus signals share one hover cue")
	menu.show_customization()
	await create_timer(.25).timeout
	heard.clear()
	menu.workshop.tabs["Sails"].pressed.emit()
	await process_frame
	check(heard == [&"click"], "customization controls use shared click audio")
	menu.workshop.save_path = "/tmp/project-pirate-audio-test-ship.json"
	heard.clear()
	menu.workshop._save()
	check(heard == [&"confirm"] and menu.current_page == "main", "successful ship save plays confirmation")
	# Seek across the actual imported loop boundary without waiting a full track.
	audio.music.play(audio.music.stream.get_length() - .2)
	await create_timer(.45).timeout
	check(audio.music.playing and audio.music.get_playback_position() < 2.0, "playback crosses the loop boundary without stopping")
	menu.start_cosmetic_sailing_test()
	await create_timer(.9).timeout
	check(not audio.music.playing, "leaving the menu fades and stops music")
	var pause_menu := current_scene.get_node("PauseMenu")
	pause_menu.open_pause()
	await create_timer(.2).timeout
	heard.clear()
	audio.play_cue(&"click")
	await process_frame
	check(paused and audio.voices.any(func(v): return v.playing), "UI audio continues while gameplay is paused")
	check(not audio.music.playing, "pause does not start the menu score")
	pause_menu.settings_tab = 3
	pause_menu.show_settings()
	await key(KEY_RIGHT)
	var paused_slider := pause_menu.ui.get_node("MusicVolume") as HSlider
	var paused_value := paused_slider.value
	await key(KEY_SPACE)
	await key(KEY_A)
	check(root.gui_get_focus_owner() == paused_slider and paused_slider.value == paused_value - 5, "audio navigation and WASD adjustment also work while paused")
	await key(KEY_ESCAPE)
	check(paused and pause_menu.current_page == "settings" and pause_menu.editing_audio_slider == null, "Escape exits adjustment before pause-menu navigation")
	await key(KEY_LEFT)
	check(root.gui_get_focus_owner() == pause_menu.active_settings_button, "left returns to the settings tabs while paused")
	pause_menu.resume_game()
	audio.save_timer.stop()
	# Capture the real audio mix when running with a device rather than Dummy.
	if AudioServer.get_driver_name() != "Dummy":
		var capture := AudioEffectCapture.new()
		AudioServer.add_bus_effect(0, capture)
		audio.play_cue(&"confirm")
		await create_timer(.2).timeout
		var samples := capture.get_buffer(capture.get_frames_available())
		var peak := 0.0
		for sample in samples: peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		check(peak > .001 and peak < 1.0, "native device mix is audible and unclipped (peak %.4f)" % peak)
		AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	current_scene.queue_free()
	await process_frame
	print("MENU AUDIO FAILURES: ", failures)
	quit(failures)
