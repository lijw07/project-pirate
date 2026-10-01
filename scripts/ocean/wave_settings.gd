@tool
class_name WaveSettings
extends Resource

const MAX_WAVES := 8
const HEIGHT_SOLVER_ITERATIONS := 4

@export var waves: Array[GerstnerWave] = []:
	set(value):
		waves = value
		emit_changed()


func active_waves() -> Array[GerstnerWave]:
	var active: Array[GerstnerWave] = []
	for wave in waves:
		if wave != null and active.size() < MAX_WAVES:
			active.append(wave)
	return active


func displacement(point: Vector2, time: float) -> Vector3:
	var total := Vector3.ZERO
	for wave in active_waves():
		total += wave.displacement(point, time)
	return total


func height_at(point: Vector2, time: float) -> float:
	return solve_height(point, displacement.bind(time))


static func solve_height(point: Vector2, offset_at: Callable) -> float:
	var source := point
	for i in HEIGHT_SOLVER_ITERATIONS:
		var offset: Vector3 = offset_at.call(source)
		source = point - Vector2(offset.x, offset.z)
	var surface: Vector3 = offset_at.call(source)
	return surface.y


func max_amplitude() -> float:
	var total := 0.0
	for wave in active_waves():
		total += wave.amplitude()
	return total


func to_shader_array() -> PackedVector4Array:
	var packed := PackedVector4Array()
	for wave in active_waves():
		packed.append(wave.to_shader_vector())
	packed.resize(MAX_WAVES)
	return packed
