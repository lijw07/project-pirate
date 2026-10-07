class_name CosmeticShip
extends Node3D
## Visual assembly shared by the harbor menu and the cosmetic sailing test.

const MODEL_DIR := "res://assets/ships/cosmetics/models/"
const MODELS := {
	"reference_ship": preload("res://assets/ships/cosmetics/models/reference_ship.glb"),
	"pennants": preload("res://assets/ships/cosmetics/models/pennants.glb"),
	"pennants_square": preload("res://assets/ships/cosmetics/models/pennants_square.glb"),
	"pennants_pointed": preload("res://assets/ships/cosmetics/models/pennants_pointed.glb"),
	"pennants_streamer": preload("res://assets/ships/cosmetics/models/pennants_streamer.glb"),
	"lanterns": preload("res://assets/ships/cosmetics/models/lanterns.glb"),
	"gull": preload("res://assets/ships/cosmetics/models/gull.glb"),
	"serpent": preload("res://assets/ships/cosmetics/models/serpent.glb"),
	"kraken": preload("res://assets/ships/cosmetics/models/kraken.glb"),
	"leviathan": preload("res://assets/ships/cosmetics/models/leviathan.glb"),
	"banners": preload("res://assets/ships/cosmetics/models/banners.glb"),
	"bunting": preload("res://assets/ships/cosmetics/models/bunting.glb"),
	"tassels": preload("res://assets/ships/cosmetics/models/tassels.glb"),
	"lion": preload("res://assets/ships/cosmetics/models/lion.glb"),
	"nautilus": preload("res://assets/ships/cosmetics/models/nautilus.glb"),
	"cobalt_lamps": preload("res://assets/ships/cosmetics/models/cobalt_lamps.glb"),
	"paper_lamps": preload("res://assets/ships/cosmetics/models/paper_lamps.glb"),
	"compass_crest": preload("res://assets/ships/cosmetics/models/compass_crest.glb"),
	"sun_crest": preload("res://assets/ships/cosmetics/models/sun_crest.glb"),
	"chest": preload("res://assets/ships/cosmetics/models/chest.glb"),
	"crates": preload("res://assets/ships/cosmetics/models/crates.glb"),
	"rope_coil": preload("res://assets/ships/cosmetics/models/rope_coil.glb"),
	"flowers": preload("res://assets/ships/cosmetics/models/flowers.glb"),
	"bottles": preload("res://assets/ships/cosmetics/models/bottles.glb"),
	"books": preload("res://assets/ships/cosmetics/models/books.glb"),
	"barrel": preload("res://assets/ships/cosmetics/models/barrel.glb"),
	"cushions": preload("res://assets/ships/cosmetics/models/cushions.glb"),
	"main_sail": preload("res://assets/ships/cosmetics/models/main_sail.glb"),
	"main_sail_swallowtail": preload("res://assets/ships/cosmetics/models/main_sail_swallowtail.glb"),
	"main_sail_pointed": preload("res://assets/ships/cosmetics/models/main_sail_pointed.glb"),
	"main_sail_streamer": preload("res://assets/ships/cosmetics/models/main_sail_streamer.glb"),
	"secondary_sail": preload("res://assets/ships/cosmetics/models/secondary_sail.glb"),
	"secondary_sail_swallowtail": preload("res://assets/ships/cosmetics/models/secondary_sail_swallowtail.glb"),
	"secondary_sail_pointed": preload("res://assets/ships/cosmetics/models/secondary_sail_pointed.glb"),
	"secondary_sail_streamer": preload("res://assets/ships/cosmetics/models/secondary_sail_streamer.glb"),
}
const TIMBER_SHADER := preload("res://shaders/ship_timber_paint.gdshader")
const PROP_POSITIONS := [Vector3(-1.05, 3.3, 3.7), Vector3(1.05, 3.3, 3.7), Vector3(-1.35, 3.5, -5.96), Vector3(1.35, 3.5, -5.96)]
const FLAG_ANCHORS := {"fore": Vector3(0, 6.55, 4.215), "main": Vector3(0, 9.72, -0.343), "aft": Vector3(0, 9.12, -5.357)}
const DECOR_COLORS := {"crimson": [Color("a33f3c"), Color("e8d2a0")], "teal": [Color("287674"), Color("c9ac70")], "ivory": [Color("ded0ab"), Color("305e69")]}

