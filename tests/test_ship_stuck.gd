extends SceneTree

const PLAYER_SHIP := "res://game/ships/ship_corsair.tscn"
const WALL_DISTANCE := 30.0
const WALL_SIZE := Vector3(80.0, 12.0, 4.0)

var _failures := 0


func _initialize() -> void:
	await process_frame
	check("open water sailing is never stuck", await open_water_is_never_stuck())
	check("pushing into land gets stuck", await pushing_into_land_gets_stuck())
	check("stopping against land clears stuck", await stopping_clears_stuck())
	check("rescue ignores a ship that is not stuck", await rescue_ignores_free_ship())
	check("rescue frees a stuck ship into open water facing away", await rescue_frees_stuck_ship())
	print("%d failure(s)" % _failures)
	quit(_failures)


func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed:
		_failures += 1


func simulate(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func spawn(with_wall: bool) -> ShipRescue:
	var world := Node3D.new()
	root.add_child(world)
	var ocean := Ocean.new()
	ocean.wave_settings = WaveSettings.new()
	world.add_child(ocean)
	var ship: RigidBody3D = load(PLAYER_SHIP).instantiate()
	world.add_child(ship)
	var movement := ShipMovement.new()
	movement.buoyancy = ship.get_node("Buoyancy")
	ship.add_child(movement)
	var detector := ShipStuckDetector.new()
	detector.movement = movement
	ship.add_child(detector)
	var rescue := ShipRescue.new()
	rescue.movement = movement
	rescue.stuck_detector = detector
	ship.add_child(rescue)
	if with_wall:
		world.add_child(build_wall(movement.forward_direction() * WALL_DISTANCE))
	await simulate(2.0)
	return rescue


func build_wall(center: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = WALL_SIZE
	shape.shape = box
	wall.add_child(shape)
	wall.position = center
	return wall


func despawn(rescue: ShipRescue) -> void:
	rescue.get_parent().get_parent().queue_free()


func open_water_is_never_stuck() -> bool:
	var rescue := await spawn(false)
	rescue.movement.set_sail_level(rescue.movement.highest_sail_level())
	await simulate(10.0)
	var stuck := rescue.stuck_detector.is_stuck
	despawn(rescue)
	return not stuck


func pushing_into_land_gets_stuck() -> bool:
	var rescue := await spawn(true)
	rescue.movement.set_sail_level(rescue.movement.highest_sail_level())
	await simulate(12.0)
	var stuck := rescue.stuck_detector.is_stuck
	despawn(rescue)
	return stuck


func stopping_clears_stuck() -> bool:
	var rescue := await spawn(true)
	rescue.movement.set_sail_level(rescue.movement.highest_sail_level())
	await simulate(12.0)
	rescue.movement.halt()
	await simulate(1.0)
	var stuck := rescue.stuck_detector.is_stuck
	despawn(rescue)
	return not stuck


func rescue_ignores_free_ship() -> bool:
	var rescue := await spawn(false)
	var start := (rescue.get_parent() as Node3D).global_position
	var acted := rescue.rescue_if_stuck()
	var moved := (rescue.get_parent() as Node3D).global_position.distance_to(start) > 1.0
	despawn(rescue)
	return not acted and not moved


func rescue_frees_stuck_ship() -> bool:
	var rescue := await spawn(true)
	var ship := rescue.get_parent() as RigidBody3D
	var toward_wall := rescue.movement.forward_direction()
	rescue.movement.set_sail_level(rescue.movement.highest_sail_level())
	await simulate(12.0)
	var stuck_position := ship.global_position
	var rescued := rescue.rescue_if_stuck()
	await simulate(2.0)
	var moved := ship.global_position.distance_to(stuck_position)
	var facing_away := rescue.movement.forward_direction().dot(-toward_wall)
	var clear := rescue.stuck_detector.touching_land().is_empty()
	var halted := rescue.movement.sail_level == ShipMovement.STOPPED_LEVEL
	print("    rescued %s, moved %.1f m, facing away %.2f, clear of land %s, halted %s" % [rescued, moved, facing_away, clear, halted])
	despawn(rescue)
	return rescued and moved > 10.0 and facing_away > 0.7 and clear and halted
