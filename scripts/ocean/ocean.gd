@tool
class_name Ocean
extends Node3D

const GROUP := &"ocean"
const GENERATED_PREFIX := "_gen"
const CULL_MARGIN_PER_METER_OF_WAVE := 2.0
const MIN_WAVE_HEIGHT_SIGMA := 0.001
const WAVE_GROUPS := {
	"Wave": "height_waves",
	"UVWave": "uv_waves",
}
const WAVE_PROPERTIES := {
	"Steepnesses": "steepness",
	"Amplitudes": "amplitude",
	"DirectionsDegrees": "direction_degrees",
	"Frequencies": "frequency",
	"Speeds": "speed",
	"Phases": "phase_degrees",
}

@export var water_material: ShaderMaterial:
	set(value):
		water_material = value
		_rebuild()
@export var wave_set: OceanWaveSet:
	set(value):
		wave_set = value
		_push_wave_parameters()

@export_group("Geometry")
@export_range(2, 200) var outermost_resolution := 10:
	set(value):
		outermost_resolution = value
		_rebuild()
@export_range(1, 10) var levels_of_detail := 5:
	set(value):
		levels_of_detail = value
		_rebuild()
@export var unit_size := 2.0:
	set(value):
		unit_size = value
		_rebuild()
@export var far_edge := 4000.0:
	set(value):
		far_edge = value
		_rebuild()

@export_group("Fade")
@export_range(0.0, 1.0) var wave_fade_softness := 0.6
@export var focus_max_distance := 120.0

var height_sampler: OceanHeightSampler
var wave_time := 0.0

var _water: ShaderMaterial
var _surface_root: Node3D
var _focus := Vector3.ZERO

var region_width: float:
	get:
		return outermost_resolution * unit_size * 2 ** (levels_of_detail - 1)

var total_width: float:
	get:
		return region_width * (2 * levels_of_detail - 1)

var snap_unit: float:
	get:
		return unit_size * 2 ** (levels_of_detail - 1)

var wave_fade_far: float:
	get:
		return total_width / 2.0 - snap_unit


func _ready() -> void:
	height_sampler = OceanHeightSampler.new()
	height_sampler.bind(self)
	add_child(height_sampler)
	add_to_group(GROUP)
	_rebuild()


func _process(delta: float) -> void:
	wave_time += delta
	RenderingServer.global_shader_parameter_set(&"ocean_time", wave_time)
	_track_camera()
	if Engine.is_editor_hint():
		_push_wave_parameters()


func surface_offset_at(rest_position: Vector2) -> Vector3:
	if wave_set == null:
		return Vector3.ZERO
	return wave_set.displacement_at(rest_position, wave_time) * _wave_fade_at(rest_position)


func focus_point(camera: Camera3D) -> Vector3:
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var sea_level := global_position.y
	var reach := 0.0
	if forward.y < 0.0:
		reach = minf((sea_level - origin.y) / forward.y, focus_max_distance)
	var focus := origin + forward * maxf(reach, 0.0)
	return Vector3(focus.x, sea_level, focus.z)


func generated_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if _surface_root:
		meshes.assign(_surface_root.get_children())
	return meshes


func surface_center() -> Vector3:
	return _surface_root.global_position if _surface_root else global_position


func water() -> ShaderMaterial:
	return _water


func _rebuild() -> void:
	if not is_inside_tree() or water_material == null:
		return
	_water = water_material.duplicate()
	_build_meshes()
	_push_fade_parameters()
	_push_wave_parameters()


func _track_camera() -> void:
	var camera := _active_camera()
	if camera == null:
		return
	var focus := focus_point(camera)
	_set_focus(focus)
	if _surface_root:
		_surface_root.global_position = Vector3(snappedf(focus.x, snap_unit), global_position.y, snappedf(focus.z, snap_unit))


func _set_focus(focus: Vector3) -> void:
	_focus = focus
	RenderingServer.global_shader_parameter_set(&"ocean_focus", focus)


func _active_camera() -> Camera3D:
	if not Engine.is_editor_hint():
		return get_viewport().get_camera_3d()
	var editor := Engine.get_singleton(&"EditorInterface")
	return editor.get_editor_viewport_3d(0).get_camera_3d() if editor else null


