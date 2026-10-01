extends SceneTree

const AssetPaths = preload("res://tools/asset_paths.gd")
func _initialize(): call_deferred("run")
func run():
	var world = load("res://levels/sandbox/ocean_sandbox.tscn").instantiate()
	root.add_child(world)
	var camera = world.get_node("OrbitCamera")
	camera.set_process(false)
	var hud = world.get_node_or_null("ReviewHUD")
	if hud: hud.hide()
	for id in ["Food","Timber","Gold","Metal","HarborPlayer","HarborEnemy"]:
		var island = world.get_node("Islands/"+id)
		var center: Vector3 = island.global_position + Vector3(0,3.9,0)
		camera.global_position = center + Vector3(35,60,48)*(1.18 if "Harbor" in id else 1.0)
		camera.look_at(center)
		await create_timer(1).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(AssetPaths.report_path("ground_placement_"+id.to_snake_case()+".png"))
		print("CAPTURE ",id)
	world.queue_free()
	await process_frame
	await process_frame
	quit()
