class_name ShipPlayerInput
extends Node

@export var movement: ShipMovement


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"sail_raise"):
		movement.raise_sails()
	elif event.is_action_pressed(&"sail_lower"):
		movement.lower_sails()


func _physics_process(_delta: float) -> void:
	movement.steer(Input.get_axis(&"steer_left", &"steer_right"))