func _wave_fade_at(rest_position: Vector2) -> float:
	var distance := rest_position.distance_to(Vector2(_focus.x, _focus.z))
	return smoothstep(wave_fade_far, wave_fade_far * (1.0 - wave_fade_softness), distance)


func _build_meshes() -> void:
	_ensure_surface_root()
	for mesh_instance in generated_meshes():
		_surface_root.remove_child(mesh_instance)
		mesh_instance.queue_free()
	var limit := levels_of_detail - 1
	for z in range(-limit, limit + 1):
		for x in range(-limit, limit + 1):
			_add_near_plane(x, z)
	_add_far_rings()


func _add_near_plane(x: int, z: int) -> void:
	var shell := maxi(absi(x), absi(z))
	var resolution := outermost_resolution * 2 ** (levels_of_detail - shell - 1)
	var plane_unit_size := unit_size * 2 ** shell
	var mesh := OceanMeshGenerator.build_plane(resolution, plane_unit_size, _seams_for(x, z, shell))
	_add_mesh(mesh, "%s_plane_%d_%d" % [GENERATED_PREFIX, x, z], Vector3(x, 0, z) * region_width)


func _seams_for(x: int, z: int, shell: int) -> int:
	var seams := 0
	if -z >= shell:
		seams |= OceanMeshGenerator.Seam.UP
	if z >= shell:
		seams |= OceanMeshGenerator.Seam.DOWN
	if -x >= shell:
		seams |= OceanMeshGenerator.Seam.LEFT
	if x >= shell:
		seams |= OceanMeshGenerator.Seam.RIGHT
	return seams


func _add_far_rings() -> void:
	var near := total_width / 2.0
	if far_edge <= near:
		return
	var middle := minf(near * 3.0, (near + far_edge) / 2.0)
	_add_mesh(OceanMeshGenerator.build_ring(near, middle, region_width), GENERATED_PREFIX + "_ring_mid")
	_add_mesh(OceanMeshGenerator.build_ring(middle, far_edge, region_width), GENERATED_PREFIX + "_ring_far")


func _add_mesh(mesh: Mesh, mesh_name: String, mesh_position := Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = mesh
	instance.position = mesh_position
	instance.extra_cull_margin = _max_wave_height() * CULL_MARGIN_PER_METER_OF_WAVE + unit_size
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.material_override = _water
	_surface_root.add_child(instance)


func _ensure_surface_root() -> void:
	if _surface_root:
		return
	_surface_root = Node3D.new()
	_surface_root.name = GENERATED_PREFIX + "_surface"
	add_child(_surface_root)


func _max_wave_height() -> float:
	if wave_set == null:
		return 0.0
	var waves := wave_set.shader_waves(wave_set.height_waves)
	var total := 0.0
	for wave in waves:
		total += absf(wave.steepness) * maxf(1.0, absf(wave.amplitude))
	return total / maxf(1.0, waves.size())


func _push_fade_parameters() -> void:
	for feature in ["foam_fade", "vertex_wave_fade"]:
		_set_fade(feature, wave_fade_far, wave_fade_softness)


func _set_fade(prefix: String, far: float, softness: float) -> void:
	_water.set_shader_parameter(prefix + "_max", far)
	_water.set_shader_parameter(prefix + "_min", far * (1.0 - softness))


func _push_wave_parameters() -> void:
	if _water == null:
		return
	_push_whitecap_parameters()
	for prefix in WAVE_GROUPS:
		var waves: Array[GerstnerWave] = []
		if wave_set:
			waves = wave_set.shader_waves(wave_set.get(WAVE_GROUPS[prefix]))
		_water.set_shader_parameter(prefix + "Count", waves.size())
		for suffix in WAVE_PROPERTIES:
			_water.set_shader_parameter(prefix + suffix, _collect(waves, WAVE_PROPERTIES[suffix]))


func _push_whitecap_parameters() -> void:
	var strength := wave_set.whitecap_strength if wave_set else 0.0
	var sigma := wave_set.height_sigma() if wave_set else 0.0
	_water.set_shader_parameter("whitecap_strength", strength)
	_water.set_shader_parameter("wave_height_sigma", maxf(sigma, MIN_WAVE_HEIGHT_SIGMA))


func _collect(waves: Array[GerstnerWave], property: String) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	for wave in waves:
		values.append(wave.get(property))
	return values
