extends SceneTree
func _initialize() -> void:
	call_deferred("inspect")

func inspect() -> void:
	for id in ["ship-warship", "food", "harbor-player", "module-rigging"]:
		var model = load("res://assets/pirate/models/" + id + ".glb").instantiate()
		root.add_child(model)
		print("ASSET ", id, " root ", model.transform)
		for node in model.find_children("*", "MeshInstance3D", true, false):
			if id != "food" or "Beach" in str(node.name) or "foam" in str(node.name):
				print(node.get_path(), " ", model.global_transform.affine_inverse() * node.global_transform * node.mesh.get_aabb())
		model.free()
	quit()
