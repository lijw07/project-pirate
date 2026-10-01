class_name OverheadCamera
extends Camera3D

@export var target: Node3D
@export_range(-89.0, -10.0, 0.5, "degrees") var pitch_degrees := -45.0
@export var yaw_degrees := 0.0
@export_range(5.0, 500.0, 0.5, "suffix:m") var distance := 60.0
@export_range(5.0, 500.0, 0.5, "suffix:m") var min_distance := 18.0
@export_range(5.0, 1000.0, 0.5, "suffix:m") var max_distance := 180.0
@export var zoom_factor := 1.15
@export var pan_gesture_zoom_speed := 0.1
@export_range(0.1, 30.0, 0.1, "suffix:1/s") var zoom_smoothing := 8.0
@export_range(0.1, 30.0, 0.1, "suffix:1/s") var follow_smoothing := 8.0

var _target_distance := 0.0
var _focus := Vector3.ZERO


func _ready() -> void:
	_target_distance = distance
	if target != null:
		_focus = target.global_position
	_place()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_zoom_with_wheel(event.button_index)
	elif event is InputEventMagnifyGesture:
		zoom_by(1.0 / event.factor)
	elif event is InputEventPanGesture:
		zoom_by(1.0 + event.delta.y * pan_gesture_zoom_speed)


func _process(delta: float) -> void:
	distance = lerpf(distance, _target_distance, 1.0 - exp(-zoom_smoothing * delta))
	if target != null:
		_focus = _focus.lerp(target.global_position, 1.0 - exp(-follow_smoothing * delta))
	_place()


func zoom_by(scale: float) -> void:
	_target_distance = clampf(_target_distance * scale, min_distance, max_distance)


func _zoom_with_wheel(button: MouseButton) -> void:
	if button == MOUSE_BUTTON_WHEEL_UP:
		zoom_by(1.0 / zoom_factor)
	elif button == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_by(zoom_factor)


func _place() -> void:
	var angle := Basis.from_euler(Vector3(deg_to_rad(pitch_degrees), deg_to_rad(yaw_degrees), 0.0))
	global_position = _focus + angle * Vector3(0.0, 0.0, distance)
	look_at(_focus)
