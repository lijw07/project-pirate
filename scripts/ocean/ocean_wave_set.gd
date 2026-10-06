@tool
class_name OceanWaveSet
extends Resource

const MAX_SHADER_WAVES := 8

@export var height_waves: Array[GerstnerWave] = []
@export var uv_waves: Array[GerstnerWave] = []
@export_range(0.0, 2.0, 0.05) var whitecap_strength := 1.0


func displacement_at(rest_position: Vector2, time: float) -> Vector3:
	var active := shader_waves(height_waves)
	if active.is_empty():
		return Vector3.ZERO
	var total := Vector3.ZERO
	for wave in active:
		total += wave.offset_at(rest_position, time)
	return total / active.size()


func height_sigma() -> float:
	var active := shader_waves(height_waves)
	if active.is_empty():
		return 0.0
	var variance := 0.0
	for wave in active:
		variance += wave.steepness * wave.steepness / 2.0
	return sqrt(variance) / active.size()


func shader_waves(waves: Array[GerstnerWave]) -> Array[GerstnerWave]:
	var active: Array[GerstnerWave] = []
	for wave in waves.slice(0, MAX_SHADER_WAVES):
		if wave:
			active.append(wave)
	return active
