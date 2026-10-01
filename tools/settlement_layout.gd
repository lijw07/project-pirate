extends RefCounted

const DIRECTORY := "res://assets/models/settlements/"
const SOFT_ASSETS := ["grass-tuft", "flowering-grass", "fern-patch", "shrub-cluster"]


static func scene_path(id: String) -> String:
	return "res://game/settlements/assets/%s.tscn" % id.replace("-", "_")


static func layout_path(id: String) -> String:
	return "res://game/settlements/layouts/%s.tscn" % id.replace("-", "_")


static func available() -> bool:
	return ResourceLoader.exists(layout_path("food"))


static func prepare_model(model: Node3D, id: String) -> void:
	var assembly := model.get_child(0)
	for child in assembly.get_children():
		var label := str(child.name).to_lower()
		if label.begins_with("beach") or label.begins_with("wet sand") or label.begins_with("island ground") or "dock" in label or "mooring" in label or "structure-platform" in label:
			continue
		child.free()
	var scenery: Node3D = load(DIRECTORY + "layouts/%s_scenery.glb" % id.replace("-", "_")).instantiate()
	scenery.name = "SettlementScenery"
	model.add_child(scenery)


static func populate(body: Node3D, id: String) -> void:
	var layout: Node3D = load(layout_path(id)).instantiate()
	layout.name = "Settlement"
	body.add_child(layout)
	layout.owner = body


static func skip_collision(id: String, mesh_name: String) -> bool:
	var label := mesh_name.to_lower()
	if id in SOFT_ASSETS:
		return true
	if id == "citrus-tree":
		return not label.begins_with("trunk")
	for word in ["flame", "fire", "rope", "cable", "banner", "fruit", "leafy crop", "crop heart", "wildflower", "windmill sail", "window glass", "arrow slit", "tower slit"]:
		if word in label:
			return true
	return false
