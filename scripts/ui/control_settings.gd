extends Node
## Shared gameplay bindings, loaded before either the harbor or sailing scenes.

const SETTINGS_PATH := "user://control_settings.cfg"
const ACTIONS := {
	"Raise sails": &"sail_raise",
	"Lower sails": &"sail_lower",
	"Steer left": &"steer_left",
	"Steer right": &"steer_right",
	"Free ship": &"ship_unstuck",
}
var settings_path := SETTINGS_PATH
var overrides: Dictionary = {}

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	for action in ACTIONS.values():
		var code: Variant = config.get_value("keys", action, 0)
		if code is int and code > 0 and code != KEY_ESCAPE:
			overrides[action] = code
			apply_key(action, code)

func key_label(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode)
	return "Unbound"

func rebind(action: StringName, event: InputEventKey) -> void:
	var code := event.physical_keycode if event.physical_keycode else event.keycode
	if not action in ACTIONS.values() or code == 0 or code == KEY_ESCAPE:
		return
	overrides[action] = code
	apply_key(action, code)
	var config := ConfigFile.new()
	for saved_action in overrides:
		config.set_value("keys", saved_action, overrides[saved_action])
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Could not save controls: " + error_string(error))

func apply_key(action: StringName, code: int) -> void:
	# Replace every old keyboard alternative, preserving any controller bindings.
	Input.action_release(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var key := InputEventKey.new()
	key.physical_keycode = code
	InputMap.action_add_event(action, key)
