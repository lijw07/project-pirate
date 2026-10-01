extends SceneTree

const AssetPaths = preload("res://tools/asset_paths.gd")
func _initialize() -> void:
	call_deferred("capture")
func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.save_png(AssetPaths.report_path(path + ".png")) == OK)
	print("CAPTURE ",path)
func capture() -> void:
	var world: Node3D = load("res://levels/sandbox/ocean_sandbox.tscn").instantiate()
	root.add_child(world)
	await create_timer(5).timeout
	await shot("ocean_overview")
	var camera = world.get_node("OrbitCamera")
	camera.target = world.get_node("Ships/ShipWarship")
	camera.distance = 22
	camera.pitch_degrees = -26
	camera.yaw_degrees = 36
	await create_timer(3).timeout
	await shot("warship_in_ocean")
	camera.target = world.get_node("Islands/Food")
	camera.distance = 100
	camera.pitch_degrees = -40
	camera.yaw_degrees = 25
	await create_timer(3).timeout
	await shot("food_island_in_ocean")
	await create_timer(1).timeout
	await shot("food_island_wave_motion")
	# Inspect the island at water level during a trough without changing the ocean.
	camera.set_process(false)
	var metal: Node3D = world.get_node("Islands/Metal")
	camera.global_position = metal.position + Vector3(52,0.2,43)
	camera.look_at(metal.position + Vector3(0,-1,0))
	await create_timer(1).timeout
	await shot("grounded_island_waterline")
	camera.global_position = metal.position + Vector3(55,-6,45)
	camera.look_at(metal.position + Vector3(0,-8,0))
	await create_timer(1).timeout
	await shot("island_foundation_underwater")
	world.queue_free()
	await process_frame
	await process_frame
	var gallery: Node3D = load("res://levels/sandbox/asset_gallery.tscn").instantiate()
	root.add_child(gallery)
	await create_timer(2).timeout
	await shot("asset_gallery")
	gallery.queue_free()
	await process_frame
	await process_frame
	quit()
