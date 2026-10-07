extends "res://tests/test_ship_customization_ui.gd"
func run() -> void:
	menu = load("res://scenes/main_menu_preview.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	menu.show_customization()
	await create_timer(0.2).timeout
	menu.workshop.draft = ShipAppearance.defaults()
	menu.workshop.draft.main_flag.shape = "streamer"
	menu.workshop.draft.main_flag.length = 1.35
	menu.workshop.draft.main_flag.height = 1.2
	menu.workshop._changed()
	for window_size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1024, 768)]:
		root.size = window_size
		await create_timer(0.2).timeout
		for category in ["Ship", "Sails", "Flags", "Decor", "Deck"]:
			menu.workshop._select_section(category)
			await create_timer(0.1).timeout
			check_layout()
			if category == "Flags":
				var rect := Rect2(Vector2(620, 20), root.get_visible_rect().size - Vector2(640, 80))
				var all_visible := true
				for entry in menu.ship._wind_pennants.values():
					for mesh in entry.meshes:
						if not mesh.visible: continue
						var box: AABB = mesh.get_aabb()
						for i in 8:
							var world: Vector3 = mesh.global_transform * box.get_endpoint(i)
							all_visible = all_visible and not menu.camera.is_position_behind(world) and rect.has_point(menu.camera.unproject_position(world))
				check(all_visible, "longest pennants all fit beside the sign at " + str(window_size))
	root.size = Vector2i(1440, 900)
	menu.workshop._select_section("Flags")
	await create_timer(0.3).timeout
	await shot("all-flags")
	menu.workshop._select_section("Decor")
	await create_timer(0.2).timeout
	await select("Figurehead", 0)
	await select("Banners", 2)
	await select("Bunting", 3)
	await select("Braided trim", 1)
	check(menu.ship.appearance.banners_color == "teal" and menu.ship.appearance.bunting_color == "ivory", "decorations have independent color choices")
	menu.inspect_ship("Stern")
	await create_timer(0.3).timeout
	await shot("attached-stern")
	menu.orbit_target = Vector3(0, 2.5, 0)
	menu.orbit_yaw = 1.0
	menu.orbit_distance = 22
	menu.orbit_pitch = 0.28
	await create_timer(0.3).timeout
	await shot("attached-trim")
	for name in ["Banners", "Bunting", "Braided trim"]: await select(name, 0)
	check(not menu.ship.fittings.has_node("Banners") and not menu.ship.fittings.has_node("Bunting") and not menu.ship.fittings.has_node("Tassels"), "None removes each decoration")
	print("CUSTOMIZATION REVIEW: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