@export var load_saved_on_ready := true
@export var wind_source: WindEffects
var _wind_pennants: Dictionary = {}
var appearance: Dictionary = {}
var base: Node3D
var fittings: Node3D
var _timber_surfaces: Array[Dictionary] = []
var _used_slots: Array[String] = []

func _ready() -> void:
	base = MODELS.reference_ship.instantiate()
	base.name = "ReferenceShip"
	add_child(base)
	for mesh in _meshes(base):
		for i in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(i) as StandardMaterial3D
			if material and material.resource_name.begins_with("Ship_"):
				_timber_surfaces.append({"mesh": mesh, "surface": i, "original": material, "region": material.resource_name.trim_prefix("Ship_").to_lower()})
	apply(ShipAppearance.read_saved() if load_saved_on_ready else ShipAppearance.defaults())

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D: result.append(node)
	for child in node.get_children(): result.append_array(_meshes(child))
	return result

func _set_named_visible(node: Node, needle: String, enabled: bool, prefix := false) -> void:
	var normalized := String(node.name).replace("_", "-")
	if (normalized.begins_with(needle) if prefix else normalized == needle):
		if node is Node3D: node.visible = enabled
	for child in node.get_children(): _set_named_visible(child, needle, enabled, prefix)

func _loop_animations(node: Node) -> void:
	if node is AnimationPlayer:
		# glTF has an independent clip for each flutter/sway. Merge tracks so all play.
		var combined := Animation.new()
		combined.length = 64.0 / 24.0
		combined.loop_mode = Animation.LOOP_LINEAR
		for animation_name in node.get_animation_list():
			if animation_name == "RESET": continue
			var clip: Animation = node.get_animation(animation_name)
			for track in clip.get_track_count(): clip.copy_track(track, combined)
		var library := AnimationLibrary.new()
		library.add_animation("motion", combined)
		node.add_animation_library("cosmetics", library)
		node.play("cosmetics/motion")
	for child in node.get_children(): _loop_animations(child)

func _add(id: String, slot: String) -> Node3D:
	if id == "none": return null
	_used_slots.append(slot)
	var instance := fittings.get_node_or_null(NodePath(slot)) as Node3D
	if instance and instance.get_meta("cosmetic_id") != id:
		fittings.remove_child(instance)
		instance.queue_free()
		instance = null
	if instance == null:
		var model := MODELS.get(id) as PackedScene
		if model == null: return null
		instance = model.instantiate() as Node3D
		instance.name = slot
		instance.set_meta("cosmetic_id", id)
		fittings.add_child(instance)
		_loop_animations(instance)
	var colors: Array = DECOR_COLORS[appearance.get(id + "_color", appearance.decoration_color)]
	for mesh in _meshes(instance):
		for index in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(index) as StandardMaterial3D
			if original == null: continue
			var material := original.duplicate() as StandardMaterial3D
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			match original.resource_name:
				"Cloth_Main": material.albedo_color = colors[0]
				"Cloth_Accent": material.albedo_color = colors[1]
				"Sail yard timber":
					if appearance.paint: material.albedo_color = Color(appearance.masts)
			mesh.set_surface_override_material(index, material)
	return instance

