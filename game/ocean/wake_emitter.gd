class_name WakeEmitter
extends Node3D

const GROUP := &"ocean_wakes"
const BREAK_SPEED := -1.0
const JUMP_SPACINGS := 3.0

@export_range(0.5, 20.0, 0.1, "suffix:m") var emit_spacing := 4.0
@export_range(1.0, 45.0, 0.5, "degrees") var turn_spacing_degrees := 5.0
@export_range(0.1, 10.0, 0.1, "suffix:m") var min_turn_spacing := 1.0
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var min_speed := 1.0
@export_range(2, 95, 1) var max_points := 40

var _points := PackedVector4Array()
var _emitted_direction := Vector2.ZERO
var _ocean: Ocean


func _enter_tree() -> void:
	add_to_group(GROUP)


func _physics_process(_delta: float) -> void:
	var ocean := _find_ocean()
	if ocean == null:
		return
	_expire(ocean.time - ocean.wake_lifetime)
	if is_moving():
		_trail_behind(ocean.time)


func shader_points() -> PackedVector4Array:
	var points := _points.duplicate()
	if is_moving() and _ocean != null:
		points.insert(0, _point_here(_ocean.time))
	return points


func is_moving() -> bool:
	return speed() >= min_speed


func speed() -> float:
	return _flat_velocity().length()


func clear() -> void:
	_points.clear()


func _trail_behind(now: float) -> void:
	if _points.is_empty() or _ends_in_break():
		_emit(now)
		return
	var travelled := _flat_distance_to(_points[0])
	if travelled > emit_spacing * JUMP_SPACINGS:
		_points.insert(0, _break_point(now))
		_emit(now)
	elif travelled >= emit_spacing or _turned_since_emit(travelled):
		_emit(now)


func _turned_since_emit(travelled: float) -> bool:
	if travelled < min_turn_spacing:
		return false
	var turned := absf(_emitted_direction.angle_to(_flat_velocity()))
	return rad_to_deg(turned) >= turn_spacing_degrees


func _emit(now: float) -> void:
	_points.insert(0, _point_here(now))
	_emitted_direction = _flat_velocity()
	if _points.size() > max_points:
		_points.resize(max_points)


func _expire(oldest_birth: float) -> void:
	while _points.size() >= 2 and _points[_points.size() - 2].z < oldest_birth:
		_points.remove_at(_points.size() - 1)
	if _points.size() == 1 and _points[0].z < oldest_birth:
		_points.clear()


func _ends_in_break() -> bool:
	return not _points.is_empty() and _points[0].w < 0.0


func _point_here(now: float) -> Vector4:
	return Vector4(global_position.x, global_position.z, now, speed())


func _break_point(now: float) -> Vector4:
	return Vector4(global_position.x, global_position.z, now, BREAK_SPEED)


func _flat_distance_to(point: Vector4) -> float:
	return Vector2(global_position.x, global_position.z).distance_to(Vector2(point.x, point.y))


func _flat_velocity() -> Vector2:
	var body := get_parent() as RigidBody3D
	if body == null:
		return Vector2.ZERO
	return Vector2(body.linear_velocity.x, body.linear_velocity.z)


func _find_ocean() -> Ocean:
	if not is_instance_valid(_ocean):
		_ocean = get_tree().get_first_node_in_group(Ocean.GROUP) as Ocean
	return _ocean
