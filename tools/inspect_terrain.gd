extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var model = load("res://assets/pirate/models/food.glb").instantiate()
	root.add_child(model)
	for node in model.find_children("*","MeshInstance3D",true,false):
		if "Wet sand" not in str(node.name) and "Beach" not in str(node.name): continue
		var levels := {}
		var points := {}
		for v in node.global_transform * node.mesh.get_faces():
			levels[snappedf(v.y,0.001)] = true
			if v.y < -0.199:points[Vector2(v.x,v.z)] = true
		print(node.name, " levels ", levels.keys(), " base ", points.keys())
	model.queue_free()
	await process_frame
	quit()
