extends SceneTree

const OCEAN := "res://prefabs/ocean.tscn"
const SHIP := "res://prefabs/filler_ship.tscn"
const DEEP_SEA := "res://resources/waves/deep_sea_waves.tres"
const MOVEMENT_SCENE := "res://scenes/ship_movement_test_scene.tscn"
const SETTLE_SECONDS := 3.0
const MAX_TURN_HEEL_DEGREES := 10.0
const MAX_AIRBORNE_SHARE := 0.02
const ROUGH_SAILING_SECONDS := 60.0

var failures := 0


func _initialize() -> void:
	await process_frame
	_check(await _reaches_top_speed(), "full sails reach top speed")
	_check(await _sails_toward_bow(), "ship sails toward its bow")
	_check(await _builds_speed_gradually(), "ship builds speed gradually")
	_check(await _coasts_to_stop(), "furled sails coast to a stop")
	_check(await _right_rudder_turns_clockwise(), "right rudder turns clockwise")
	_check(await _steering_weak_when_stopped(), "steering is weak when stopped")
	_check(await _heels_gently_in_turn(), "ship heels gently in a hard turn on calm water")
	_check(await _lowering_at_stop_reverses(), "lowering sails at a stop selects reverse")
	_check(await _reverse_backs_up(), "reverse backs the ship up")
	_check(await _reverse_steering_flips(), "right rudder in reverse swings the bow left")
	_check(await _sails_through_deep_sea(), "ship stays in the water at full speed through deep swells")
	_check(await _movement_scene_wires_player(), "movement scene wires input, camera and HUD to the ship")
	_check(await _player_actions_drive_ship(), "sail and steer actions drive the player ship")
	_check(await _rudder_follows_held_steering(), "held steering grows the rudder, release keeps it, and it snaps to centre")
	print("ship movement test failures: ", failures)
	quit(failures)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failures += 1
	print("FAIL ", label)


func _spawn_ship(waves: OceanWaveSet = OceanWaveSet.new()) -> ShipMovement:
	var world := Node3D.new()
	root.add_child(world)
	var ocean: Ocean = load(OCEAN).instantiate()
	world.add_child(ocean)
	ocean.wave_set = waves
	var ship: RigidBody3D = load(SHIP).instantiate()
	world.add_child(ship)
	await _simulate(SETTLE_SECONDS)
	return ship.get_node("ShipMovement")


func _despawn(movement: ShipMovement) -> void:
	movement.get_parent().get_parent().free()


func _simulate(seconds: float) -> void:
	for tick in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _ship(movement: ShipMovement) -> RigidBody3D:
	return movement.get_parent() as RigidBody3D


func _turned_degrees(movement: ShipMovement, start_heading: float) -> float:
	return wrapf(movement.heading_degrees() - start_heading, -180.0, 180.0)


func _reaches_top_speed() -> bool:
	var movement := await _spawn_ship()
	movement.set_sail_level(movement.highest_sail_level())
	await _simulate(30.0)
	var speed := movement.forward_speed()
	var target := movement.target_speed()
	print("  speed %.2f m/s, target %.2f m/s" % [speed, target])
	_despawn(movement)
	return absf(speed - target) < target * 0.05


func _sails_toward_bow() -> bool:
	var movement := await _spawn_ship()
	var ship := _ship(movement)
	var start := ship.global_position
	var bow := movement.forward_direction()
	movement.set_sail_level(2)
	await _simulate(15.0)
	var travel := ship.global_position - start
	print("  travelled %.1f m along the bow, %.1f m sideways" % [travel.dot(bow), absf(travel.dot(bow.cross(Vector3.UP)))])
	_despawn(movement)
	return travel.dot(bow) > 40.0 and absf(travel.dot(bow.cross(Vector3.UP))) < 2.0


