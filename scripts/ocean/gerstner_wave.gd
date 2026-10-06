@tool
class_name GerstnerWave
extends Resource

@export var steepness := 1.0:
	set(value):
		steepness = value
		emit_changed()
@export var amplitude := 1.0:
	set(value):
		amplitude = value
		emit_changed()
@export_range(0, 360) var direction_degrees := 0.0:
	set(value):
		direction_degrees = value
		emit_changed()
@export var frequency := 0.1:
	set(value):
		frequency = value
		emit_changed()
@export var speed := 1.0:
	set(value):
		speed = value
		emit_changed()
@export_range(-360, 360) var phase_degrees := 0.0:
	set(value):
		phase_degrees = value
		emit_changed()


func offset_at(rest_position: Vector2, time: float) -> Vector3:
	var direction := Vector2(sin(deg_to_rad(direction_degrees)), cos(deg_to_rad(direction_degrees)))
	var angle := TAU * (frequency * direction).dot(rest_position) + speed * (time + deg_to_rad(phase_degrees))
	var horizontal := steepness * amplitude * cos(angle)
	return Vector3(horizontal * direction.x, steepness * sin(angle), horizontal * direction.y)
