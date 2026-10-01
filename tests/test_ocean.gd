extends SceneTree

const SETTLE_SECONDS := 6.0
const FILLER_SHIP := "res://game/ships/filler_ship.tscn"
const DEFAULT_WAVES := "res://game/ocean/default_waves.tres"
const DECK_HEIGHT_ABOVE_ORIGIN := 1.4
const MIN_FREEBOARD := 0.6

var _failures := 0


func _initialize() -> void:
	await process_frame
	check("height sample matches displaced surface", height_matches_displaced_surface())
	check("calm sea is flat", calm_sea_is_flat())
	check("ocean mesh spans extent", ocean_mesh_spans_extent())
	check("shader array is padded to max waves", shader_array_is_padded())
	check("calm zone flattens waves at its center", calm_zone_flattens_center())
	check("calm zone leaves open sea untouched", calm_zone_leaves_open_sea())
	check("hull mask frame follows ship heading", hull_mask_follows_heading())
	check("filler ship floats upright on calm sea", await ship_floats_upright(WaveSettings.new()))
	check("filler ship stays afloat in default waves", await ship_floats_upright(load(DEFAULT_WAVES)))
	print("%d failure(s)" % _failures)
	quit(_failures)


func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed:
		_failures += 1


func height_matches_displaced_surface() -> bool:
	var settings: WaveSettings = load(DEFAULT_WAVES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 200:
		var grid_point := Vector2(rng.randf_range(-500.0, 500.0), rng.randf_range(-500.0, 500.0))
		var time := rng.randf_range(0.0, 120.0)
		var offset := settings.displacement(grid_point, time)
		var surface_point := grid_point + Vector2(offset.x, offset.z)
		if absf(settings.height_at(surface_point, time) - offset.y) > 0.02:
			return false
	return true


func calm_sea_is_flat() -> bool:
	return is_zero_approx(WaveSettings.new().height_at(Vector2(12.0, -40.0), 3.0))


func ocean_mesh_spans_extent() -> bool:
	var mesh := OceanMeshBuilder.build(100.0, 10, 0.1)
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var bounds := mesh.get_aabb()
	var footprint := Vector2(bounds.size.x, bounds.size.z)
	return vertices.size() == 121 and footprint.is_equal_approx(Vector2(200.0, 200.0))


func shader_array_is_padded() -> bool:
	var settings: WaveSettings = load(DEFAULT_WAVES)
	return settings.to_shader_array().size() == WaveSettings.MAX_WAVES


func calm_zone_flattens_center() -> bool:
	var zone := CalmZone.new()
	zone.inner_radius = 10.0
	zone.outer_radius = 30.0
	root.add_child(zone)
	var scale := zone.wave_scale_at(Vector2(3.0, 0.0), 0.15)
	zone.free()
	return is_equal_approx(scale, 0.15)


func calm_zone_leaves_open_sea() -> bool:
	var zone := CalmZone.new()
	zone.inner_radius = 10.0
	zone.outer_radius = 30.0
	root.add_child(zone)
	var scale := zone.wave_scale_at(Vector2(0.0, 31.0), 0.15)
	zone.free()
	return is_equal_approx(scale, 1.0)


func hull_mask_follows_heading() -> bool:
	var mask := HullWaterMask.new()
	root.add_child(mask)
	mask.global_position = Vector3(5.0, 0.0, -2.0)
	mask.rotation.y = PI * 0.5
	var frame := mask.to_shader_frame()
	mask.free()
	return frame.is_equal_approx(Vector4(5.0, -2.0, 1.0, 0.0))


func ship_floats_upright(settings: WaveSettings) -> bool:
	var world := Node3D.new()
	root.add_child(world)
	var ocean := Ocean.new()
	ocean.wave_settings = settings
	world.add_child(ocean)
	var ship: RigidBody3D = load(FILLER_SHIP).instantiate()
	ship.position = Vector3(0.0, 2.0, 0.0)
	world.add_child(ship)

	var elapsed := 0.0
	while elapsed < SETTLE_SECONDS:
		await physics_frame
		elapsed += 1.0 / Engine.physics_ticks_per_second

	var deck_height := ship.to_global(Vector3(0.0, DECK_HEIGHT_ABOVE_ORIGIN, 0.0)).y
	var freeboard := deck_height - ocean.height_at(ship.global_position)
	var upright := ship.global_basis.y.dot(Vector3.UP)
	print("    deck %.2f m above water, upright %.3f" % [freeboard, upright])
	world.queue_free()
	return freeboard > MIN_FREEBOARD and upright > 0.9
