extends SceneTree
const Geometry = preload("res://tools/island_geometry.gd")
const AssetPaths = preload("res://tools/asset_paths.gd")
var failures := 0
var count := 0
func _initialize(): call_deferred("run")
func check(label: String,ok: bool):
	count += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ")+label)
func run():
	for id in Geometry.ISLANDS:
		var body = load(AssetPaths.scene_path(id)).instantiate()
		root.add_child(body)
		var assembly = body.get_node("Visual").get_child(0)
		var beach: MeshInstance3D
		var cover: MeshInstance3D
		for node in assembly.get_children():
			if str(node.name).begins_with("Beach"):beach=node
			if str(node.name).begins_with("Island ground cover"):cover=node
		var sand := Geometry.local_faces(beach,body)
		var grass := Geometry.local_faces(cover,body)
		var supported := true
		for p in grass:
			var h := Geometry.surface_height(sand,p.x,p.z)
			if not is_finite(h) or absf(p.y-h-0.012)>0.004:supported=false
		check(id+" grass is supported by sand at every vertex",supported)
		var terrain := Geometry.ground_faces(body)
		var trees := true
		for tree: MeshInstance3D in assembly.find_children("*","MeshInstance3D",true,false):
			if not tree.has_meta("grounded_tree"):continue
			var b: AABB = body.global_transform.affine_inverse()*tree.global_transform*tree.mesh.get_aabb()
			var pos: Vector3 = body.global_transform.affine_inverse()*tree.global_position
			var h := Geometry.surface_height(terrain,pos.x,pos.z)
			trees = trees and absf(b.position.y-h+0.015)<0.005
		check(id+" tree roots seated on terrain",trees)
		var details := true
		for node in body.get_children():
			if not node.has_meta("grounded_detail"):continue
			var box: AABB = node.get_meta("visual_bounds")
			for point in [Vector2(box.position.x,box.position.z),Vector2(box.end.x,box.position.z),Vector2(box.end.x,box.end.z),Vector2(box.position.x,box.end.z)]:
				var h := Geometry.surface_height(terrain,node.position.x+point.x,node.position.z+point.y)
				details = details and is_finite(h) and absf(h-node.position.y-box.position.y-0.015)<0.03
		check(id+" added building footprints supported",details)
		var docks := true
		for dock: MeshInstance3D in assembly.find_children("*","MeshInstance3D",true,false):
			if not str(dock.name).begins_with("Dock • pier 0"):continue
			var b: AABB = body.global_transform.affine_inverse()*dock.global_transform*dock.mesh.get_aabb()
			var h := Geometry.surface_height(sand,b.get_center().x,b.position.z+0.1)
			docks = docks and is_finite(h)
		check(id+" docks overlap the shore",docks)
		body.queue_free()
		await process_frame
	await process_frame
	var f := FileAccess.open(AssetPaths.report_path("island_placement.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":count,"failures":failures},"\t"))
	print("PLACEMENT: ",count," checks, ",failures," failures")
	quit(failures)
