class_name FreeLookCamera
extends Camera3D

@export_range(0.0, 10.0, 0.01) var look_sensitivity := 3.0
@export var fly_speed := 20.0
@export var boost_multiplier := 4.0
@export var speed_step := 1.2
@export var min_speed := 1.0
@export var max_speed := 500.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative)


func _process(delta: float) -> void:
	var speed := fly_speed * (boost_multiplier if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	translate(_fly_direction() * speed * delta)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
		MOUSE_BUTTON_WHEEL_UP:
			fly_speed = clampf(fly_speed * speed_step, min_speed, max_speed)
		MOUSE_BUTTON_WHEEL_DOWN:
			fly_speed = clampf(fly_speed / speed_step, min_speed, max_speed)


func _look(relative: Vector2) -> void:
	rotation.y -= relative.x / 1000.0 * look_sensitivity
	rotation.x = clampf(rotation.x - relative.y / 1000.0 * look_sensitivity, -PI / 2.0, PI / 2.0)


func _fly_direction() -> Vector3:
	return Vector3(
		_axis(KEY_A, KEY_D),
		_axis(KEY_Q, KEY_E),
		_axis(KEY_W, KEY_S)
	).normalized()


func _axis(negative: Key, positive: Key) -> float:
	return float(Input.is_physical_key_pressed(positive)) - float(Input.is_physical_key_pressed(negative))
