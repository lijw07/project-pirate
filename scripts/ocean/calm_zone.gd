@tool
class_name CalmZone
extends Node3D

const GROUP := &"ocean_calm_zones"

@export_range(0.0, 500.0, 0.5, "suffix:m") var inner_radius := 18.0
@export_range(0.0, 1000.0, 0.5, "suffix:m") var outer_radius := 45.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func wave_scale_at(point: Vector2, residual: float) -> float:
	var distance := point.distance_to(center())
	var blend := smoothstep(inner_radius, maxf(outer_radius, inner_radius + 0.01), distance)
	return lerpf(residual, 1.0, blend)


func center() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func to_shader_vector() -> Vector4:
	var origin := center()
	return Vector4(origin.x, origin.y, inner_radius, maxf(outer_radius, inner_radius + 0.01))
