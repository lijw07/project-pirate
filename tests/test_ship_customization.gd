extends SceneTree

var failures := 0
var checks := 0

func check(value: bool, caption: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS " if value else "FAIL ", caption)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var data := ShipAppearance.defaults()
	var fallback := ShipAppearance.validate({"version": 1, "figurehead": "../../missing", "main": "invalid", "main_flag": {"length": 900}, "hull": false})
	check(fallback.figurehead == "gull" and fallback.main.shape == "square" and fallback.main_flag.length == 1.35, "damaged selections are validated and flag dimensions bounded")
	check(ShipAppearance.validate({"version": 99}) == data, "unknown save version safely falls back")
	check(ShipAppearance.validate_name("  Black Pearl  ") == "Black Pearl", "ship name keeps user text and trims surrounding spaces")
	check(ShipAppearance.validate_name("   ") == ShipAppearance.DEFAULT_SHIP_NAME and ShipAppearance.validate_name(42) == ShipAppearance.DEFAULT_SHIP_NAME, "empty and malformed ship names use the default")
	check(ShipAppearance.validate_name("A".repeat(80)).length() == ShipAppearance.SHIP_NAME_LIMIT, "long ship names are bounded for the title area")
	var path := "/tmp/project_pirate_customization_test.json"
	var custom := ShipAppearance.preset("tidebound")
	custom.match_sails = false
	custom.secondary.shape = "swallowtail"
	custom.secondary.emblem = "moon"
	custom.secondary.enabled = false
	custom = ShipAppearance.validate(custom)
	check(custom.match_sails and custom.secondary == custom.main, "legacy independent sail settings inherit the main sail design")
	custom.match_pennants = false
	custom.main_flag.shape = "streamer"
	custom.fore_flag.shape = "square"
	custom.aft_flag.shape = "none"
	custom = ShipAppearance.validate(custom)
	check(custom.match_pennants and custom.fore_flag == custom.main_flag and custom.aft_flag == custom.main_flag, "legacy independent pennants inherit the main pennant design")
	custom.aft_port = "flowers"
	check(ShipAppearance.save(custom, path) == OK and ShipAppearance.read_saved(path) == custom, "shared sails, pennants, props and paint round-trip through saved loadout")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check(ShipAppearance.read_saved(path) == data, "truncated save recovers without crashing")
	DirAccess.remove_absolute(path)
	var ship := CosmeticShip.new()
	ship.load_saved_on_ready = false
	root.add_child(ship)
	await process_frame
	await process_frame
	ship.apply(custom)
	await process_frame
	check(not ship.base.get_node("Bowsprit").visible and ship.base.get_node("BowSailFigurehead").visible, "carving replaces bowsprit and selects cleared bow sail")
	check(ship.fittings.get_node("SecondarySail").get_meta("cosmetic_id") == "secondary_sail", "secondary sail uses the main sail shape")
	check(ship.fittings.get_node("ForePennant").get_meta("cosmetic_id") == "pennants_streamer" and ship.fittings.get_node("AftPennant").get_meta("cosmetic_id") == "pennants_streamer", "all mast pennants share the same shape")
	check(ship.fittings.get_node("aft_port").position == Vector3(-1.35, 3.5, -5.96), "stern prop uses corrected rear mount")
	var cloth_mesh: MeshInstance3D
	for mesh in ship._meshes(ship.fittings.get_node("SecondarySail")):
		if String(mesh.name).contains("cloth"): cloth_mesh = mesh
	check(cloth_mesh != null and cloth_mesh.get_active_material(0).albedo_texture != null, "secondary sail has painted texture")
	var same_sail := ship.fittings.get_node("SecondarySail")
	custom.hull = "#552211"
	ship.apply(custom)
	check(ship.fittings.get_node("SecondarySail") == same_sail, "paint edits retain geometry and animation players")
	var initial_blend := cloth_mesh.get_blend_shape_value(0)
	await create_timer(0.45).timeout
	check(not is_equal_approx(initial_blend, cloth_mesh.get_blend_shape_value(0)), "imported sail flutter actually advances")
	for region in ship._timber_surfaces:
		check(region.mesh.get_active_material(region.surface) is ShaderMaterial, "paint applies to " + region.region)
	data.figurehead = "none"
	data.main.enabled = false
	data.pennants = false
	ship.apply(data)
	check(ship.base.get_node("Bowsprit").visible and ship.base.get_node("BowSailOriginal").visible and not ship.base.get_node("BowSailFigurehead").visible, "removing carving restores beam and original bow cloth")
	for mesh in ship._meshes(ship.base):
		if String(mesh.name) in ["sail-a", "sail-b"] or String(mesh.name).begins_with("flag-c"):
			check(mesh.visible, "original " + String(mesh.name) + " restored")
	for region in ship._timber_surfaces: check(region.mesh.get_active_material(region.surface) == region.original, "natural " + region.region + " restores source atlas")
	for shape in ShipAppearance.SHAPES:
		data = ShipAppearance.defaults()
		data.main.shape = shape
		ship.apply(data)
		check(ship.fittings.get_node("SecondarySail").get_meta("cosmetic_id") == "secondary_sail" + ("" if shape == "square" else "_" + shape), "matching sails propagate " + shape)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ships/cosmetics/manifest.json"))
	for module in manifest.modules:
		check(FileAccess.get_sha256(CosmeticShip.MODEL_DIR + module.file) == module.sha256, "approved asset integrity: " + module.id)
	# Exercise all pattern/emblem templates, including long-flag compensation.
	var textures_ok := true
	for pattern in ShipAppearance.PATTERNS:
		for emblem in ShipAppearance.EMBLEMS:
			var settings := ShipAppearance.sail()
			settings.pattern = pattern
			settings.emblem = emblem
			for flag in [true, false]:
				var tex := SailPainter.texture(settings, flag, 4.8 if flag else 1.0)
				textures_ok = textures_ok and tex != null and tex.get_width() == 512
	check(textures_ok, "all 128 paint combinations render successfully")
	var wind := WindEffects.new()
	root.add_child(wind)
	wind.set_process(false)
	ship.wind_source = wind
	wind.strength = 0.0
	ship._update_wind()
	var calm_ok := true
	for entry in ship._wind_pennants.values():
		for player in entry.players: calm_ok = calm_ok and is_zero_approx(player.speed_scale)
	check(calm_ok, "calm wind stops pennant flutter")
	wind.strength = 0.8
	var wind_ok := true
	for heading in [0.0, 90.0, 180.0, 270.0]:
		wind.heading = heading
		ship.rotation.y = deg_to_rad(heading * 0.5)
		ship._update_wind()
		for mast in ship._wind_pennants:
			var entry: Dictionary = ship._wind_pennants[mast]
			var anchor: Vector3 = ship.FLAG_ANCHORS[mast]
			wind_ok = wind_ok and (entry.instance.transform * anchor).is_equal_approx(anchor)
			wind_ok = wind_ok and entry.instance.basis.is_equal_approx(Basis.IDENTITY)
			for player in entry.players: wind_ok = wind_ok and player.speed_scale > 1.0
	check(wind_ok, "pennants stay aligned with the turning ship at every wind heading while continuing to flutter")
	wind.paused = true
	ship._update_wind()
	check(ship._wind_pennants.main.players[0].speed_scale == 0.0, "paused wind freezes pennant animation")
	var old_wind_save := ShipAppearance.defaults()
	old_wind_save.main_flag.breeze = 1.5
	check(not ShipAppearance.validate(old_wind_save).main_flag.has("breeze"), "saved cosmetics no longer override the wind")
	wind.queue_free()
	ship.queue_free()
	await process_frame
	var menu: Node = load("res://scenes/main_menu_preview.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu.show_customization()
	await process_frame
	check(menu.ship.wind_source == menu.get_node("WindEffects"), "harbor pennants use the scene wind")
	check(menu.sign_art != null and menu.sign_art.texture == menu.BOARD, "customization retains the Harbor Sign artwork")
	var panel: ShipCustomizationPanel = menu.workshop
	for section in ["Ship", "Sails", "Flags", "Decor", "Deck"]:
		panel.section = section
		panel._rebuild()
		await process_frame
		check(panel.content.get_child_count() > 0, "controls build for " + section)
	panel.draft.figurehead = "lion"
	panel._changed()
	check(menu.ship.appearance.figurehead == "lion", "draft updates live ship")
	menu.close_customization(false)
	check(menu.ship.appearance == ShipAppearance.read_saved(), "Cancel restores saved appearance")
	var sailing: Node = load("res://scenes/cosmetic_sailing_test.tscn").instantiate()
	root.add_child(sailing)
	await process_frame
	check(sailing.get_node("PlayerShip/CosmeticShip").wind_source == sailing.get_node("WindEffects"), "sailing pennants use the scene wind")
	check(not sailing.get_node("PlayerShip/Model").visible, "sailing preview hides original medium ship")
	check(sailing.get_node("PlayerShip/CosmeticShip").appearance == ShipAppearance.read_saved(), "sailing preview loads same saved appearance")
	check(sailing.get_node("PlayerShip").mass == 12000.0, "cosmetics leave physics unchanged")
	sailing.queue_free()
	menu.queue_free()
	await process_frame
	print("CUSTOMIZATION: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
