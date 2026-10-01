class_name StuckPrompt
extends Control

const UNSTUCK_ACTION := &"ship_unstuck"

@export var stuck_detector: ShipStuckDetector
@export var message_label: Label


func _ready() -> void:
	message_label.text = "Stuck?  Press [%s] to free your ship" % _action_key_name()
	stuck_detector.stuck_changed.connect(_on_stuck_changed)
	visible = stuck_detector.is_stuck


func _on_stuck_changed(is_stuck: bool) -> void:
	visible = is_stuck


func _action_key_name() -> String:
	for event in InputMap.action_get_events(UNSTUCK_ACTION):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode)
	return "?"
