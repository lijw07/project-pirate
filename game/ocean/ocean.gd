@tool
class_name Ocean
extends Node3D

const GROUP := &"ocean"
const SURFACE_CULL_MARGIN := 20.0
const MAX_CALM_ZONES := 16
const MAX_HULL_MASKS := 16

@export var wave_settings: WaveSettings:
	set(value):
		_disconnect_wave_signals()
		wave_settings = value
		_connect_wave_signals()
		_apply_waves()
@export var material: ShaderMaterial:
	set(value):
		material = value
		_pushed_parameters.clear()
		_apply_material()
		_apply_waves()
@export_range(100.0, 10000.0, 10.0, "suffix:m") var extent := 1600.0:
	set(value):
		extent = value
		_rebuild_surface()
@export_range(16, 512, 1) var subdivisions := 220:
	set(value):
		subdivisions = value
		_rebuild_surface()
@export_range(0.01, 1.0, 0.01) var center_density := 0.07:
	set(value):
		center_density = value
		_rebuild_surface()
@export_range(0.0, 1.0, 0.01) var calm_residual := 0.15
@export var follow_active_camera := true

var time := 0.0
var _surface: MeshInstance3D
var _calm_zones: Array[CalmZone] = []
var _pushed_parameters := {}


func _ready() -> void:
	add_to_group(GROUP)
	_surface = MeshInstance3D.new()
	_surface.name = "Surface"
	_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_surface, false, Node.INTERNAL_MODE_FRONT)
	_rebuild_surface()
	_apply_material()
	_apply_waves()


func _process(delta: float) -> void:
	time += delta
	if _surface == null:
		return
	_surface.set_instance_shader_parameter(&"wave_time", time)
	if follow_active_camera and not Engine.is_editor_hint():
		_follow(get_viewport().get_camera_3d())
	_refresh_calm_zones()
	_refresh_hull_masks()


func height_at(world_position: Vector3) -> float:
	if wave_settings == null:
		return global_position.y
	var point := Vector2(world_position.x, world_position.z)
	return global_position.y + WaveSettings.solve_height(point, surface_offset)


func surface_offset(point: Vector2) -> Vector3:
	return wave_settings.displacement(point, time) * wave_scale_at(point)


func wave_scale_at(point: Vector2) -> float:
	var scale := 1.0
	for zone in _calm_zones:
		if is_instance_valid(zone):
			scale = minf(scale, zone.wave_scale_at(point, calm_residual))
	return scale


func snap_step() -> float:
	return OceanMeshBuilder.center_spacing(extent, subdivisions, center_density)


func _follow(camera: Camera3D) -> void:
	if camera == null:
		return
	var step := snap_step()
	var target := camera.global_position.snapped(Vector3(step, 0.0, step))
	_surface.global_position = Vector3(target.x, global_position.y, target.z)


func _refresh_calm_zones() -> void:
	_calm_zones.clear()
	var packed := PackedVector4Array()
	for zone: CalmZone in get_tree().get_nodes_in_group(CalmZone.GROUP):
		if _calm_zones.size() == MAX_CALM_ZONES:
			break
		_calm_zones.append(zone)
		packed.append(zone.to_shader_vector())
	_push_parameter(&"calm_zone_count", packed.size())
	packed.resize(MAX_CALM_ZONES)
	_push_parameter(&"calm_zones", packed)
	_push_parameter(&"calm_residual", calm_residual)


func _refresh_hull_masks() -> void:
	var masks := _nearest_hull_masks()
	var frames := PackedVector4Array()
	var sizes := PackedVector4Array()
	for mask in masks:
		frames.append(mask.to_shader_frame())
		sizes.append(mask.to_shader_size())
	_push_parameter(&"hull_mask_count", masks.size())
	frames.resize(MAX_HULL_MASKS)
	sizes.resize(MAX_HULL_MASKS)
	_push_parameter(&"hull_mask_frames", frames)
	_push_parameter(&"hull_mask_sizes", sizes)


func _nearest_hull_masks() -> Array[HullWaterMask]:
	var masks: Array[HullWaterMask] = []
	masks.assign(get_tree().get_nodes_in_group(HullWaterMask.GROUP))
	if masks.size() <= MAX_HULL_MASKS:
		return masks
	var origin := _surface.global_position
	masks.sort_custom(func(a: HullWaterMask, b: HullWaterMask) -> bool:
		return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
	return masks.slice(0, MAX_HULL_MASKS)


func _push_parameter(parameter: StringName, value: Variant) -> void:
	if material == null or _pushed_parameters.get(parameter) == value:
		return
	_pushed_parameters[parameter] = value
	material.set_shader_parameter(parameter, value)


func _rebuild_surface() -> void:
	if _surface == null:
		return
	var mesh := OceanMeshBuilder.build(extent, subdivisions, center_density)
	var height := _max_wave_height() + SURFACE_CULL_MARGIN
	mesh.custom_aabb = AABB(Vector3(-extent, -height, -extent), Vector3(extent * 2.0, height * 2.0, extent * 2.0))
	_surface.mesh = mesh


func _apply_material() -> void:
	if _surface != null:
		_surface.material_override = material


func _apply_waves() -> void:
	if material == null or wave_settings == null:
		return
	material.set_shader_parameter(&"waves", wave_settings.to_shader_array())
	material.set_shader_parameter(&"wave_count", wave_settings.active_waves().size())
	material.set_shader_parameter(&"wave_amplitude", wave_settings.max_amplitude())


func _max_wave_height() -> float:
	return wave_settings.max_amplitude() if wave_settings != null else 0.0


func _on_waves_changed() -> void:
	_disconnect_wave_signals()
	_connect_wave_signals()
	_apply_waves()


func _connect_wave_signals() -> void:
	if wave_settings == null:
		return
	wave_settings.changed.connect(_on_waves_changed)
	for wave in wave_settings.waves:
		if wave != null:
			wave.changed.connect(_apply_waves)


func _disconnect_wave_signals() -> void:
	if wave_settings == null:
		return
	if wave_settings.changed.is_connected(_on_waves_changed):
		wave_settings.changed.disconnect(_on_waves_changed)
	for wave in wave_settings.waves:
		if wave != null and wave.changed.is_connected(_apply_waves):
			wave.changed.disconnect(_apply_waves)
