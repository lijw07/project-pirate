extends SceneTree

const SETTLE_FRAMES := 240
const SWELL_HEIGHT := 10.0

var failures := 0


func _initialize() -> void:
	await process_frame
	_check(await _settles_on_moved_target(), "camera settles on a moved target")
	_check(await _keeps_angle_while_following(), "camera keeps its angle while following")
	_check(await _rides_swells_lazily(), "camera rises with swells more slowly than it pans")
	_check(await _zoom_stays_within_limits(), "zoom stays within limits")
	print("overhead camera test failures: ", failures)
	quit(failures)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failures += 1
	print("FAIL ", label)


func _spawn_camera() -> OverheadCamera:
	var target := Node3D.new()
	root.add_child(target)
	var camera := OverheadCamera.new()
	camera.target = target
	root.add_child(camera)
	return camera


func _despawn(camera: OverheadCamera) -> void:
	camera.target.free()
	camera.free()


func _settle(frames := SETTLE_FRAMES) -> void:
	for frame in frames:
		await process_frame


func _looking_at(camera: OverheadCamera) -> Vector3:
	return camera.global_position - camera.global_basis.z * camera.distance


func _settles_on_moved_target() -> bool:
	var camera := _spawn_camera()
	camera.target.global_position = Vector3(120.0, 4.0, -80.0)
	await _settle(SETTLE_FRAMES * 4)
	var settled := _looking_at(camera).distance_to(camera.target.global_position) < 0.5
	_despawn(camera)
	return settled


func _keeps_angle_while_following() -> bool:
	var camera := _spawn_camera()
	var start_basis := camera.global_basis
	camera.target.global_position = Vector3(-60.0, 0.0, 200.0)
	camera.target.rotate_y(1.0)
	await _settle()
	var unchanged := camera.global_basis.is_equal_approx(start_basis)
	_despawn(camera)
	return unchanged


func _rides_swells_lazily() -> bool:
	var camera := _spawn_camera()
	camera.target.global_position = Vector3(SWELL_HEIGHT, SWELL_HEIGHT, 0.0)
	await _settle(10)
	var focus := _looking_at(camera)
	print("  after 10 frames: panned %.2f m, rose %.2f m" % [focus.x, focus.y])
	_despawn(camera)
	return focus.y < focus.x * 0.5


func _zoom_stays_within_limits() -> bool:
	var camera := _spawn_camera()
	for step in 40:
		camera.zoom_by(1.5)
	await _settle()
	var zoomed_out := camera.distance
	for step in 40:
		camera.zoom_by(0.5)
	await _settle()
	var zoomed_in := camera.distance
	var within := is_equal_approx(snappedf(zoomed_out, 0.01), camera.max_distance) and is_equal_approx(snappedf(zoomed_in, 0.01), camera.min_distance)
	print("  zoomed out %.2f m, zoomed in %.2f m" % [zoomed_out, zoomed_in])
	_despawn(camera)
	return within
