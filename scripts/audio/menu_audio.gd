extends Node
## Persistent menu score and shared UI voices; works while the game is paused.

signal cue_played(cue: StringName)

const SETTINGS_PATH := "user://audio_settings.cfg"
const CUES := {
	&"hover": preload("res://assets/audio/ui/hover.wav"),
	&"click": preload("res://assets/audio/ui/click.wav"),
	&"back": preload("res://assets/audio/ui/back.wav"),
	&"confirm": preload("res://assets/audio/ui/confirm.wav"),
}
const MUSIC := preload("res://assets/audio/music/harbor_of_rivals.wav")
const MUSIC_LEVEL_DB := -9.0
var levels := {"Music": 0.75, "SFX": 0.8}
var settings_path := SETTINGS_PATH
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var fade: Tween
var save_timer: Timer
var last_hover_ms := -1000
var suppress_hover_until := 0
var navigation_ms := -1000
var pointer_ms := -1000
var last_hover_id := 0
var last_cue: StringName
var cue_count := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		for bus in levels:
			var value: Variant = config.get_value("volume", bus, levels[bus])
			if (value is float or value is int) and is_finite(float(value)):
				levels[bus] = clampf(float(value), 0.0, 1.0)
	for bus in levels:
		apply_volume(bus)
	music = AudioStreamPlayer.new()
	music.name = "MenuMusic"
	music.bus = &"Music"
	music.stream = MUSIC
	music.volume_db = -60.0
	add_child(music)
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		voices.append(player)
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = 0.35
	save_timer.timeout.connect(save_settings)
	add_child(save_timer)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not event.relative.is_zero_approx():
		pointer_ms = Time.get_ticks_msec()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_TAB, KEY_Q, KEY_E]:
		navigation_ms = Time.get_ticks_msec()
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		navigation_ms = Time.get_ticks_msec()

func bind_button(button: BaseButton, cue: StringName = &"click") -> void:
	if button.has_meta("menu_audio_bound"):
		return
	button.set_meta("menu_audio_bound", true)
	button.mouse_entered.connect(func(): hover_control(button, false))
	button.focus_entered.connect(func(): hover_control(button, true))
	if not cue.is_empty():
		button.pressed.connect(func():
			if not button.disabled and button.is_visible_in_tree(): play_cue(cue))

func hover_control(button: Control, keyboard: bool) -> void:
	var now := Time.get_ticks_msec()
	if (button is BaseButton and button.disabled) or not button.is_visible_in_tree() or now < suppress_hover_until:
		return
	# Programmatic focus/page restoration is silent; mouse + focus is one cue.
	if now - (navigation_ms if keyboard else pointer_ms) > 150:
		return
	if now - last_hover_ms < 65 or (last_hover_id == button.get_instance_id() and now - last_hover_ms < 180):
		return
	last_hover_ms = now
	last_hover_id = button.get_instance_id()
	play_cue(&"hover")

func play_cue(cue: StringName) -> void:
	if not CUES.has(cue): return
	if cue != &"hover": suppress_hover_until = Time.get_ticks_msec() + 160
	var voice := voices[0]
	for candidate in voices:
		if not candidate.playing:
			voice = candidate
			break
	voice.stream = CUES[cue]
	voice.volume_db = -3.0 if cue == &"hover" else 0.0
	voice.play()
	last_cue = cue
	cue_count += 1
	cue_played.emit(cue)

func start_menu_music() -> void:
	if fade: fade.kill()
	if not music.playing:
		music.volume_db = -60.0
		music.play()
	fade = create_tween()
	fade.tween_property(music, "volume_db", MUSIC_LEVEL_DB, 1.4)

func stop_menu_music() -> void:
	if fade: fade.kill()
	fade = create_tween()
	fade.tween_property(music, "volume_db", -60.0, 0.7)
	fade.tween_callback(music.stop)

func set_volume(bus: String, value: float) -> void:
	if not levels.has(bus) or not is_finite(value): return
	levels[bus] = clampf(value, 0.0, 1.0)
	apply_volume(bus)
	save_timer.start()

func apply_volume(bus: String) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0: return
	var value: float = levels[bus]
	AudioServer.set_bus_mute(index, value <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))

func save_settings() -> void:
	var config := ConfigFile.new()
	for bus in levels: config.set_value("volume", bus, levels[bus])
	var error := config.save(settings_path)
	if error != OK: push_warning("Could not save audio settings: " + error_string(error))

func quit_game() -> void:
	# Let the button transient reach the device before closing the game.
	save_settings()
	await get_tree().create_timer(0.18, true).timeout
	get_tree().quit()

func _exit_tree() -> void:
	if is_instance_valid(save_timer) and not save_timer.is_stopped(): save_settings()
