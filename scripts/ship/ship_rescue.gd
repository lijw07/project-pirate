class_name ShipRescue
extends Node

signal rescued

const RESCUE_DISTANCES: Array[float] = [15.0, 25.0, 40.0, 60.0, 90.0]
const RESCUE_ANGLES_DEGREES: Array[float] = [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0, 135.0, -135.0, 180.0]

@export var movement: ShipMovement
@export var stuck_detector: ShipStuckDetector
@export_range(1.0, 50.0, 0.5, "suffix:m") var clearance_radius := 8.0
@export_flags_3d_physics var land_layers := 1

var _body: RigidBody3D


func _ready() -> void:
	_body = get_parent() as RigidBody3D
	assert(_body != null, "ShipRescue must be a direct child of a RigidBody3D")


func rescue_if_stuck() -> bool:
	return stuck_detector.is_stuck and rescue()


func rescue() -> bool:
	var escape := _escape_direction()
	var destination: Variant = _find_open_water(escape)
	if destination == null:
		return false
	_place_ship(destination, escape)
	movement.halt()
	stuck_detector.reset()
	rescued.emit()
	return true


func _escape_direction() -> Vector3:
	var away := Vector3.ZERO
	for land in stuck_detector.touching_land():
		away += _flat(_body.global_position - land.global_position)
	if away.is_zero_approx():
		away = -movement.forward_direction()
	return away.normalized()


func _find_open_water(escape: Vector3) -> Variant:
	for distance in RESCUE_DISTANCES:
		for angle in RESCUE_ANGLES_DEGREES:
			var candidate := _sea_point(_body.global_position + escape.rotated(Vector3.UP, deg_to_rad(angle)) * distance)
			if _is_open_water(candidate):
				return candidate
	return null


func _is_open_water(point: Vector3) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = clearance_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = land_layers
	query.exclude = [_body.get_rid()]
	return _body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _sea_point(point: Vector3) -> Vector3:
	var ocean := get_tree().get_first_node_in_group(Ocean.GROUP) as Ocean
	var sea_level := ocean.global_position.y if ocean != null else 0.0
	return Vector3(point.x, sea_level, point.z)


func _place_ship(destination: Vector3, heading: Vector3) -> void:
	var bow := _flat(movement.local_bow_direction)
	var yaw := atan2(heading.x, heading.z) - atan2(bow.x, bow.z)
	_body.global_transform = Transform3D(Basis(Vector3.UP, yaw), destination)
	_body.linear_velocity = Vector3.ZERO
	_body.angular_velocity = Vector3.ZERO


func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
