class_name ShipStuckDetector
extends Node

signal stuck_changed(is_stuck: bool)

const CONTACTS_TO_REPORT := 8

@export var movement: ShipMovement
@export_range(0.5, 30.0, 0.5, "suffix:s") var seconds_until_stuck := 3.0
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var progress_speed := 1.0
@export_range(0.0, 1.0, 0.01) var steering_effort := 0.5
@export_range(-1.0, 1.0, 0.01) var capsized_upright := 0.4
@export_flags_3d_physics var land_layers := 1

var is_stuck := false

var _body: RigidBody3D
var _stuck_seconds := 0.0


func _ready() -> void:
	_body = get_parent() as RigidBody3D
	assert(_body != null, "ShipStuckDetector must be a direct child of a RigidBody3D")
	_body.contact_monitor = true
	_body.max_contacts_reported = maxi(_body.max_contacts_reported, CONTACTS_TO_REPORT)


func _physics_process(delta: float) -> void:
	if _looks_stuck():
		_stuck_seconds += delta
	else:
		_stuck_seconds = 0.0
	_set_stuck(_stuck_seconds >= seconds_until_stuck)


func reset() -> void:
	_stuck_seconds = 0.0
	_set_stuck(false)


func touching_land() -> Array[PhysicsBody3D]:
	var land: Array[PhysicsBody3D] = []
	for body in _body.get_colliding_bodies():
		if body is PhysicsBody3D and body.collision_layer & land_layers:
			land.append(body)
	return land


func is_capsized() -> bool:
	return _body.global_basis.y.dot(Vector3.UP) < capsized_upright


func _looks_stuck() -> bool:
	if is_capsized():
		return true
	return not touching_land().is_empty() and _trying_to_move() and not _making_progress()


func _trying_to_move() -> bool:
	return movement.sail_level != ShipMovement.STOPPED_LEVEL or absf(movement.rudder) >= steering_effort


func _making_progress() -> bool:
	return _body.linear_velocity.length() >= progress_speed


func _set_stuck(stuck: bool) -> void:
	if stuck == is_stuck:
		return
	is_stuck = stuck
	stuck_changed.emit(is_stuck)
