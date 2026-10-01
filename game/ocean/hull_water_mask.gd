@tool
class_name HullWaterMask
extends Node3D

const GROUP := &"ocean_hull_masks"

@export_range(0.1, 50.0, 0.05, "suffix:m") var half_width := 1.7
@export_range(0.1, 100.0, 0.05, "suffix:m") var half_length := 4.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func to_shader_frame() -> Vector4:
	var heading := Vector2(global_basis.z.x, global_basis.z.z)
	heading = heading.normalized() if heading.length_squared() > 0.0001 else Vector2.DOWN
	return Vector4(global_position.x, global_position.z, heading.x, heading.y)


func to_shader_size() -> Vector4:
	return Vector4(half_width, half_length, 0.0, 0.0)