func _builds_speed_gradually() -> bool:
	var movement := await _spawn_ship()
	movement.set_sail_level(movement.highest_sail_level())
	await _simulate(2.0)
	var early := movement.forward_speed()
	await _simulate(8.0)
	var later := movement.forward_speed()
	var target := movement.target_speed()
	print("  speed after 2 s %.2f m/s, after 10 s %.2f m/s" % [early, later])
	_despawn(movement)
	return early < target * 0.25 and later > target * 0.75


func _coasts_to_stop() -> bool:
	var movement := await _spawn_ship()
	movement.set_sail_level(movement.highest_sail_level())
	await _simulate(25.0)
	movement.set_sail_level(ShipMovement.STOPPED_LEVEL)
	await _simulate(5.0)
	var gliding := movement.forward_speed()
	await _simulate(30.0)
	var stopped := movement.forward_speed()
	print("  speed 5 s after furling %.2f m/s, after 35 s %.2f m/s" % [gliding, stopped])
	_despawn(movement)
	return gliding > 3.0 and absf(stopped) < 1.0


func _right_rudder_turns_clockwise() -> bool:
	var movement := await _spawn_ship()
	movement.set_sail_level(2)
	await _simulate(12.0)
	var start_heading := movement.heading_degrees()
	movement.set_rudder(1.0)
	await _simulate(6.0)
	var turned := _turned_degrees(movement, start_heading)
	print("  turned %.1f degrees" % turned)
	_despawn(movement)
	return turned > 40.0


func _steering_weak_when_stopped() -> bool:
	var movement := await _spawn_ship()
	movement.set_rudder(1.0)
	await _simulate(4.0)
	var yaw_rate := rad_to_deg(absf(_ship(movement).angular_velocity.y))
	var limit := movement.max_turn_rate_degrees * movement.minimum_steerage * 1.5
	print("  yaw rate at rest %.1f deg/s" % yaw_rate)
	_despawn(movement)
	return yaw_rate < limit


func _heels_gently_in_turn() -> bool:
	var movement := await _spawn_ship()
	var ship := _ship(movement)
	movement.set_sail_level(movement.highest_sail_level())
	await _simulate(20.0)
	movement.set_rudder(1.0)
	var steepest_heel := 0.0
	for second in 10:
		await _simulate(1.0)
		steepest_heel = maxf(steepest_heel, rad_to_deg(ship.global_basis.y.angle_to(Vector3.UP)))
	print("  steepest heel %.1f degrees" % steepest_heel)
	_despawn(movement)
	return steepest_heel > 1.0 and steepest_heel < MAX_TURN_HEEL_DEGREES


func _lowering_at_stop_reverses() -> bool:
	var movement := await _spawn_ship()
	movement.lower_sails()
	var reversing := movement.is_reversing()
	movement.lower_sails()
	var stays_lowest := movement.sail_level == ShipMovement.REVERSE_LEVEL
	_despawn(movement)
	return reversing and stays_lowest


func _reverse_backs_up() -> bool:
	var movement := await _spawn_ship()
	var ship := _ship(movement)
	var start := ship.global_position
	var bow := movement.forward_direction()
	movement.set_sail_level(ShipMovement.REVERSE_LEVEL)
	await _simulate(20.0)
	var speed := movement.forward_speed()
	var target := movement.target_speed()
	var travel := (ship.global_position - start).dot(bow)
	print("  reverse speed %.2f m/s (target %.2f), travelled %.1f m along the bow" % [speed, target, travel])
	_despawn(movement)
	return absf(speed - target) < absf(target) * 0.1 and travel < -20.0


func _reverse_steering_flips() -> bool:
	var movement := await _spawn_ship()
	movement.set_sail_level(ShipMovement.REVERSE_LEVEL)
	await _simulate(12.0)
	var start_heading := movement.heading_degrees()
	movement.set_rudder(1.0)
	await _simulate(5.0)
	var turned := _turned_degrees(movement, start_heading)
	print("  turned %.1f degrees while reversing" % turned)
	_despawn(movement)
	return turned < -5.0


