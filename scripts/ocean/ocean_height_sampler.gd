class_name OceanHeightSampler
extends Node

const NO_SLOT := -1
const CAPACITY := 256
const INVERSION_ITERATIONS := 5

var _ocean: Ocean
var _points := PackedVector2Array()
var _slot_used := PackedByteArray()


func _init() -> void:
	_points.resize(CAPACITY)
	_slot_used.resize(CAPACITY)


func bind(ocean: Ocean) -> void:
	_ocean = ocean


func allocate(count: int) -> int:
	var run := 0
	for slot in CAPACITY:
		run = run + 1 if _slot_used[slot] == 0 else 0
		if run == count:
			var first := slot - count + 1
			_mark_slots(first, count, 1)
			return first
	return NO_SLOT


func release(first_slot: int, count: int) -> void:
	_mark_slots(first_slot, count, 0)


func set_point(slot: int, world_position: Vector3) -> void:
	_points[slot] = Vector2(world_position.x, world_position.z)


func height(slot: int) -> float:
	return height_at(_points[slot])


func height_at(world_xz: Vector2) -> float:
	if _ocean == null:
		return 0.0
	var rest := world_xz
	for iteration in INVERSION_ITERATIONS:
		rest = world_xz - _horizontal(_ocean.surface_offset_at(rest))
	return _ocean.global_position.y + _ocean.surface_offset_at(rest).y


func _horizontal(offset: Vector3) -> Vector2:
	return Vector2(offset.x, offset.z)


func _mark_slots(first_slot: int, count: int, value: int) -> void:
	for slot in range(first_slot, first_slot + count):
		_slot_used[slot] = value
