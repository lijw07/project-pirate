class_name ShipPlayerInput
extends Node

@export var movement: ShipMovement


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"sail_raise"):
		movement.raise_sails()
	elif event.is_action_pressed(&"sail_lower"):
		movement.lower_sails()
	elif event.is_action_pressed(&"steer_left"):
		movement.turn_rudder_left()
	elif event.is_action_pressed(&"steer_right"):
		movement.turn_rudder_right()
