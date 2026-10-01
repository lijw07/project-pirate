extends SceneTree

const ISLAND_SCENES := [
	"res://game/islands/food.tscn",
	"res://game/islands/timber.tscn",
	"res://game/islands/gold.tscn",
	"res://game/islands/metal.tscn",
	"res://game/islands/harbor_player.tscn",
	"res://game/islands/harbor_enemy.tscn",
]
const DEFAULT_WAVES := "res://game/ocean/default_waves.tres"
const SHORE_CLEARANCE := 5.0
const OPEN_SEA_DISTANCE := 150.0
const CALM_SHORE_RATIO := 0.3
const SAMPLE_TIMES := 120
const SAMPLE_STEP := 0.25

var _failures := 0


func _initialize() -> void:
	await process_frame
	for path in ISLAND_SCENES:
		check("%s calms its shore" % path.get_file().get_basename(), await calms_its_shore(path))
	print("%d failure(s)" % _failures)
	quit(_failures)


func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed:
		_failures += 1


func calms_its_shore(path: String) -> bool:
	var world := Node3D.new()
	root.add_child(world)
	var island: Node3D = load(path).instantiate()
	world.add_child(island)
	var ocean := Ocean.new()
	ocean.wave_settings = load(DEFAULT_WAVES)
	world.add_child(ocean)
	await process_frame
	await process_frame

	var bounds: AABB = island.get_meta("visual_bounds")
	var shore_distance := maxf(bounds.size.x, bounds.size.z) * 0.5 + SHORE_CLEARANCE
	var center := bounds.get_center()
	var shore := Vector3(center.x + shore_distance, 0.0, center.z)
	var open_sea := Vector3(center.x + OPEN_SEA_DISTANCE, 0.0, center.z)
	var shore_swing := highest_wave(ocean, shore)
	var open_swing := highest_wave(ocean, open_sea)
	print("    shore %.2f m, open sea %.2f m" % [shore_swing, open_swing])
	world.queue_free()
	return island.has_node("CalmZone") and shore_swing < open_swing * CALM_SHORE_RATIO


func highest_wave(ocean: Ocean, point: Vector3) -> float:
	var highest := 0.0
	for step in SAMPLE_TIMES:
		ocean.time = step * SAMPLE_STEP
		highest = maxf(highest, absf(ocean.height_at(point)))
	return highest
