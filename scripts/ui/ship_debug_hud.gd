class_name ShipDebugHud
extends Label

const KNOTS_PER_METER_PER_SECOND := 1.944
const CONTROLS := "W / S  raise / lower sails (S at a stop reverses)\nA / D  hold to turn the rudder further (it holds its angle when released)\nScroll or pinch  zoom"

@export var movement: ShipMovement


func _process(_delta: float) -> void:
	text = "\n".join([
		"Sails  %s" % _sail_label(),
		"Speed  %.1f kn  (target %.1f)" % [_knots(movement.forward_speed()), _knots(movement.target_speed())],
		"Heading  %03d°" % (roundi(movement.heading_degrees()) % 360),
		"Rudder  %s" % _rudder_label(),
		"",
		CONTROLS,
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
