@tool
class_name Buoyancy
extends Node3D

const PREVIEW_RESPONSE := 6.0
const MIN_FIT_DETERMINANT := 1e-6

@export_range(0.05, 10.0, 0.05, "suffix:m") var draft := 0.95
@export_range(1.0, 10.0, 0.1) var max_submersion_ratio := 2.0
@export_range(0.0, 2.0, 0.05) var damping_ratio := 0.8
@export_range(0.0, 5.0, 0.1) var airborne_gravity_boost := 3.0
@export var editor_preview_target: Node3D

var submerged_fraction := 0.0

var _body: RigidBody3D
var _ocean: Ocean
var _probes: Array[Marker3D] = []
var _previous_surface_heights := PackedFloat32Array()
var _first_slot := OceanHeightSampler.NO_SLOT
var _preview_rest := Transform3D.IDENTITY
var _preview_offset := Transform3D.IDENTITY


static func water_pose(points: PackedVector3Array, rises: PackedFloat32Array) -> Transform3D:
	var plane := _fit_rise_plane(points, rises)
	var up := Vector3(-plane.y, 1.0, -plane.z).normalized()
	return Transform3D(Basis(Quaternion(Vector3.UP, up)), Vector3.UP * plane.x)


static func _fit_rise_plane(points: PackedVector3Array, rises: PackedFloat32Array) -> Vector3:
	var centroid := Vector2.ZERO
	var mean_rise := 0.0
	for index in points.size():
		centroid += Vector2(points[index].x, points[index].z)
		mean_rise += rises[index]
	centroid /= points.size()
	mean_rise /= points.size()
	var covariance := Vector3.ZERO
	var correlation := Vector2.ZERO
	for index in points.size():
		var spread := Vector2(points[index].x, points[index].z) - centroid
		covariance += Vector3(spread.x * spread.x, spread.x * spread.y, spread.y * spread.y)
		correlation += spread * (rises[index] - mean_rise)
	var slope := _solve_slope(covariance, correlation)
	return Vector3(mean_rise - slope.dot(centroid), slope.x, slope.y)


static func _solve_slope(covariance: Vector3, correlation: Vector2) -> Vector2:
	var determinant := covariance.x * covariance.z - covariance.y * covariance.y
	if absf(determinant) < MIN_FIT_DETERMINANT:
		return Vector2.ZERO
	return Vector2(
		correlation.x * covariance.z - correlation.y * covariance.y,
		correlation.y * covariance.x - correlation.x * covariance.y
	) / determinant


func _ready() -> void:
	_body = get_parent() as RigidBody3D
	assert(_body != null, "Buoyancy must be a direct child of a RigidBody3D")
	_collect_probes()
	assert(not _probes.is_empty(), "Buoyancy needs Marker3D probe children")
	child_order_changed.connect(_on_probes_changed)
	if editor_preview_target:
		_preview_rest = editor_preview_target.transform


func _exit_tree() -> void:
	_release_slots()
	if Engine.is_editor_hint():
		_show_rest_pose()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			_show_rest_pose()
		NOTIFICATION_EDITOR_POST_SAVE:
			_show_preview_pose()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or editor_preview_target == null or not _acquire_ocean():
		return
	var target := water_pose(_probe_body_points(), _probe_rises())
	_preview_offset = _preview_offset.interpolate_with(target, 1.0 - exp(-PREVIEW_RESPONSE * delta))
	_show_preview_pose()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _acquire_ocean():
		return
	var mass_share := _body.mass / _probes.size()
	var weight_share := mass_share * _gravity()
	var damping := heave_damping()
	var submerged := 0
	var lift_shortfall := 0.0
	for index in _probes.size():
		var point := _probes[index].global_position
		var surface := _surface_height(index, point)
		var surface_speed := _surface_speed(index, surface, delta)
		var lift := _lift_for_depth(surface - point.y)
		lift_shortfall += 1.0 - minf(lift, 1.0)
		if lift <= 0.0:
			continue
		submerged += 1
		var offset := point - _body.global_position
		var speed_through_surface := _point_velocity(offset).y - surface_speed
		var force := Vector3.UP * (weight_share * lift - mass_share * damping * speed_through_surface)
		_body.apply_force(force, offset)
	submerged_fraction = float(submerged) / _probes.size()
	_pull_back_into_water(lift_shortfall / _probes.size())


func heave_damping() -> float:
	return 2.0 * damping_ratio * sqrt(_gravity() / draft)


func _pull_back_into_water(riding_high: float) -> void:
	_body.apply_central_force(Vector3.DOWN * _body.mass * _gravity() * airborne_gravity_boost * riding_high)


func _lift_for_depth(depth: float) -> float:
	if depth <= 0.0:
		return 0.0
	return minf(depth / draft, max_submersion_ratio)


func _surface_speed(index: int, surface: float, delta: float) -> float:
	var previous := _previous_surface_heights[index]
	_previous_surface_heights[index] = surface
	if is_nan(previous):
		return 0.0
	return (surface - previous) / delta


func _surface_height(index: int, point: Vector3) -> float:
	var slot := _first_slot + index
	_ocean.height_sampler.set_point(slot, point)
	return _ocean.height_sampler.height(slot)


func _probe_body_points() -> PackedVector3Array:
	var to_body := _body.global_transform.affine_inverse()
	var points := PackedVector3Array()
	for probe in _probes:
		points.append(to_body * probe.global_position)
	return points


func _probe_rises() -> PackedFloat32Array:
	var to_body := _body.global_transform.affine_inverse()
	var rises := PackedFloat32Array()
	for index in _probes.size():
		var point := _probes[index].global_position
		var resting_point := Vector3(point.x, _surface_height(index, point) - draft, point.z)
		rises.append((to_body * resting_point).y - (to_body * point).y)
	return rises


func _show_preview_pose() -> void:
	if editor_preview_target:
		editor_preview_target.transform = _preview_offset * _preview_rest


func _show_rest_pose() -> void:
	if editor_preview_target:
		editor_preview_target.transform = _preview_rest


func _point_velocity(offset: Vector3) -> Vector3:
	return _body.linear_velocity + _body.angular_velocity.cross(offset)


func _collect_probes() -> void:
	_probes.clear()
	for child in get_children():
		if child is Marker3D:
			_probes.append(child)
	_previous_surface_heights.resize(_probes.size())
	_previous_surface_heights.fill(NAN)


func _on_probes_changed() -> void:
	_release_slots()
	_collect_probes()


func _acquire_ocean() -> bool:
	if is_instance_valid(_ocean):
		return true
	if _body == null or _probes.is_empty() or not is_inside_tree():
		return false
	var ocean := get_tree().get_first_node_in_group(Ocean.GROUP) as Ocean
	if ocean == null:
		return false
	var slot := ocean.height_sampler.allocate(_probes.size())
	if slot == OceanHeightSampler.NO_SLOT:
		push_error("Ocean height sampler has no free probe slots")
		return false
	_ocean = ocean
	_first_slot = slot
	return true


func _release_slots() -> void:
	if is_instance_valid(_ocean):
		_ocean.height_sampler.release(_first_slot, _probes.size())
	_ocean = null
	_first_slot = OceanHeightSampler.NO_SLOT


func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity")) * _body.gravity_scale
