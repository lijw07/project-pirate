extends SceneTree

const SETTLE_PHYSICS_FRAMES := 600
const FLAT_SEA_TOLERANCE := 0.1
const LEVEL_TOLERANCE := 0.99
const SWELL_PHYSICS_FRAMES := 1800
const SEATED_MIN_RATIO := 0.8
const SEATED_MAX_RATIO := 1.3
const RIDING_HIGH_RATIO := 0.5
const MAX_RIDING_HIGH_SHARE := 0.02

var failures := 0


func _init() -> void:
	_check_slot_allocation()
	_check_water_pose()
	await _check_ship_floats()
	await _check_ship_stays_seated_in_swell()
	print("buoyancy test failures: ", failures)
	quit(failures)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failures += 1
	print("FAIL ", label)


func _check_slot_allocation() -> void:
	var sampler := OceanHeightSampler.new()
	var first := sampler.allocate(6)
	var second := sampler.allocate(6)
	_check(first == 0 and second == 6, "allocations get separate slot ranges")
	sampler.release(first, 6)
	_check(sampler.allocate(4) == 0, "released slots are reused")
	_check(sampler.allocate(OceanHeightSampler.CAPACITY) == OceanHeightSampler.NO_SLOT, "oversized allocation is refused")
	_check(is_zero_approx(sampler.height(second)), "height is zero before any readback")
	sampler.free()


func _check_water_pose() -> void:
	var points := PackedVector3Array([Vector3(-1, 0, -3), Vector3(1, 0, -3), Vector3(-1, 0, 3), Vector3(1, 0, 3)])
	var level := Buoyancy.water_pose(points, PackedFloat32Array([0.5, 0.5, 0.5, 0.5]))
	_check(level.origin.is_equal_approx(Vector3.UP * 0.5) and level.basis.is_equal_approx(Basis.IDENTITY), "even water lifts the preview straight up")
	var listing := Buoyancy.water_pose(points, PackedFloat32Array([-0.1, 0.1, -0.1, 0.1]))
	_check(absf((listing * Vector3(1, 0, 0)).y - 0.1) < 0.01, "sloped water rolls the preview")
	var pitching := Buoyancy.water_pose(points, PackedFloat32Array([-0.3, -0.3, 0.3, 0.3]))
	_check(absf((pitching * Vector3(0, 0, 3)).y - 0.3) < 0.02, "sloped water pitches the preview")


func _check_ship_floats() -> void:
	var level: Node3D = load("res://scenes/gym_test_scene.tscn").instantiate()
	root.add_child(level)
	var ship: RigidBody3D = level.get_node("FillerShip")
	var buoyancy: Buoyancy = ship.get_node("Buoyancy")
	var ocean: Ocean = level.get_node("Ocean")
	ocean.wave_set = OceanWaveSet.new()
	for frame in SETTLE_PHYSICS_FRAMES:
		await physics_frame
	_check(ocean.is_in_group(Ocean.GROUP), "ocean registers in its group")
	_check(is_equal_approx(buoyancy.submerged_fraction, 1.0), "every probe is submerged at rest")
	_check(absf(ship.global_position.y + buoyancy.draft) < FLAT_SEA_TOLERANCE, "ship settles one draft below flat sea level")
	_check(ship.global_transform.basis.y.dot(Vector3.UP) > LEVEL_TOLERANCE, "ship stays upright")
	_check(ship.linear_velocity.length() < FLAT_SEA_TOLERANCE, "ship comes to rest")
	level.free()


func _check_ship_stays_seated_in_swell() -> void:
	var level: Node3D = load("res://scenes/gym_test_scene.tscn").instantiate()
	root.add_child(level)
	var ship: RigidBody3D = level.get_node("FillerShip")
	var buoyancy: Buoyancy = ship.get_node("Buoyancy")
	var ocean: Ocean = level.get_node("Ocean")
	ocean.wave_set = load("res://resources/waves/deep_sea_waves.tres")
	for frame in SETTLE_PHYSICS_FRAMES:
		await physics_frame
	var ratios := PackedFloat32Array()
	for frame in SWELL_PHYSICS_FRAMES:
		await physics_frame
		ratios.append(_immersion_ratio(ocean, buoyancy))
	ratios.sort()
	var median := ratios[ratios.size() / 2]
	var riding_high := ratios.bsearch(RIDING_HIGH_RATIO) / float(ratios.size())
	print("  swell immersion median %.2f drafts, riding high %.1f%%" % [median, riding_high * 100.0])
	_check(median > SEATED_MIN_RATIO and median < SEATED_MAX_RATIO, "ship sits at its draft through deep swells")
	_check(riding_high < MAX_RIDING_HIGH_SHARE, "ship rarely rides above the water on crests")
	level.free()


func _immersion_ratio(ocean: Ocean, buoyancy: Buoyancy) -> float:
	var immersion := 0.0
	var probes := buoyancy.get_children()
	for probe: Marker3D in probes:
		var point := probe.global_position
		immersion += ocean.height_sampler.height_at(Vector2(point.x, point.z)) - point.y
	return immersion / probes.size() / buoyancy.draft
