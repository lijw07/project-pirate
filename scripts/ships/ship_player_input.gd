class_name ShipPlayerInput
extends Node

@export var movement: ShipMovement


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"sail_raise"):
		movement.raise_sails()
	elif event.is_action_pressed(&"sail_lower"):
		movement.lower_sails()


func _physics_process(delta: float) -> void:
	var steering := Input.get_axis(&"steer_left", &"steer_right")
	if is_zero_approx(steering):
		movement.settle_rudder()
	else:
		movement.turn_rudder(steering, delta)