func _sails_through_deep_sea() -> bool:
	var movement := await _spawn_ship(load(DEEP_SEA))
	var ship := _ship(movement)
	var target := movement.sail_speeds[movement.highest_sail_level()]
	movement.set_sail_level(movement.highest_sail_level())
	await _simulate(15.0)
	var ticks := roundi(ROUGH_SAILING_SECONDS * Engine.physics_ticks_per_second)
	var airborne_ticks := 0
	var total_speed := 0.0
	for tick in ticks:
		movement.set_rudder(1.0 if (tick / 600) % 2 == 1 else 0.0)
		await physics_frame
		total_speed += movement.forward_speed()
		if movement.buoyancy.submerged_fraction == 0.0:
			airborne_ticks += 1
	var airborne_share := float(airborne_ticks) / ticks
	var mean_speed := total_speed / ticks
	var upright := ship.global_basis.y.dot(Vector3.UP) > 0.5
	print("  airborne %.1f%% of the time, mean speed %.1f m/s of %.1f" % [airborne_share * 100.0, mean_speed, target])
	_despawn(movement)
	return airborne_share < MAX_AIRBORNE_SHARE and mean_speed > target * 0.6 and upright


func _movement_scene_wires_player() -> bool:
	var level: Node3D = load(MOVEMENT_SCENE).instantiate()
	root.add_child(level)
	var ship := level.get_node("PlayerShip") as RigidBody3D
	var movement := ship.get_node("ShipMovement") as ShipMovement
	var input := ship.get_node("PlayerInput") as ShipPlayerInput
	var camera := level.get_node("OverheadCamera") as OverheadCamera
	var hud := level.get_node("Hud/ShipDebugHud") as ShipDebugHud
	var wired := input.movement == movement and camera.target == ship and hud.movement == movement and movement.buoyancy != null
	level.free()
	return wired


func _player_actions_drive_ship() -> bool:
	var level: Node3D = load(MOVEMENT_SCENE).instantiate()
	root.add_child(level)
	var movement := level.get_node("PlayerShip/ShipMovement") as ShipMovement
	await _simulate(SETTLE_SECONDS)
	for press in 2:
		await _tap(&"sail_raise")
	await _tap(&"sail_lower")
	var raised_twice_lowered_once := movement.sail_level == 1
	Input.action_press(&"steer_right")
	await _simulate(0.5)
	var after_short_hold := movement.rudder
	await _simulate(0.5)
	var after_longer_hold := movement.rudder
	Input.action_release(&"steer_right")
	await _simulate(2.0)
	var kept := movement.rudder
	print("  rudder %.2f after 0.5 s, %.2f after 1 s, %.2f 2 s after release" % [after_short_hold, after_longer_hold, kept])
	level.free()
	return raised_twice_lowered_once and after_short_hold > 0.0 and after_longer_hold > after_short_hold and is_equal_approx(kept, after_longer_hold)


func _rudder_follows_held_steering() -> bool:
	var movement := await _spawn_ship()
	var time_to_full_lock := 1.0 / movement.rudder_turn_rate
	for tick in roundi((time_to_full_lock + 1.0) * Engine.physics_ticks_per_second):
		movement.turn_rudder(1.0, 1.0 / Engine.physics_ticks_per_second)
	var stops_at_full_lock := is_equal_approx(movement.rudder, 1.0)
	movement.settle_rudder()
	var full_lock_kept := is_equal_approx(movement.rudder, 1.0)
	movement.set_rudder(movement.rudder_center_snap * 0.5)
	movement.settle_rudder()
	var snapped_to_centre := is_zero_approx(movement.rudder)
	movement.set_rudder(-0.5)
	movement.settle_rudder()
	var half_left_kept := is_equal_approx(movement.rudder, -0.5)
	_despawn(movement)
	return stops_at_full_lock and full_lock_kept and snapped_to_centre and half_left_kept


func _tap(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
