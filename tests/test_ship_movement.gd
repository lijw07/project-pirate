extends SceneTree

const PLAYER_SHIP := "res://game/ships/ship_corsair.tscn"
const DEFAULT_WAVES := "res://game/ocean/default_waves.tres"
const MAX_TURN_HEEL_DEGREES := 10.0
const MAX_AIRBORNE_SHARE := 0.02
const MAX_RISE_SPEED := 3.0
const ROUGH_SAILING_SECONDS := 60.0

var _failures := 0


func _initialize() -> void:
	await process_frame
	check("full sails reach top speed", await reaches_top_speed())
	check("ship sails toward its bow", await sails_toward_bow())
	check("furled sails coast to a stop", await coasts_to_stop())
	check("right rudder turns clockwise", await right_rudder_turns_clockwise())
	check("steering is weak when stopped", await steering_weak_when_stopped())
	check("ship heels gently in a hard turn on calm water", await heels_gently_in_turn())
	check("lowering sails at a stop selects reverse", await lowering_at_stop_reverses())
	check("reverse backs the ship up", await reverse_backs_up())
	check("right rudder in reverse swings the bow left", await reverse_steering_flips())
	check("ship stays in the water at full speed through waves", await stays_in_water_at_full_speed())
	print("%d failure(s)" % _failures)
	quit(_failures)


func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed:
		_failures += 1


func spawn_ship(waves: WaveSettings = load(DEFAULT_WAVES)) -> ShipMovement:
	var world := Node3D.new()
	world.name = "World"
	root.add_child(world)
	var ocean := Ocean.new()
	ocean.wave_settings = waves
	world.add_child(ocean)
	var ship: RigidBody3D = load(PLAYER_SHIP).instantiate()
	world.add_child(ship)
	var movement := ShipMovement.new()
	movement.buoyancy = ship.get_node("Buoyancy")
	ship.add_child(movement)
	await simulate(3.0)
	return movement


func despawn(movement: ShipMovement) -> void:
	movement.get_parent().get_parent().queue_free()


func simulate(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func reaches_top_speed() -> bool:
	var movement := await spawn_ship()
	movement.set_sail_level(movement.sail_speeds.size() - 1)
	await simulate(30.0)
	var speed := movement.forward_speed()
	var target := movement.target_speed()
	print("    speed %.2f m/s, target %.2f m/s" % [speed, target])
	despawn(movement)
	return absf(speed - target) < target * 0.1


func sails_toward_bow() -> bool:
	var movement := await spawn_ship()
	var ship := movement.get_parent() as RigidBody3D
	var start := ship.global_position
	var bow := ship.global_basis * movement.local_bow_direction
	movement.set_sail_level(2)
	await simulate(10.0)
	var travel := ship.global_position - start
	print("    travelled %.1f m along bow" % travel.dot(bow))
	despawn(movement)
	return travel.dot(bow) > 20.0


func coasts_to_stop() -> bool:
	var movement := await spawn_ship()
	movement.set_sail_level(movement.sail_speeds.size() - 1)
	await simulate(20.0)
	movement.set_sail_level(0)
	await simulate(30.0)
	var speed := movement.forward_speed()
	print("    speed after coasting %.2f m/s" % speed)
	despawn(movement)
	return absf(speed) < 1.0


func right_rudder_turns_clockwise() -> bool:
	var movement := await spawn_ship()
	movement.set_sail_level(2)
	await simulate(8.0)
	var start_heading := movement.heading_degrees()
	movement.steer(1.0)
	await simulate(6.0)
	var turned := wrapf(movement.heading_degrees() - start_heading, -180.0, 180.0)
	print("    turned %.1f degrees" % turned)
	despawn(movement)
	return turned > 40.0


func steering_weak_when_stopped() -> bool:
	var movement := await spawn_ship()
	movement.steer(1.0)
	await simulate(4.0)
	var yaw_rate := rad_to_deg(absf((movement.get_parent() as RigidBody3D).angular_velocity.y))
	var limit := movement.max_turn_rate_degrees * movement.minimum_steerage * 1.5
	print("    yaw rate at rest %.1f deg/s" % yaw_rate)
	despawn(movement)
	return yaw_rate < limit


func heels_gently_in_turn() -> bool:
	var movement := await spawn_ship(WaveSettings.new())
	var ship := movement.get_parent() as RigidBody3D
	movement.set_sail_level(movement.sail_speeds.size() - 1)
	await simulate(15.0)
	movement.steer(1.0)
	var steepest_heel := 0.0
	for i in 10:
		await simulate(1.0)
		steepest_heel = maxf(steepest_heel, rad_to_deg(acos(clampf(ship.global_basis.y.dot(Vector3.UP), -1.0, 1.0))))
	print("    steepest heel %.1f degrees" % steepest_heel)
	despawn(movement)
	return steepest_heel > 1.0 and steepest_heel < MAX_TURN_HEEL_DEGREES


func lowering_at_stop_reverses() -> bool:
	var movement := await spawn_ship()
	movement.lower_sails()
	var reversing := movement.is_reversing()
	despawn(movement)
	return reversing


func reverse_backs_up() -> bool:
	var movement := await spawn_ship()
	var ship := movement.get_parent() as RigidBody3D
	var start := ship.global_position
	var bow := movement.forward_direction()
	movement.set_sail_level(ShipMovement.REVERSE_LEVEL)
	await simulate(15.0)
	var speed := movement.forward_speed()
	var target := movement.target_speed()
	var travel := (ship.global_position - start).dot(bow)
	print("    reverse speed %.2f m/s (target %.2f), travelled %.1f m along bow" % [speed, target, travel])
	despawn(movement)
	return absf(speed - target) < absf(target) * 0.15 and travel < -20.0


func reverse_steering_flips() -> bool:
	var movement := await spawn_ship()
	movement.set_sail_level(ShipMovement.REVERSE_LEVEL)
	await simulate(8.0)
	var start_heading := movement.heading_degrees()
	movement.steer(1.0)
	await simulate(5.0)
	var turned := wrapf(movement.heading_degrees() - start_heading, -180.0, 180.0)
	print("    turned %.1f degrees while reversing" % turned)
	despawn(movement)
	return turned < -5.0


func stays_in_water_at_full_speed() -> bool:
	var movement := await spawn_ship()
	var ship := movement.get_parent() as RigidBody3D
	var buoyancy := movement.buoyancy
	movement.set_sail_level(movement.highest_sail_level())
	var ticks := roundi(ROUGH_SAILING_SECONDS * Engine.physics_ticks_per_second)
	var airborne_ticks := 0
	var fastest_rise := 0.0
	for tick in ticks:
		movement.steer(1.0 if (tick / 600) % 2 == 1 else 0.0)
		await physics_frame
		fastest_rise = maxf(fastest_rise, ship.linear_velocity.y)
		if buoyancy.submerged_fraction == 0.0:
			airborne_ticks += 1
	var airborne_share := float(airborne_ticks) / ticks
	print("    airborne %.1f%% of the time, fastest rise %.1f m/s" % [airborne_share * 100.0, fastest_rise])
	despawn(movement)
	return airborne_share < MAX_AIRBORNE_SHARE and fastest_rise < MAX_RISE_SPEED
