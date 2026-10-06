class_name ShipWake
extends Node

const CAPACITY := 32
const LIFETIME := 2.7
const SAMPLE_INTERVAL := 0.12
const MIN_SPEED := 0.35
const FULL_STRENGTH_SPEED := 8.0
const BOW_OFFSET := 4.3
const STERN_OFFSET := 3.3
const BOUNDS_MARGIN := 7.0

@export var ocean: Ocean
@export var movement: ShipMovement

var points: Array[Vector4] = []
var elapsed := 0.0
var _sample_time := 0.0
var _previous_position := Vector3.ZERO
var _hull_forward := Vector3.BACK
var _has_position := false
var _travel_sign := 0.0
var _head := Vector4.ZERO
var _has_head := false


func _physics_process(delta: float) -> void:
	if not is_instance_valid(ocean) or not is_instance_valid(movement):
		return
	var body := movement.get_parent() as RigidBody3D
	var wet := movement.buoyancy == null or movement.buoyancy.submerged_fraction > 0.05
	_sample(body.global_position, movement.forward_direction(), movement.forward_speed(), wet, delta)
	_upload()


func clear() -> void:
	points.clear()
	_has_head = false
	_sample_time = 0.0
	_travel_sign = 0.0


func _sample(position: Vector3, forward: Vector3, signed_speed: float, wet: bool, delta: float) -> void:
	elapsed += delta
	var horizontal := Vector3(position.x, 0.0, position.z)
	if _has_position and horizontal.distance_to(_previous_position) > maxf(8.0, absf(signed_speed) * delta * 3.0):
		clear()
	_previous_position = horizontal
	_hull_forward = forward
	_has_position = true
	while not points.is_empty() and elapsed - points.back().z >= LIFETIME:
		points.pop_back()
	if _has_head and elapsed - _head.z >= LIFETIME:
		_has_head = false
	if not wet or absf(signed_speed) < MIN_SPEED:
		return
	var travel_sign := signf(signed_speed)
	if _travel_sign != 0.0 and travel_sign != _travel_sign:
		clear()
	_travel_sign = travel_sign
	# The leading end cuts the water: bow ahead, stern when backing up.
	var origin := horizontal + forward * (BOW_OFFSET if travel_sign > 0.0 else -STERN_OFFSET)
	var strength := smoothstep(MIN_SPEED, FULL_STRENGTH_SPEED, absf(signed_speed))
	_head = Vector4(origin.x, origin.z, elapsed, strength)
	_has_head = true
	_sample_time += delta
	if points.is_empty() or _sample_time >= SAMPLE_INTERVAL:
		points.push_front(_head)
		_sample_time = 0.0
		if points.size() > CAPACITY - 1:
			points.pop_back()


func _upload() -> void:
	var water := ocean.water()
	if water == null:
		return
	var samples := PackedVector4Array()
	if _has_head:
		samples.append(_head)
	for point in points:
		samples.append(point)
	var count := samples.size()
	var bounds := Vector4(INF, INF, -INF, -INF)
	for point in samples:
		bounds.x = minf(bounds.x, point.x - BOUNDS_MARGIN)
		bounds.y = minf(bounds.y, point.y - BOUNDS_MARGIN)
		bounds.z = maxf(bounds.z, point.x + BOUNDS_MARGIN)
		bounds.w = maxf(bounds.w, point.y + BOUNDS_MARGIN)
	samples.resize(CAPACITY)
	water.set_shader_parameter("wake_points", samples)
	water.set_shader_parameter("wake_count", count)
	water.set_shader_parameter("wake_time", elapsed)
	water.set_shader_parameter("wake_hull", Vector4(_previous_position.x, _previous_position.z, _hull_forward.x, _hull_forward.z))
	water.set_shader_parameter("wake_bounds", bounds if count > 0 else Vector4.ZERO)


func _exit_tree() -> void:
	if is_instance_valid(ocean) and ocean.water() != null:
		ocean.water().set_shader_parameter("wake_count", 0)
