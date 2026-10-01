extends SceneTree

const AssetPaths = preload("res://tools/asset_paths.gd")
var failures := 0
var checks := 0
var results: Array = []
func _initialize() -> void:
	call_deferred("run")
func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	results.append({"check":label,"passed":passed})
	print(("PASS " if passed else "FAIL ") + label)
func ray(world: Node3D, x: float, z: float, top: float = 30.0) -> Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,top,z),Vector3(x,-10,z),3))
func run() -> void:
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string(AssetPaths.MANIFEST_PATH)).assets
	check("34 approved assets have a scene",records.size()==34)
	for record in records:
		var asset: PhysicsBody3D = load(record.scene).instantiate()
		if asset is RigidBody3D: asset.freeze = true
		root.add_child(asset)
		await physics_frame
		await physics_frame
		var colliders := asset.find_children("*","CollisionShape3D",true,false)
		var valid := not colliders.is_empty()
		for c in colliders:
			valid = valid and c.get_parent() is PhysicsBody3D and c.shape != null and not c.disabled
			if asset is RigidBody3D or asset is AnimatableBody3D:
				valid = valid and c.shape is ConvexPolygonShape3D
		check(record.id + " body has valid collision shapes",valid)
		var box: AABB = asset.get_meta("visual_bounds")
		var hit := false
		for x in range(9):
			for z in range(9):
				var pos := box.position + box.size * Vector3(float(x)/8,1,float(z)/8)
				if not ray(asset,pos.x,pos.z,pos.y+5).is_empty():hit = true
		check(record.id + " responds to physics rays",hit)
		if record.id == "dock-corner":
			check("corner dock deck is solid",not ray(asset,-1.3,0.0).is_empty())
			check("corner dock open water stays open",ray(asset,0.65,0.65).is_empty())
		if record.id == "shipyard-gantry":
			var q := PhysicsRayQueryParameters3D.create(Vector3(0.75,1.4,-4),Vector3(0.75,1.4,4),3)
			check("gantry passage stays open",asset.get_world_3d().direct_space_state.intersect_ray(q).is_empty())
		if asset.has_meta("land_scale"):
			check(record.id+" enlarged land without scaling whole island",asset.get_meta("land_scale")==3.0 and asset.scale==Vector3.ONE)
			var base: MeshInstance3D = asset.get_node("UnderwaterFoundation")
			var bounds := base.mesh.get_aabb()
			check(record.id+" foundation reaches seabed and meets shore",bounds.position.y<=-18.19 and bounds.end.y>=2.62)
			for depth in [-1.0,-4.0,-12.0]:
				var closed := true
				for side in range(16):
					var a := side*TAU/16
					var from := Vector3(cos(a)*100,depth,sin(a)*100)
					var q := PhysicsRayQueryParameters3D.create(from,Vector3(0,depth,0),1)
					closed = closed and not asset.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
				check(record.id+" solid underwater perimeter at "+str(depth)+"m",closed)
		asset.queue_free()
		await process_frame
	var scene: Node3D = load("res://levels/sandbox/ocean_sandbox.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	check("six islands and harbors instantiated",scene.get_node("Islands").get_child_count()==6)
	check("four physical ships instantiated",scene.get_node("Ships").get_child_count()==4)
	check("ocean uses unchanged project wave preset",scene.get_node("Ocean").wave_settings.resource_path == "res://game/ocean/default_waves.tres")
	check("ocean uses original mesh settings",scene.get_node("Ocean").extent == 1600.0 and scene.get_node("Ocean").subdivisions == 220)
	var ground_query := PhysicsRayQueryParameters3D.create(Vector3(500,0,500),Vector3(500,-30,500),1)
	var ground_hit := scene.get_world_3d().direct_space_state.intersect_ray(ground_query)
	check("seabed has a solid floor at minus 18m",not ground_hit.is_empty() and absf(ground_hit.position.y+18)<0.01)
	var camera = scene.get_node("OrbitCamera")
	check("camera starts on archipelago overview",camera.target == scene.get_node("Overview"))
	camera.cycle_target()
	check("camera can focus a ship or island",camera.target != scene.get_node("Overview"))
	camera._handle_key(KEY_HOME)
	check("Home restores overview",camera.target == scene.get_node("Overview") and camera.distance == 465.0)
	for i in 480: await physics_frame
	var ocean = scene.get_node("Ocean")
	for ship: RigidBody3D in scene.get_node("Ships").get_children():
		var offset: float = ship.global_position.y - ocean.height_at(ship.global_position)
		print("    ",ship.name," surface offset ",offset," upright ",ship.global_basis.y.dot(Vector3.UP))
		check(str(ship.name)+" floats upright",absf(offset)<1.5 and ship.global_basis.y.dot(Vector3.UP)>0.93)
		check(str(ship.name)+" has six active buoyancy probes",ship.get_node("Buoyancy").get_child_count()==6 and ship.get_node("Buoyancy").submerged_fraction>0)
	# A falling rigid body must settle on the actual island mesh, not pass through it.
	var island: StaticBody3D = scene.get_node("Islands/Food")
	var hit := ray(island,island.position.x+8,island.position.z)
	check("food island beach ray hits",not hit.is_empty())
	if not hit.is_empty():
		var ball := RigidBody3D.new()
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.3
		shape.shape = sphere
		ball.add_child(shape)
		ball.position = hit.position + Vector3(0,3,0)
		root.add_child(ball)
		for i in 120: await physics_frame
		check("rigid body lands on island collision",ball.position.y > hit.position.y - 0.2 and ball.position.y < hit.position.y+0.8)
		ball.queue_free()
	scene.queue_free()
	await process_frame
	await process_frame
	var f := FileAccess.open(AssetPaths.report_path("asset_integration.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	print("ASSET INTEGRATION: ",checks," checks, ",failures," failures")
	quit(failures)
