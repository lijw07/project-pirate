extends SceneTree

const Wake = preload("res://scripts/ships/ship_wake.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1


func run() -> void:
	var wake := Wake.new()
	for tick in 120:
		wake._sample(Vector3(0, sin(tick * 0.1), 0), Vector3.BACK, 0, true, 1.0 / 60.0)
	check(wake.points.is_empty(), "stationary wave heave produces no wake")
	for tick in 120:
		wake._sample(Vector3(0, 0, tick * 14.0 / 60.0), Vector3.BACK, 14, true, 1.0 / 60.0)
	check(wake.points.size() > 10, "real sailing builds a continuous history")
	check(is_equal_approx(wake._head.y, 119 * 14.0 / 60.0 + Wake.BOW_OFFSET), "forward wake begins at the bow that cuts the water")
	var old_point: Vector4 = wake.points.back()
	for tick in 20:
		var forward := Vector3(sin(tick * 0.03), 0, cos(tick * 0.03))
		wake._sample(Vector3(tick * 0.05, 0, 28 + tick * 0.2), forward, 14, true, 1.0 / 60.0)
	check(wake.points.back() == old_point, "turning leaves old foam at its original world position")
	var strength_at_speed := wake._head.w
	for tick in 240:
		wake._sample(Vector3(1, 0, 32), Vector3.BACK, 0, true, 1.0 / 60.0)
	check(wake.points.is_empty() and not wake._has_head, "stopping removes all foam after its lifetime")
	wake._sample(Vector3(1, 0, 32), Vector3.BACK, -2.5, true, 0.12)
	check(wake._head.y < 32 and wake._head.w < strength_at_speed, "reverse emits a smaller wake from the leading stern")
	wake._sample(Vector3(1000, 0, 1000), Vector3.BACK, 14, true, 0.12)
	check(wake.points.size() == 1 and wake.points[0].x == 1000, "teleport does not draw a line across the ocean")
	for tick in 30:
		wake._sample(Vector3(1000, 20, 1000), Vector3.BACK, 14, false, 0.12)
	check(wake.points.is_empty(), "airborne motion does not emit foam and old foam expires")
	wake.free()

	var level: Node3D = load("res://scenes/ship_movement_test_scene.tscn").instantiate()
	root.add_child(level)
	var controller: ShipWake = level.get_node("ShipWake")
	controller.set_physics_process(false)
	check(controller.ocean == level.get_node("Ocean") and controller.movement == level.get_node("PlayerShip/ShipMovement"), "scene connects the followed ship to its ocean")
	for tick in 600:
		controller._sample(Vector3(0, 0, tick * 14.0 / 60.0), Vector3.BACK, 14, true, 1.0 / 60.0)
	controller._upload()
	var water := controller.ocean.water()
	var count: int = water.get_shader_parameter("wake_count")
	check(count > 2 and count <= Wake.CAPACITY, "long sailing stays within the shader history capacity")
	var bounds: Vector4 = water.get_shader_parameter("wake_bounds")
	check(bounds.x <= -6.0 and bounds.z >= 6.0, "shader bounds include both expanding ribbons")
	var hull: Vector4 = water.get_shader_parameter("wake_hull")
	check(is_equal_approx(hull.y, 599 * 14.0 / 60.0) and hull.z == 0 and hull.w == 1, "hull foam mask follows the ship position and heading")
	controller.free()
	check(water.get_shader_parameter("wake_count") == 0, "removing the emitter clears its wake")
	level.free()
	print("ship wake test failures: ", failures)
	quit(failures)