func _cloth_material(settings: Dictionary, flag := false, aspect := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = SailPainter.texture(settings, flag, aspect)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

func _sail(slot: String, settings: Dictionary) -> void:
	if not settings.enabled: return
	var id: String = slot + "_sail" + ("" if settings.shape == "square" else "_" + settings.shape)
	var instance := _add(id, slot.capitalize() + "Sail")
	var material := _cloth_material(settings)
	for mesh in _meshes(instance):
		for i in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(i)
			if original and original.resource_name.begins_with("Custom_"): mesh.set_surface_override_material(i, material)

func _flag(mast: String, settings: Dictionary) -> void:
	if settings.shape == "none": return
	var id: String = "pennants" + ("" if settings.shape == "swallowtail" else "_" + settings.shape)
	var instance := _add(id, mast.capitalize() + "Pennant")
	var anchor: Vector3 = FLAG_ANCHORS[mast]
	var flag_length := (2.3 if mast == "fore" else 2.9) if settings.shape == "streamer" else (1.65 if mast == "fore" else 2.05)
	var flag_height := 0.6 if settings.shape == "streamer" else 0.85
	var material := _cloth_material(settings, true, flag_length * settings.length / (flag_height * settings.height))
	for mesh in _meshes(instance):
		mesh.visible = String(mesh.name).begins_with(mast.capitalize())
		if not mesh.visible: continue
		mesh.scale = Vector3(1.0, settings.height, settings.length)
		mesh.position = Vector3(0, anchor.y * (1 - settings.height), anchor.z * (1 - settings.length))
		for i in mesh.mesh.get_surface_count(): mesh.set_surface_override_material(i, material)

	_wind_pennants[mast] = {"instance": instance, "meshes": _meshes(instance), "players": _animation_players(instance)}

func _animation_players(node: Node) -> Array[AnimationPlayer]:
	var players: Array[AnimationPlayer] = []
	if node is AnimationPlayer: players.append(node)
	for child in node.get_children(): players.append_array(_animation_players(child))
	return players

func _process(_delta: float) -> void:
	_update_wind()

func _update_wind() -> void:
	var strength := clampf(wind_source.strength, 0.0, 1.0) if is_instance_valid(wind_source) else 0.0
	for mast in _wind_pennants:
		var entry: Dictionary = _wind_pennants[mast]
		if not is_instance_valid(entry.instance) or entry.instance.is_queued_for_deletion(): continue
		# Pennants trail along the ship; only flutter responds to wind strength.
		entry.instance.transform = Transform3D.IDENTITY
		for mesh in entry.meshes:
			if mesh.visible: mesh.scale.x = maxf(0.001, strength * 1.8)
		for player in entry.players:
			player.speed_scale = 0.0 if strength <= 0.001 or (is_instance_valid(wind_source) and wind_source.paused) else lerpf(0.35, 2.0, strength)

func apply(data: Dictionary) -> void:
	appearance = ShipAppearance.validate(data)
	if base == null: return
	_used_slots.clear()
	_wind_pennants.clear()
	if fittings == null:
		fittings = Node3D.new()
		fittings.name = "Fittings"
		add_child(fittings)
	var carving: bool = appearance.figurehead != "none"
	_set_named_visible(base, "Bowsprit", not carving)
	_set_named_visible(base, "BowSailOriginal", not carving)
	_set_named_visible(base, "BowSailFigurehead", carving)
	_set_named_visible(base, "sail-a", not appearance.main.enabled)
	_set_named_visible(base, "sail-b", not appearance.main.enabled)
	_set_named_visible(base, "flag-c", not appearance.pennants, true)
	for region in _timber_surfaces:
		if not appearance.paint:
			region.mesh.set_surface_override_material(region.surface, region.original)
		else:
			var paint := ShaderMaterial.new()
			paint.shader = TIMBER_SHADER
			paint.set_shader_parameter("palette", region.original.albedo_texture)
			paint.set_shader_parameter("paint", Color(appearance[region.region]))
			region.mesh.set_surface_override_material(region.surface, paint)
	_sail("main", appearance.main)
	_sail("secondary", appearance.main)
	if appearance.pennants:
		for mast in ["main", "fore", "aft"]: _flag(mast, appearance.main_flag)
	_add(appearance.figurehead, "Figurehead")
	_add(appearance.lamps, "Lanterns")
	_add(appearance.trophy, "SternTrophy")
	for id in ["banners", "bunting", "tassels"]:
		if appearance[id]:
			var decoration := _add(id, id.capitalize())
			# Reference stern rail: y=4.2, rear face z=-6.55; side hull x=+-2.2.
			match id:
				"banners": decoration.position = Vector3(0, 0.84, 0.15)
				"bunting":
					decoration.scale = Vector3(3.1 / 4.2, 1, 1)
					decoration.position = Vector3(0, 0.48, 0.21)
				"tassels":
					decoration.scale = Vector3(2.21 / 2.43, 1, 1)
					decoration.position = Vector3(0, 0.44, 0)
	for i in ShipAppearance.SLOTS.size():
		var prop := _add(appearance[ShipAppearance.SLOTS[i]], ShipAppearance.SLOTS[i])
		if prop: prop.position = PROP_POSITIONS[i]
	for old in fittings.get_children():
		if String(old.name) not in _used_slots:
			fittings.remove_child(old)
			old.queue_free()

	_update_wind()
