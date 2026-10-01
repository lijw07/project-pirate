extends SceneTree

const MINIMAP_SCENE := preload("res://game/ui/minimap/minimap.tscn")
const SHIP_MARKER_SCENE := preload("res://game/ui/minimap/markers/player_ship.tscn")
const HARBOR_MARKER_SCENE := preload("res://game/ui/minimap/markers/enemy_harbor.tscn")

var _failures := 0


func _initialize() -> void:
	await process_frame
	check("focus sits in the center of the map", await focus_sits_in_center())
	check("north is up and east is right", await north_is_up_east_is_right())
	check("view radius reaches the rim", await view_radius_reaches_rim())
	check("ship marker points along the bow", await ship_marker_points_along_bow())
	check("pinned markers stay inside the rim", await pinned_markers_stay_inside())
	check("world sized markers scale with the map", await world_sized_markers_scale())
	check("every marker joins the minimap group", await markers_join_group())
	print("%d failure(s)" % _failures)
	quit(_failures)


func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed:
		_failures += 1


func spawn_minimap(focus_position: Vector3) -> Minimap:
	var focus := Node3D.new()
	root.add_child(focus)
	focus.global_position = focus_position
	var minimap: Minimap = MINIMAP_SCENE.instantiate()
	minimap.focus = focus
	root.add_child(minimap)
	await process_frame
	return minimap


func despawn(minimap: Minimap) -> void:
	minimap.focus.free()
	minimap.free()


func focus_sits_in_center() -> bool:
	var minimap := await spawn_minimap(Vector3(40.0, 3.0, -25.0))
	var point := minimap.world_to_map(Vector2(40.0, -25.0))
	var centered := point.is_equal_approx(minimap.size * 0.5)
	despawn(minimap)
	return centered


func north_is_up_east_is_right() -> bool:
	var minimap := await spawn_minimap(Vector3.ZERO)
	var center := minimap.size * 0.5
	var north := minimap.world_to_map(Vector2(0.0, -50.0)) - center
	var east := minimap.world_to_map(Vector2(50.0, 0.0)) - center
	var oriented := north.y < 0.0 and is_zero_approx(north.x) and east.x > 0.0 and is_zero_approx(east.y)
	despawn(minimap)
	return oriented


func view_radius_reaches_rim() -> bool:
	var minimap := await spawn_minimap(Vector3.ZERO)
	var edge := minimap.world_to_map(Vector2(minimap.view_radius, 0.0))
	var reaches := is_equal_approx(edge.x - minimap.size.x * 0.5, minimap.map_radius())
	despawn(minimap)
	return reaches


func ship_marker_points_along_bow() -> bool:
	var marker: MinimapMarker = SHIP_MARKER_SCENE.instantiate()
	root.add_child(marker)
	var headings := {}
	for yaw_degrees in [0.0, 90.0, 180.0, -90.0]:
		marker.rotation = Vector3(0.0, deg_to_rad(yaw_degrees), 0.0)
		var bow := marker.global_basis * marker.local_forward
		var drawn_bow := Vector2.UP.rotated(marker.map_heading())
		headings[yaw_degrees] = drawn_bow.is_equal_approx(Vector2(bow.x, bow.z))
	marker.free()
	return headings.values().all(func(matches: bool) -> bool: return matches)


func pinned_markers_stay_inside() -> bool:
	var minimap := await spawn_minimap(Vector3.ZERO)
	var far_away := minimap.world_to_map(Vector2(-70.0, -2000.0))
	var pinned := minimap.pin_inside(far_away)
	var inside := pinned.distance_to(minimap.size * 0.5) <= minimap.map_radius() - minimap.edge_margin + 0.01
	var same_direction := (pinned - minimap.size * 0.5).normalized().is_equal_approx((far_away - minimap.size * 0.5).normalized())
	var nearby := minimap.world_to_map(Vector2(10.0, 10.0))
	var untouched := minimap.pin_inside(nearby).is_equal_approx(nearby)
	despawn(minimap)
	return inside and same_direction and untouched


func world_sized_markers_scale() -> bool:
	var harbor: Node3D = HARBOR_MARKER_SCENE.instantiate()
	root.add_child(harbor)
	var island: MinimapMarker = harbor.get_node("Island")
	var badge: MinimapMarker = harbor.get_node("Faction")
	var island_grows := island.size_on_map(2.0).x > island.size_on_map(1.0).x
	var badge_fixed := badge.size_on_map(2.0).is_equal_approx(badge.size_on_map(1.0))
	var island_matches_meters := is_equal_approx(island.size_on_map(1.0).x, island.world_size)
	harbor.free()
	return island_grows and badge_fixed and island_matches_meters


func markers_join_group() -> bool:
	var harbor: Node3D = HARBOR_MARKER_SCENE.instantiate()
	root.add_child(harbor)
	var count := get_nodes_in_group(MinimapMarker.GROUP).size()
	harbor.free()
	return count == 3
