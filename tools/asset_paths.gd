extends RefCounted

const IslandGeometry = preload("res://tools/island_geometry.gd")
const MODEL_DIR := "res://assets/models/pirate/"
const MANIFEST_PATH := MODEL_DIR + "manifest.json"
const REPORT_DIR := "res://tests/reports/"


static func scene_path(id: String) -> String:
	return "res://game/%s/%s.tscn" % [category(id), file_stem(id)]


static func model_path(id: String) -> String:
	return MODEL_DIR + file_stem(id) + ".glb"


static func report_path(file_name: String) -> String:
	DirAccess.make_dir_recursive_absolute(REPORT_DIR)
	return REPORT_DIR + file_name


static func file_stem(id: String) -> String:
	return id.replace("-", "_")


static func category(id: String) -> String:
	if id.begins_with("ship-"):
		return "ships"
	if id.begins_with("module-"):
		return "modules"
	if id in IslandGeometry.ISLANDS:
		return "islands"
	return "props"
