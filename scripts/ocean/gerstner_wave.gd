@tool
class_name GerstnerWave
extends Resource

const GRAVITY := 9.81

@export var direction := Vector2.RIGHT:
	set(value):
		direction = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var steepness := 0.1:
	set(value):
		steepness = value
		emit_changed()
@export_range(1.0, 500.0, 0.1, "suffix:m") var wavelength := 20.0:
	set(value):
		wavelength = value
		emit_changed()


func wave_number() -> float:
	return TAU / wavelength


func phase_speed() -> float:
	return sqrt(GRAVITY / wave_number())


func amplitude() -> float:
	return steepness / wave_number()


func heading() -> Vector2:
	return direction.normalized()


func displacement(point: Vector2, time: float) -> Vector3:
	var k := wave_number()
	var d := heading()
	var phase := k * (d.dot(point) - phase_speed() * time)
	var a := amplitude()
	var horizontal := d * a * cos(phase)
	return Vector3(horizontal.x, a * sin(phase), horizontal.y)


func to_shader_vector() -> Vector4:
	var d := heading()
	return Vector4(d.x, d.y, steepness, wavelength)
