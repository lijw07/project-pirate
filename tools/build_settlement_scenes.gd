extends SceneTree

const Layout = preload("res://tools/settlement_layout.gd")
const AssetPaths = preload("res://tools/asset_paths.gd")
var records: Array


func _initialize() -> void:
	call_deferred("build")


func own(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		if child.scene_file_path.is_empty():
			own(child, owner_node)


func save_scene(node: Node, path: String) -> void:
	own(node, node)
	var scene := PackedScene.new()
	assert(scene.pack(node) == OK)
	assert(ResourceSaver.save(scene, path) == OK)


func build() -> void:
	records = JSON.parse_string(FileAccess.get_file_as_string(Layout.DIRECTORY + "manifest.json")).assets
	for record in records:
		build_asset(record)
	var placements: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Layout.DIRECTORY + "layouts/placements.json"))
	var new_ids: Array = records.map(func(record): return record.id)
	for id in placements:
		var layout := Node3D.new()
		layout.name = str(id).to_pascal_case() + "Settlement"
		layout.set_meta("source", "approved_blender_settlements_v1")
		for item in placements[id]:
			var path := Layout.scene_path(item.asset) if item.asset in new_ids else AssetPaths.scene_path(item.asset)
			var node: Node3D = load(path).instantiate()
			var values: Array = item.transform
			node.transform = Transform3D(Vector3(values[0],values[1],values[2]), Vector3(values[3],values[4],values[5]), Vector3(values[6],values[7],values[8]), Vector3(values[9],values[10],values[11]))
			# Blender's grass is 3 mm higher than the fitted Godot cover.
			node.position.y -= 0.003
			node.name = str(item.asset).to_pascal_case() + str(layout.get_child_count())
			layout.add_child(node)
		save_scene(layout, Layout.layout_path(id))
		layout.free()
	print("BUILT 28 settlement asset scenes and six reusable populated layouts")
	await process_frame
	quit()


func build_asset(record: Dictionary) -> void:
	var id: String = record.id
	var soft := id in Layout.SOFT_ASSETS
	var node: Node3D = Node3D.new() if soft else StaticBody3D.new()
	node.name = id.to_pascal_case()
	node.set_meta("asset_id", id)
	node.set_meta("collision_policy", "non_blocking_foliage" if soft else "static_solid_triangles")
	node.add_to_group("settlement_assets", true)
	if not soft:
		node.collision_layer = 1
		node.collision_mask = 3
	root.add_child(node)
	var visual: Node3D = load(record.model).instantiate()
	visual.name = "Visual"
	node.add_child(visual)
	var faces := PackedVector3Array()
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		var local := node.global_transform.affine_inverse() * mesh.global_transform
		var box := local * mesh.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		if Layout.skip_collision(id, str(mesh.name)):
			continue
		faces.append_array(local * mesh.mesh.get_faces())
	if not soft:
		assert(not faces.is_empty(), id + " needs solid geometry")
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		var collision := CollisionShape3D.new()
		collision.name = "SolidGeometry"
		collision.shape = shape
		node.add_child(collision)
	node.set_meta("visual_bounds", bounds)
	save_scene(node, record.scene)
	node.free()
