extends SceneTree

const PLAYER_SHIP := "res://game/ships/ship_corsair.tscn"
const SHIP_SCENES := [
	"res://game/ships/ship_corsair.tscn",
	"res://game/ships/ship_scout.tscn",
	"res://game/ships/ship_trader.tscn",
	"res://game/ships/ship_warship.tscn",
]
const DEFAULT_WAVES := "res://game/ocean/default_waves.tres"
const OCEAN_MATERIAL := "res://game/ocean/ocean_material.tres"
const SAILING_LEVEL := 2

var _failures := 0


func _initialize() -> void:
	await process_frame
	for path in SHIP_SCENES:
		check("%s has a wake emitter ahead of its hull" % path.get_file().get_basename(), emitter_sits_at_bow(path))
	check("a sailing ship leaves a trail behind its bow", await leaves_trail())
	check("the ocean draws the wake of a sailing ship", await ocean_receives_wake())
	check("the hull mask reports ship speed for bow foam", await hull_mask_reports_speed())
	check("a turning ship's trail bends in small steps", await turning_trail_bends_smoothly())
	check("a stopped ship's wake fades away", await wake_fades_after_stopping())
	check("a teleported ship breaks its trail", await teleport_breaks_trail())
	check("many ships never overflow the wake buffer", await wake_buffer_is_capped())
	print("%d failure(s)" % _failures)
	quit(_failures)


func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed:
		_failures += 1


func emitter_sits_at_bow(path: String) -> bool:
	var ship: Node3D = load(path).instantiate()
	var wake := ship.get_node_or_null("WakeEmitter") as WakeEmitter
	var mask := ship.get_node("HullWaterMask") as HullWaterMask
	var at_bow := wake != null and wake.position.z > mask.position.z + mask.half_length * 0.5
	ship.free()
	return at_bow


func spawn_world() -> Ocean:
	var world := Node3D.new()
	root.add_child(world)
	var ocean := Ocean.new()
	ocean.wave_settings = load(DEFAULT_WAVES)
	ocean.material = (load(OCEAN_MATERIAL) as ShaderMaterial).duplicate()
	world.add_child(ocean)
	return ocean


func spawn_ship(ocean: Ocean, offset := Vector3.ZERO) -> ShipMovement:
	var ship: RigidBody3D = load(PLAYER_SHIP).instantiate()
	ship.position = offset
	ocean.get_parent().add_child(ship)
	var movement := ShipMovement.new()
	movement.buoyancy = ship.get_node("Buoyancy")
	ship.add_child(movement)
	return movement


func sail(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func wake_of(movement: ShipMovement) -> WakeEmitter:
	return movement.get_parent().get_node("WakeEmitter")


func leaves_trail() -> bool:
	var ocean := spawn_world()
	var movement := spawn_ship(ocean)
	movement.set_sail_level(SAILING_LEVEL)
	await sail(12.0)
	var wake := wake_of(movement)
	var points := wake.shader_points()
	var head_at_bow := Vector2(points[0].x, points[0].y).distance_to(Vector2(wake.global_position.x, wake.global_position.z)) < 0.01
	var newest_first := true
	for i in points.size() - 1:
		newest_first = newest_first and points[i].z >= points[i + 1].z
	var trail_behind := (wake.global_position - Vector3(points[-1].x, wake.global_position.y, points[-1].y)).dot(movement.forward_direction()) > 20.0
	print("    %d points, head speed %.1f m/s" % [points.size(), points[0].w])
	ocean.get_parent().queue_free()
	return points.size() >= 4 and head_at_bow and newest_first and trail_behind and points[0].w > 1.0


func ocean_receives_wake() -> bool:
	var ocean := spawn_world()
	var movement := spawn_ship(ocean)
	movement.set_sail_level(SAILING_LEVEL)
	await sail(8.0)
	await process_frame
	var count: int = ocean.material.get_shader_parameter(&"wake_point_count")
	var uploaded: PackedVector4Array = ocean.material.get_shader_parameter(&"wake_points")
	var expected := wake_of(movement).shader_points().size() + 1
	print("    uploaded %d of %d slots" % [count, uploaded.size()])
	ocean.get_parent().queue_free()
	return count >= 3 and absi(count - expected) <= 1 and uploaded.size() == Ocean.MAX_WAKE_POINTS and uploaded[count - 1].w < 0.0


func hull_mask_reports_speed() -> bool:
	var ocean := spawn_world()
	var movement := spawn_ship(ocean)
	movement.set_sail_level(SAILING_LEVEL)
	await sail(10.0)
	var mask: HullWaterMask = movement.get_parent().get_node("HullWaterMask")
	var reported := mask.to_shader_size().z
	var actual := absf(movement.forward_speed())
	print("    mask speed %.2f, ship speed %.2f" % [reported, actual])
	ocean.get_parent().queue_free()
	return actual > 5.0 and absf(reported - actual) < actual * 0.1


func turning_trail_bends_smoothly() -> bool:
	var ocean := spawn_world()
	var movement := spawn_ship(ocean)
	movement.set_sail_level(movement.highest_sail_level())
	await sail(10.0)
	movement.steer(1.0)
	await sail(6.0)
	var wake := wake_of(movement)
	var points := wake.shader_points()
	var sharpest := 0.0
	for i in range(1, points.size() - 2):
		var newer := Vector2(points[i].x - points[i + 1].x, points[i].y - points[i + 1].y)
		var older := Vector2(points[i + 1].x - points[i + 2].x, points[i + 1].y - points[i + 2].y)
		sharpest = maxf(sharpest, rad_to_deg(absf(older.angle_to(newer))))
	print("    %d points, sharpest bend %.1f degrees" % [points.size(), sharpest])
	ocean.get_parent().queue_free()
	return sharpest <= wake.turn_spacing_degrees * 1.6


func wake_fades_after_stopping() -> bool:
	var ocean := spawn_world()
	var movement := spawn_ship(ocean)
	movement.set_sail_level(SAILING_LEVEL)
	await sail(8.0)
	movement.halt()
	(movement.get_parent() as RigidBody3D).linear_velocity = Vector3.ZERO
	await sail(ocean.wake_lifetime + 2.0)
	var wake := wake_of(movement)
	var remaining := wake.shader_points().size() if not wake.is_moving() else -1
	print("    %d points left after stopping, drifting at %.2f m/s" % [remaining, wake.speed()])
	ocean.get_parent().queue_free()
	return remaining == 0


func teleport_breaks_trail() -> bool:
	var ocean := spawn_world()
	var movement := spawn_ship(ocean)
	movement.set_sail_level(SAILING_LEVEL)
	await sail(8.0)
	var ship := movement.get_parent() as RigidBody3D
	ship.global_position += Vector3(120.0, 0.0, 0.0)
	await sail(0.5)
	var has_break := false
	for point in wake_of(movement).shader_points():
		has_break = has_break or point.w < 0.0
	ocean.get_parent().queue_free()
	return has_break


func wake_buffer_is_capped() -> bool:
	var ocean := spawn_world()
	for i in 6:
		var movement := spawn_ship(ocean, Vector3(i * 30.0, 0.0, 0.0))
		movement.set_sail_level(movement.highest_sail_level())
	await sail(20.0)
	await process_frame
	var count: int = ocean.material.get_shader_parameter(&"wake_point_count")
	var uploaded: PackedVector4Array = ocean.material.get_shader_parameter(&"wake_points")
	print("    %d points uploaded for 6 ships" % count)
	ocean.get_parent().queue_free()
	return count > 0 and count <= Ocean.MAX_WAKE_POINTS and uploaded.size() == Ocean.MAX_WAKE_POINTS
