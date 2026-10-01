extends SceneTree

const SETTLE_FRAMES := 180

var _failures := 0


func _initialize() -> void:
	await process_frame
	check("camera settles above a moved target", await settles_above_moved_target())
	check("camera keeps its angle while following", await keeps_angle_while_following())
	check("zoom stays within limits", await zoom_stays_within_limits())
	print("%d failure(s)" % _failures)
	quit(_failures)


func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed:
		_failures += 1


func spawn_camera() -> OverheadCamera:
	var target := Node3D.new()
	root.add_child(target)
	var camera := OverheadCamera.new()
	camera.target = target
	root.add_child(camera)
	return camera


func despawn(camera: OverheadCamera) -> void:
	camera.target.free()
	camera.free()


func settle() -> void:
	for i in SETTLE_FRAMES:
		await process_frame


func settles_above_moved_target() -> bool:
	var camera := spawn_camera()
	camera.target.global_position = Vector3(120.0, 0.0, -80.0)
	await settle()
	var looking_at := camera.global_position - camera.global_basis.z * camera.distance
	var settled := looking_at.distance_to(camera.target.global_position) < 0.5
	despawn(camera)
	return settled


func keeps_angle_while_following() -> bool:
	var camera := spawn_camera()
	var start_basis := camera.global_basis
	camera.target.global_position = Vector3(-60.0, 0.0, 200.0)
	await settle()
	var unchanged := camera.global_basis.is_equal_approx(start_basis)
	despawn(camera)
	return unchanged


func zoom_stays_within_limits() -> bool:
	var camera := spawn_camera()
	for i in 40:
		camera.zoom_by(1.5)
	await settle()
	var zoomed_out := camera.distance
	for i in 40:
		camera.zoom_by(0.5)
	await settle()
	var zoomed_in := camera.distance
	var within := is_equal_approx(snappedf(zoomed_out, 0.01), camera.max_distance) and is_equal_approx(snappedf(zoomed_in, 0.01), camera.min_distance)
	print("    zoomed out %.2f m, zoomed in %.2f m" % [zoomed_out, zoomed_in])
	despawn(camera)
	return within
