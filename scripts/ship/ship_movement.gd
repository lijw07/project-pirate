class_name ShipMovement
extends Node

signal sail_level_changed(level: int)

const KNOTS_PER_METER_PER_SECOND := 1.944
const REVERSE_LEVEL := -1
const STOPPED_LEVEL := 0
const REVERSING_SPEED_THRESHOLD := -0.5

@export var buoyancy: Buoyancy
@export var local_bow_direction := Vector3.BACK

@export_group("Sails")
@export var sail_speeds: Array[float] = [0.0, 6.0, 11.0, 17.0]
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var reverse_speed := 4.0
@export_range(0.0, 1.0, 0.001) var forward_drag := 0.02
@export_range(0.0, 2.0, 0.01, "suffix:1/s") var forward_linear_drag := 0.08

@export_group("Keel")
@export_range(0.0, 10.0, 0.1, "suffix:1/s") var lateral_grip := 2.5
@export_range(0.0, 5.0, 0.05, "suffix:m") var keel_depth := 0.12

@export_group("Steering")
@export_range(1.0, 90.0, 0.5, "suffix:deg/s") var max_turn_rate_degrees := 26.0
@export_range(0.1, 30.0, 0.1, "suffix:m/s") var full_steerage_speed := 6.0
@export_range(0.0, 1.0, 0.01) var minimum_steerage := 0.2
@export_range(0.1, 10.0, 0.1, "suffix:1/s") var turn_responsiveness := 2.5
@export_range(0.1, 10.0, 0.1, "suffix:1/s") var rudder_speed := 2.5

var sail_level := STOPPED_LEVEL
var rudder := 0.0

var _steer_input := 0.0
var _body: RigidBody3D


func _ready() -> void:
	_body = get_parent() as RigidBody3D
	assert(_body != null, "ShipMovement must be a direct child of a RigidBody3D")
	_body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	_body.linear_damp = 0.0


func _physics_process(delta: float) -> void:
	rudder = move_toward(rudder, _steer_input, rudder_speed * delta)
	var grip := _water_grip()
	if grip <= 0.0:
		return
	_apply_propulsion(grip)
	_apply_keel(grip)
	_apply_steering(grip)


func raise_sails() -> void:
	set_sail_level(sail_level + 1)


func lower_sails() -> void:
	set_sail_level(sail_level - 1)


func set_sail_level(level: int) -> void:
	var clamped := clampi(level, lowest_sail_level(), highest_sail_level())
	if clamped == sail_level:
		return
	sail_level = clamped
	sail_level_changed.emit(sail_level)


func steer(input: float) -> void:
	_steer_input = clampf(input, -1.0, 1.0)


func halt() -> void:
	set_sail_level(STOPPED_LEVEL)
	_steer_input = 0.0
	rudder = 0.0


func lowest_sail_level() -> int:
	return REVERSE_LEVEL if reverse_speed > 0.0 else STOPPED_LEVEL


func highest_sail_level() -> int:
	return sail_speeds.size() - 1


func is_reversing() -> bool:
	return sail_level == REVERSE_LEVEL


func sail_fraction() -> float:
	return float(maxi(sail_level, STOPPED_LEVEL)) / maxf(highest_sail_level(), 1)


func target_speed() -> float:
	return -reverse_speed if is_reversing() else sail_speeds[sail_level]


func forward_direction() -> Vector3:
	var bow := _body.global_basis * local_bow_direction
	return Vector3(bow.x, 0.0, bow.z).normalized()


func forward_speed() -> float:
	return _body.linear_velocity.dot(forward_direction())


func heading_degrees() -> float:
	var forward := forward_direction()
	return fposmod(rad_to_deg(atan2(forward.x, -forward.z)), 360.0)


func _water_grip() -> float:
	return buoyancy.submerged_fraction if buoyancy != null else 1.0


func _apply_propulsion(grip: float) -> void:
	var thrust := _drag_at(target_speed())
	var drag := _drag_at(forward_speed())
	_body.apply_central_force(forward_direction() * (thrust - drag) * _body.mass * grip)


func _drag_at(speed: float) -> float:
	return forward_drag * speed * absf(speed) + forward_linear_drag * speed


func _apply_keel(grip: float) -> void:
	var side := Vector3.UP.cross(forward_direction())
	var sideways_speed := _body.linear_velocity.dot(side)
	var force := -side * sideways_speed * lateral_grip * _body.mass * grip
	_body.apply_force(force, _keel_point())


func _keel_point() -> Vector3:
	var center_of_mass := PhysicsServer3D.body_get_direct_state(_body.get_rid()).center_of_mass
	return center_of_mass - _body.global_basis.y * keel_depth


func _apply_steering(grip: float) -> void:
	var speed := forward_speed()
	var steerage := clampf(absf(speed) / full_steerage_speed, minimum_steerage, 1.0)
	var travel_direction := -1.0 if speed < REVERSING_SPEED_THRESHOLD else 1.0
	var desired_yaw_rate := -rudder * deg_to_rad(max_turn_rate_degrees) * steerage * travel_direction
	var yaw_error := desired_yaw_rate - _body.angular_velocity.y
	_body.apply_torque(Vector3.UP * yaw_error * turn_responsiveness * _yaw_inertia() * grip)


func _yaw_inertia() -> float:
	var state := PhysicsServer3D.body_get_direct_state(_body.get_rid())
	var inverse_inertia := Vector3.UP.dot(state.inverse_inertia_tensor * Vector3.UP)
	return 1.0 / inverse_inertia if inverse_inertia > 0.0 else _body.mass
