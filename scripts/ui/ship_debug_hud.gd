class_name ShipDebugHud
extends Label

const KNOTS_PER_METER_PER_SECOND := 1.944

@export var movement: ShipMovement
@onready var controls := get_node("/root/ControlSettings")


func _process(_delta: float) -> void:
	text = "\n".join([
		"Sails  %s" % _sail_label(),
		"Speed  %.1f kn  (target %.1f)" % [_knots(movement.forward_speed()), _knots(movement.target_speed())],
		"Heading  %03d°" % (roundi(movement.heading_degrees()) % 360),
		"Rudder  %s" % _rudder_label(),
		"",
		"%s / %s  raise / lower sails (%s at a stop reverses)" % [controls.key_label(&"sail_raise"), controls.key_label(&"sail_lower"), controls.key_label(&"sail_lower")],
		"%s / %s  hold to turn the rudder further (it holds its angle when released)" % [controls.key_label(&"steer_left"), controls.key_label(&"steer_right")],
		"Scroll or pinch  zoom",
	])


func _sail_label() -> String:
	if movement.is_reversing():
		return "reverse"
	return "%d / %d" % [movement.sail_level, movement.highest_sail_level()]


func _rudder_label() -> String:
	if is_zero_approx(movement.rudder):
		return "centred"
	var side := "right" if movement.rudder > 0.0 else "left"
	return "%d%% %s" % [roundi(absf(movement.rudder) * 100.0), side]


func _knots(meters_per_second: float) -> float:
	return meters_per_second * KNOTS_PER_METER_PER_SECOND
