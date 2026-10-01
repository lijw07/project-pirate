class_name Buoyancy
extends Node3D

@export_range(0.05, 10.0, 0.05, "suffix:m") var draft := 0.95
@export_range(1.0, 10.0, 0.1) var max_submersion_ratio := 2.0
@export_range(0.0, 2.0, 0.05) var damping_ratio := 0.8
@export_range(0.0, 5.0, 0.1) var airborne_gravity_boost := 1.5

var submerged_fraction := 0.0

var _body: RigidBody3D
var _ocean: Ocean
var _probes: Array[Marker3D] = []


func _ready() -> void:
	_body = get_parent() as RigidBody3D
	assert(_body != null, "Buoyancy must be a direct child of a RigidBody3D")
	for child in get_children():
		if child is Marker3D:
			_probes.append(child)
	assert(not _probes.is_empty(), "Buoyancy needs Marker3D probe children")


func _physics_process(_delta: float) -> void:
	if not _has_ocean():
		return
	var mass_share := _body.mass / _probes.size()
	var weight_share := mass_share * _gravity()
	var damping := heave_damping()
	var submerged := 0
	for probe in _probes:
		var point := probe.global_position
		var lift := _probe_lift(point)
		if lift <= 0.0:
			continue
		submerged += 1
		var offset := point - _body.global_position
		var vertical_speed := _point_velocity(offset).y
		var force := Vector3.UP * (weight_share * lift - mass_share * damping * vertical_speed)
		_body.apply_force(force, offset)
	submerged_fraction = float(submerged) / _probes.size()
	_pull_back_into_water()


func _pull_back_into_water() -> void:
	var exposed := 1.0 - submerged_fraction
	_body.apply_central_force(Vector3.DOWN * _body.mass * _gravity() * airborne_gravity_boost * exposed)


func heave_damping() -> float:
	return 2.0 * damping_ratio * sqrt(_gravity() / draft)


func _probe_lift(point: Vector3) -> float:
	var depth := _ocean.height_at(point) - point.y
	if depth <= 0.0:
		return 0.0
	return minf(depth / draft, max_submersion_ratio)


func _point_velocity(offset: Vector3) -> Vector3:
	return _body.linear_velocity + _body.angular_velocity.cross(offset)


func _has_ocean() -> bool:
	if not is_instance_valid(_ocean):
		_ocean = get_tree().get_first_node_in_group(Ocean.GROUP) as Ocean
	return _ocean != null


func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity")) * _body.gravity_scale
