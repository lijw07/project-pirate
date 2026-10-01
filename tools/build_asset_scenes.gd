extends SceneTree

const IslandGeometry = preload("res://tools/island_geometry.gd")
const ASSET_DIR := "res://assets/pirate/"
const SCENE_DIR := "res://scenes/assets/"
const CALM_ZONE_INNER_SCALE := 1.25
const CALM_ZONE_FALLOFF := 45.0
var records: Array = []
var report: Array = []

func _initialize() -> void:
	call_deferred("build")

func own(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		if child.scene_file_path.is_empty():
			own(child, owner_node)

func decorative(node: Node) -> bool:
	var text := str(node.name).to_lower()
	for word in ["foam", "pennant", "flag", "sail", "leaf", "rope", "tie", "glint", "rivet"]:
		if word in text:
			return true
	return false

func save_scene(node: Node, path: String) -> void:
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	assert(ResourceSaver.save(packed, path) == OK)

func add_shape(body: CollisionObject3D, shape: Shape3D, label: String) -> void:
	var node := CollisionShape3D.new()
	node.name = label
	node.shape = shape
	body.add_child(node)
	node.owner = body

func build() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(ASSET_DIR + "manifest.json"))
	records = manifest.assets
	if "--islands-only" in OS.get_cmdline_user_args():
		for record in records:
			if record.id in IslandGeometry.ISLANDS: build_asset(record.id)
		print("Rebuilt six island scenes; world layout and water resources preserved")
		await process_frame
		await process_frame
		quit()
		return
	for record in records:
		if record.id not in IslandGeometry.ISLANDS: build_asset(record.id)
	for record in records:
		if record.id in IslandGeometry.ISLANDS: build_asset(record.id)
	build_world()
	build_gallery()
	var file := FileAccess.open("res://docs/validation/asset-build.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("BUILT ", report.size(), " reusable asset scenes, ocean archipelago, and asset gallery")
	await process_frame
	await process_frame
	quit()

func build_asset(id: String) -> void:
	var ship := id.begins_with("ship-")
	var module := id.begins_with("module-")
	var body: PhysicsBody3D
	if ship:
		body = RigidBody3D.new()
		body.mass = 12000.0 if id != "ship-scout" else 4500.0
		body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		body.center_of_mass = Vector3(0, -0.5, 0)
		body.continuous_cd = true
		body.add_to_group("ships", true)
	elif module:
		body = AnimatableBody3D.new()
		body.sync_to_physics = false
	else:
		body = StaticBody3D.new()
	body.name = id.to_pascal_case()
	body.collision_layer = 2 if ship else 1
	body.collision_mask = 3
	body.set_meta("asset_id", id)
	body.add_to_group("pirate_assets", true)
	root.add_child(body)
	var model: Node3D = load(ASSET_DIR + "models/" + id + ".glb").instantiate()
	model.scene_file_path = ""
	model.name = "Visual"
	body.add_child(model)
	if id in IslandGeometry.ISLANDS:
		IslandGeometry.enlarge(model,id)
	# Imported GLBs have a scene wrapper around the actual assembly root.
	if ship:
		model.position.y = -0.6
		(model.get_child(0) as Node3D).rotation = Vector3.ZERO
	own(body, body)
	var faces := PackedVector3Array()
	var hull_points := PackedVector3Array()
	var cabin_points := PackedVector3Array()
	var visible_bounds := AABB()
	var first := true
	var excluded := 0
	for mesh_node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var transform := body.global_transform.affine_inverse() * mesh_node.global_transform
		var bounds := transform * mesh_node.mesh.get_aabb()
		visible_bounds = bounds if first else visible_bounds.merge(bounds)
		first = false
		if "foam" in str(mesh_node.name).to_lower():
			mesh_node.visible = false
		if decorative(mesh_node):
			excluded += 1
			continue
		var points := transform * mesh_node.mesh.get_faces()
		if ship:
			if str(mesh_node.name).begins_with("Hull + rigging"):
				for point in points:
					if point.y <= 2.65:
						hull_points.append(point)
					elif point.y < 4.9 and point.z < -2.4 and absf(point.x) < 2.5:
						cabin_points.append(point)
		elif module:
			var shape := ConvexPolygonShape3D.new()
			shape.points = points
			add_shape(body, shape, "Solid_" + str(mesh_node.name).validate_node_name())
		else:
			faces.append_array(points)
	if ship:
		assert(hull_points.size() > 12, id + " missing hull")
		var hull := ConvexPolygonShape3D.new()
		hull.points = hull_points
		add_shape(body, hull, "HullCollision")
		if cabin_points.size() > 12:
			var cabin := ConvexPolygonShape3D.new()
			cabin.points = cabin_points
			add_shape(body, cabin, "AftCabinCollision")
		var buoy := Node3D.new()
		buoy.name = "Buoyancy"
		buoy.set_script(load("res://scripts/ocean/buoyancy.gd"))
		buoy.draft = 0.25
		# Build children before adding the buoyancy component to the live tree.
		for z in [-2.8, 0.0, 2.8]:
			for x in [-1.1, 1.1]:
				var probe := Marker3D.new()
				probe.name = "Probe%d" % buoy.get_child_count()
				probe.position = Vector3(x, 0, z) * (0.75 if id == "ship-scout" else 1.0)
				buoy.add_child(probe)
		body.add_child(buoy)
		# Reuse the same existing water exclusion component as the filler ship.
		if ResourceLoader.exists("res://scripts/ocean/hull_water_mask.gd"):
			var mask := Node3D.new()
			mask.name = "HullWaterMask"
			mask.set_script(load("res://scripts/ocean/hull_water_mask.gd"))
			mask.position.z = -0.2
			mask.half_width = 1.3 if id == "ship-scout" else 1.75
			mask.half_length = 3.0 if id == "ship-scout" else 3.9
			body.add_child(mask)
		own(body, body)
		body.add_to_group("camera_targets", true)
	else:
		if not module:
			assert(not faces.is_empty())
			var shape := ConcavePolygonShape3D.new()
			shape.backface_collision = true
			shape.set_faces(faces)
			add_shape(body, shape, "SolidGeometry")
	if id in IslandGeometry.ISLANDS:
		IslandGeometry.foundation(body,model)
		add_island_details(body,id)
		add_calm_zone(body, visible_bounds)
	body.set_meta("visual_bounds", visible_bounds)
	body.set_meta("collision_policy", "convex_hull_and_cabin" if ship else ("convex_solid_parts" if module else "static_solid_triangles"))
	save_scene(body, SCENE_DIR + id + ".tscn")
	report.append({"id":id,"body":body.get_class(),"colliders":body.find_children("*", "CollisionShape3D",true,false).size(),"decorative_meshes_excluded":excluded,"bounds_position":str(visible_bounds.position),"bounds_size":str(visible_bounds.size)})
	body.free()

func instance_asset(id: String, parent: Node3D, at: Vector3, yaw: float = 0.0) -> Node3D:
	var node: Node3D = load(SCENE_DIR + id + ".tscn").instantiate()
	node.position = at
	node.rotation.y = yaw
	parent.add_child(node)
	return node

func build_world() -> void:
	var world: Node3D = load("res://scenes/test/ocean_test.tscn").instantiate()
	# Replace just the previous display content, retaining ocean, lighting, and camera.
	for label in ["Ships", "FillerIsland", "Islands", "Overview", "ReviewHUD", "Seabed"]:
		var old := world.get_node_or_null(label)
		if old: old.free()
	var islands := Node3D.new()
	islands.name = "Islands"
	world.add_child(islands)
	var ships := Node3D.new()
	ships.name = "Ships"
	world.add_child(ships)
	var ids := {"01":"food", "02":"timber", "03":"gold", "04":"metal", "05":"harbor-player", "06":"harbor-enemy"}
	var layout: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/blender-layout.json"))
	for item in layout:
		var p: Array = item.position
		var at := Vector3(p[0]*3.0, p[2], -p[1]*3.0)
		if str(item.name).begins_with("Ship"):
			var id := "ship-" + str(item.name).get_slice("• ", 1)
			instance_asset(id, ships, at, item.rotation[2])
		else:
			var island := instance_asset(ids[str(item.name).left(2)], islands, at)
			island.add_to_group("camera_targets", true)
	var overview := Marker3D.new()
	overview.name = "Overview"
	overview.position = Vector3(3, 0, -9)
	overview.add_to_group("camera_targets", true)
	world.add_child(overview)
	var camera := world.get_node("OrbitCamera") as Camera3D
	camera.target = overview
	camera.distance = 465.0
	camera.max_distance = 900.0
	camera.pitch_degrees = -55.0
	camera.yaw_degrees = 23.0
	camera.fov = 58
	camera.far = 2500
	camera.position = overview.position + Basis.from_euler(Vector3(deg_to_rad(-55), deg_to_rad(23), 0)) * Vector3(0,0,465)
	camera.rotation = Vector3(deg_to_rad(-55),deg_to_rad(23),0)
	# Always use the project's ocean scene without per-level wave or mesh overrides.
	world.get_node("Ocean").free()
	var ocean: Node3D = load("res://scenes/ocean/ocean.tscn").instantiate()
	ocean.name = "Ocean"
	world.add_child(ocean)
	var env: Environment = world.get_node("WorldEnvironment").environment.duplicate(true)
	env.ambient_light_color = Color("b8dbe5")
	env.ambient_light_energy = 0.65
	env.fog_density = 0.0007
	world.get_node("WorldEnvironment").environment = env
	var ground := IslandGeometry.seabed()
	world.add_child(ground)
	var hud := CanvasLayer.new()
	hud.name = "ReviewHUD"
	world.add_child(hud)
	var label := Label.new()
	label.position = Vector2(22,18)
	label.text = "THE SAPPHIRE REACH\n4 resource islands · 2 harbors · 4 ships\nRMB orbit   •   Wheel zoom   •   Tab focus   •   Esc + WASD pan   •   Home overview"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_shadow_color", Color(0.02,0.1,0.15,0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(label)
	own(world,world)
	save_scene(world, "res://scenes/test/ocean_test.tscn")
	world.free()

func build_gallery() -> void:
	var world := Node3D.new()
	world.name = "PirateAssetGallery"
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("244652")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d5e9ed")
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var index := 0
	for record in records:
		var x := (index % 6 - 2.5) * 100.0
		var z := floorf(index / 6.0) * 100.0
		var asset := instance_asset(record.id,world,Vector3(x,0,z))
		if asset is RigidBody3D: asset.freeze = true
		var text := Label3D.new()
		text.text = str(record.id).replace("-", " ").to_upper()
		text.position = Vector3(x,0.5,z+44)
		text.rotation_degrees.x = -90
		text.font_size = 64
		text.pixel_size = 0.022
		world.add_child(text)
		index += 1
	var focus := Marker3D.new()
	focus.position = Vector3(0,0,230)
	world.add_child(focus)
	var camera := Camera3D.new()
	camera.set_script(load("res://scripts/camera/orbit_camera.gd"))
	camera.target = focus
	camera.distance = 780.0
	camera.max_distance = 1200.0
	camera.pitch_degrees = -65.0
	camera.yaw_degrees = 0.0
	camera.far = 1500
	world.add_child(camera)
	own(world,world)
	save_scene(world,"res://scenes/test/asset_gallery.tscn")
	world.free()

func add_island_details(body: StaticBody3D, id: String) -> void:
	var placements := {
		"food": [["provision-store",-12,5],["food-crate",-9,7],["capture-standard",-12,10]],
		"timber": [["timber-workshop",12,-4],["repair-bench",12,1]],
		"gold": [["treasury-vault",12,-3],["gold-sacks",9,-1]],
		"metal": [["iron-foundry",12,4],["ore-crate",15.5,6]],
		"harbor-player": [["harbor-lighthouse",-18,-10],["shipyard-gantry",12,12],["cargo-rack",9,9],["cannonball-rack",8,5],["swivel-gun",-15,10],["deck-mortar",-12,13],["harpoon-launcher",-8,13]],
		"harbor-enemy": [["harbor-lighthouse",-18,-10],["shipyard-gantry",12,12],["cargo-rack",9,9],["cannonball-rack",8,5]]
	}
	for p in placements.get(id,[]):
		var detail := instance_asset(p[0],body,Vector3(p[1],1.3+IslandGeometry.LAND_LIFT,p[2]))
		IslandGeometry.place_detail(body,detail)
		detail.owner = body

func add_calm_zone(body: StaticBody3D, bounds: AABB) -> void:
	var zone := CalmZone.new()
	zone.name = "CalmZone"
	var center := bounds.get_center()
	zone.position = Vector3(center.x, 0.0, center.z)
	zone.inner_radius = maxf(bounds.size.x, bounds.size.z) * 0.5 * CALM_ZONE_INNER_SCALE
	zone.outer_radius = zone.inner_radius + CALM_ZONE_FALLOFF
	body.add_child(zone)
	zone.owner = body
