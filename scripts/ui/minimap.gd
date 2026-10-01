class_name Minimap
extends Control

@export var focus: Node3D
@export_range(10.0, 2000.0, 1.0, "suffix:m") var view_radius := 175.0
@export var water_texture: Texture2D
@export_range(1.0, 500.0, 0.5, "suffix:m") var water_tile_meters := 20.0
@export_range(0.0, 64.0, 1.0, "suffix:px") var edge_margin := 16.0

@onready var _canvas: Control = $Mask/Canvas


func _ready() -> void:
	_canvas.draw.connect(_draw_map)


func _process(_delta: float) -> void:
	_canvas.queue_redraw()


func map_radius() -> float:
	return minf(size.x, size.y) * 0.5


func pixels_per_meter() -> float:
	return map_radius() / view_radius


func world_to_map(world_point: Vector2) -> Vector2:
	return size * 0.5 + (world_point - focus_point()) * pixels_per_meter()


func pin_inside(map_point: Vector2) -> Vector2:
	var limit := maxf(map_radius() - edge_margin, 0.0)
	return size * 0.5 + (map_point - size * 0.5).limit_length(limit)


func focus_point() -> Vector2:
	if focus == null:
		return Vector2.ZERO
	return Vector2(focus.global_position.x, focus.global_position.z)


func _draw_map() -> void:
	_draw_water()
	for marker in _markers_in_layer_order():
		_draw_marker(marker)


func _draw_water() -> void:
	if water_texture == null:
		return
	var meters_shown := size / pixels_per_meter()
	var texels_per_meter := water_texture.get_size() / water_tile_meters
	var top_left := focus_point() - meters_shown * 0.5
	var source := Rect2(top_left * texels_per_meter, meters_shown * texels_per_meter)
	_canvas.draw_texture_rect_region(water_texture, Rect2(Vector2.ZERO, size), source)


func _markers_in_layer_order() -> Array[MinimapMarker]:
	var markers: Array[MinimapMarker] = []
	markers.assign(get_tree().get_nodes_in_group(MinimapMarker.GROUP))
	markers.sort_custom(func(a: MinimapMarker, b: MinimapMarker) -> bool: return a.layer < b.layer)
	return markers


func _draw_marker(marker: MinimapMarker) -> void:
	if marker.texture == null or not marker.is_visible_in_tree():
		return
	var point := world_to_map(marker.map_position())
	if marker.pinned_to_edge:
		point = pin_inside(point)
	var extent := marker.size_on_map(pixels_per_meter())
	if not _overlaps_map(point, extent):
		return
	var heading := marker.map_heading() if marker.rotates_with_heading else 0.0
	_canvas.draw_set_transform(point + marker.screen_offset, heading)
	_canvas.draw_texture_rect(marker.texture, Rect2(-extent * 0.5, extent), false, marker.tint)
	_canvas.draw_set_transform(Vector2.ZERO)


func _overlaps_map(point: Vector2, extent: Vector2) -> bool:
	return point.distance_to(size * 0.5) - extent.length() * 0.5 < map_radius()
