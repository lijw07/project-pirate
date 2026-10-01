class_name MinimapMarker
extends Node3D

const GROUP := &"minimap_markers"

@export var texture: Texture2D
@export_range(0.0, 1000.0, 0.5, "suffix:m") var world_size := 0.0
@export_range(1.0, 256.0, 1.0, "suffix:px") var screen_size := 24.0
@export var layer := 0
@export var rotates_with_heading := false
@export var local_forward := Vector3.BACK
@export var pinned_to_edge := false
@export var screen_offset := Vector2.ZERO
@export var tint := Color.WHITE


func _enter_tree() -> void:
	add_to_group(GROUP)


func map_position() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func map_heading() -> float:
	var forward := global_basis * local_forward
	return atan2(forward.x, -forward.z)


func size_on_map(pixels_per_meter: float) -> Vector2:
	var longest_side := world_size * pixels_per_meter if world_size > 0.0 else screen_size
	var texture_size := texture.get_size()
	return texture_size * (longest_side / maxf(texture_size.x, texture_size.y))
