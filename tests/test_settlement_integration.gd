extends SceneTree

const Layout = preload("res://tools/settlement_layout.gd")
const AssetPaths = preload("res://tools/asset_paths.gd")
const Geometry = preload("res://tools/island_geometry.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)

func ray(node: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	return node.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Layout.DIRECTORY + "manifest.json"))
	check("28 approved models imported", manifest.assets.size() == 28)
	for record in manifest.assets:
		var node: Node3D = load(record.scene).instantiate()
		root.add_child(node)
		await physics_frame
		await physics_frame
		var shapes := node.find_children("*","CollisionShape3D",true,false)
		if record.id in Layout.SOFT_ASSETS:
			check(record.id + " does not obstruct movement", shapes.is_empty() and not node is PhysicsBody3D)
		else:
			check(record.id + " has static solid collision", node is StaticBody3D and shapes.size() == 1 and shapes[0].shape is ConcavePolygonShape3D and not shapes[0].disabled)
			var bounds: AABB = node.get_meta("visual_bounds")
			var hit := false
			for x in range(13):
				for z in range(13):
					var at := bounds.position + bounds.size * Vector3(float(x)/12,1,float(z)/12)
					if not ray(node,at+Vector3.UP*2,Vector3(at.x,-1,at.z)).is_empty(): hit = true
			check(record.id + " receives physics contacts",hit)
		if record.id == "castle-gatehouse":
			check("gate center passage open",ray(node,Vector3(0,1,-3),Vector3(0,1,3)).is_empty())
			check("gate pier blocks passage",not ray(node,Vector3(1.65,1,-3),Vector3(1.65,1,3)).is_empty())
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.35
			capsule.height = 1.8
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.collision_mask = 1
			var passage := true
			for step in range(13):
				query.transform.origin = Vector3(0,0.95,-2.4+step*0.4)
				passage = passage and node.get_world_3d().direct_space_state.intersect_shape(query).is_empty()
			check("person-sized capsule fits through arch",passage)
		if record.id == "citrus-tree":
			check("tree trunk is solid",not ray(node,Vector3(-2,1,0),Vector3(2,1,0)).is_empty())
			check("tree crown stays nonblocking",ray(node,Vector3(-2,2.5,0),Vector3(2,2.5,0)).is_empty())
		node.queue_free()
		await process_frame
	var placements: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Layout.DIRECTORY + "layouts/placements.json"))
	for id in placements:
		var island: Node3D = load(AssetPaths.scene_path(id)).instantiate()
		root.add_child(island)
		var layout := island.get_node("Settlement")
		check(id + " contains every approved placement",layout.get_child_count() == placements[id].size())
		var positions_match := true
		var grounded := true
		var ground := Geometry.ground_faces(island)
		for i in layout.get_child_count():
			var item: Dictionary = placements[id][i]
			var node: Node3D = layout.get_child(i)
			var values: Array = item.transform
			var expected := Transform3D(Vector3(values[0],values[1],values[2]),Vector3(values[3],values[4],values[5]),Vector3(values[6],values[7],values[8]),Vector3(values[9],values[10]-0.003,values[11]))
			positions_match = positions_match and node.transform.is_equal_approx(expected)
			var height := Geometry.surface_height(ground,node.position.x,node.position.z)
			grounded = grounded and is_finite(height) and absf(node.position.y-height) < 0.04
		check(id + " matches Blender positions, rotations and scale",positions_match)
		check(id + " placements sit on island terrain",grounded)
		check(id + " retains foundation and calm zone",island.has_node("UnderwaterFoundation") and island.has_node("CalmZone"))
		island.queue_free()
		await process_frame
	var file := FileAccess.open(AssetPaths.report_path("settlement_integration.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("SETTLEMENT INTEGRATION: ",checks," checks, ",failures," failures")
	quit(failures)
