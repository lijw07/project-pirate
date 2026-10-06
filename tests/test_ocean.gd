extends SceneTree

const HEIGHT_TOLERANCE := 0.05
const SAMPLE_POINTS := [Vector2(0, 0), Vector2(37.5, -12.25), Vector2(-140.0, 88.0), Vector2(260.0, 310.0)]
const SAMPLE_TIMES := [0.0, 3.7, 41.2]
const CAMERA_STEPS := [Vector3(1000.4, 40.0, -700.6), Vector3(1013.9, 40.0, -705.2), Vector3(-37.18, 40.0, 12.94)]

var failures := 0


func _init() -> void:
	var level: Node3D = load("res://scenes/water_test_scene.tscn").instantiate()
	root.add_child(level)
	await process_frame

	var ocean: Ocean = level.get_node("Ocean")
	var camera: Camera3D = level.get_node("FreeLookCamera")
	camera.set_process(false)
	_check_setup(ocean)
	_check_wave_parameters(ocean)
	_check_heights_match_surface(ocean)
	_check_focus(ocean, camera)
	await _check_rings_stay_on_world_grid(ocean, camera)

	print("ocean test failures: ", failures)
	quit(failures)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failures += 1
	print("FAIL ", label)


func _check_setup(ocean: Ocean) -> void:
	_check(ocean.is_in_group(Ocean.GROUP), "ocean registers in its group")
	_check(ocean.height_sampler != null, "height sampler created")
	var plane_count := (2 * ocean.levels_of_detail - 1) ** 2
	_check(ocean.generated_meshes().size() == plane_count + 2, "LOD planes and far rings built")
	var scene_text := FileAccess.get_file_as_string("res://prefabs/ocean.tscn")
	_check(not scene_text.contains("ArrayMesh"), "generated meshes are not saved into the scene")


func _check_wave_parameters(ocean: Ocean) -> void:
	var water := ocean.water()
	_check(water != ocean.water_material, "runtime material is a copy")
	_check(water.get_shader_parameter("WaveCount") == ocean.wave_set.height_waves.size(), "height waves sent to shader")
	_check(is_equal_approx(water.get_shader_parameter("wave_height_sigma"), ocean.wave_set.height_sigma()), "whitecaps scaled to the wave height")
	_check(water.get_shader_parameter("whitecap_strength") == ocean.wave_set.whitecap_strength, "whitecap strength sent to shader")
	_check(water.get_shader_parameter("foam_noise") is Texture2D, "toon foam noise assigned")
	var crest := 0.0
	for wave in ocean.wave_set.height_waves:
		crest += wave.steepness
	_check(crest / ocean.wave_set.height_waves.size() > 10.0, "deep sea crests exceed ten metres")


func _check_heights_match_surface(ocean: Ocean) -> void:
	var worst := 0.0
	for time in SAMPLE_TIMES:
		ocean.wave_time = time
		for rest in SAMPLE_POINTS:
			var offset := ocean.surface_offset_at(rest)
			var surface_point := Vector2(rest.x + offset.x, rest.y + offset.z)
			worst = maxf(worst, absf(ocean.height_sampler.height_at(surface_point) - offset.y))
	print("  worst height error: %.4f m" % worst)
	_check(worst < HEIGHT_TOLERANCE, "buoyancy heights match the displaced surface")


func _check_focus(ocean: Ocean, camera: Camera3D) -> void:
	camera.global_position = Vector3(5.0, 30.0, 5.0)
	camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_check(ocean.focus_point(camera).distance_to(Vector3(5.0, 0.0, 5.0)) < 0.01, "overhead focus is below camera")
	camera.rotation_degrees = Vector3(-45.0, 0.0, 0.0)
	_check(ocean.focus_point(camera).distance_to(Vector3(5.0, 0.0, -25.0)) < 0.01, "tilted focus is where the view meets the sea")
	camera.rotation_degrees = Vector3(10.0, 0.0, 0.0)
	_check(ocean.focus_point(camera).distance_to(Vector3(5.0, 0.0, 5.0)) < 0.01, "upward view focuses below camera")


func _check_rings_stay_on_world_grid(ocean: Ocean, camera: Camera3D) -> void:
	camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var placed := ocean.global_position
	var on_grid := true
	var follows := true
	for step in CAMERA_STEPS:
		camera.global_position = step
		await process_frame
		var center := ocean.surface_center()
		on_grid = on_grid and _on_grid(center.x, ocean.snap_unit) and _on_grid(center.z, ocean.snap_unit)
		follows = follows and Vector2(center.x - step.x, center.z - step.z).length() <= ocean.snap_unit
	_check(on_grid, "moving the camera keeps every ring vertex on fixed world points")
	_check(follows, "surface follows the camera focus")
	_check(ocean.global_position == placed, "ocean node stays where the level placed it")
	_check(is_zero_approx(ocean.surface_center().y), "surface stays at sea level")


func _on_grid(value: float, spacing: float) -> bool:
	return is_zero_approx(fposmod(value + spacing * 0.5, spacing) - spacing * 0.5)
