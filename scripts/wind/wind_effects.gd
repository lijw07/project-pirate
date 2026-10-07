class_name WindEffects
extends Node3D

## Visual wind only: no sailing forces or sea-state changes.
## Heading is the direction air travels toward, clockwise from north (-Z).
enum Preset { CALM, BREEZE, STRONG, GUSTS }
const STRENGTHS = [0.0, 0.3, 0.78, 0.5]

@export var ocean: Ocean
@export var ship: Node3D
@export var camera: Camera3D
@export var preset: Preset = Preset.BREEZE
@export_range(0.0, 360.0, 1.0) var heading := 90.0
@export var show_trails := true
@export var paused := false
@export var pennant_anchor := Vector3(0, 8.84, 0.68)

var strength := 0.3
var time := 0.0
var travel := 0.0
var ribbons := ImmediateMesh.new()
var pennant := ImmediateMesh.new()
var ribbon_node: MeshInstance3D
var pennant_node: MeshInstance3D
var seeds: Array[Vector4] = []


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ribbon_node = MeshInstance3D.new()
	ribbon_node.mesh = ribbons
	ribbon_node.material_override = mat
	ribbon_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ribbon_node)
	pennant_node = MeshInstance3D.new()
	pennant_node.mesh = pennant
	var cloth := mat.duplicate()
	cloth.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	pennant_node.material_override = cloth
	add_child(pennant_node)
	var rng := RandomNumberGenerator.new()
	rng.seed = 98173
	for i in range(74):
		seeds.append(Vector4(rng.randf_range(-55,55), rng.randf_range(-42,42), rng.randf_range(1.6,7.5), rng.randf()))


func flow_direction() -> Vector3:
	var angle := deg_to_rad(heading)
	return Vector3(sin(angle), 0, -cos(angle))


func advance(delta: float) -> void:
	if paused:
		return
	time += delta
	var target: float = STRENGTHS[preset]
	if preset == Preset.GUSTS:
		target = 0.25 + 0.75 * pow(0.5 + 0.5 * sin(time * 1.25), 3.0)
	strength = lerpf(strength, target, 1.0 - exp(-delta * 2.8))
	if strength < 0.001:
		strength = 0.0
	travel += (3.0 + strength * 20.0) * delta


func refresh() -> void:
	if not is_instance_valid(ocean) or not is_instance_valid(camera):
		ribbons.clear_surfaces()
		pennant.clear_surfaces()
		return
	draw_wind(flow_direction())
	if is_instance_valid(ship):
		draw_pennant(flow_direction())
	else:
		pennant.clear_surfaces()


func _process(delta: float) -> void:
	advance(delta)
	refresh()


func draw_wind(flow: Vector3) -> void:
	ribbons.clear_surfaces()
	if not show_trails or strength < 0.004: return
	var side := Vector3(-flow.z,0,flow.x)
	var camera_up := camera.global_basis.y
	ribbons.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seeds.size():
		var s := seeds[i]
		var presence := clampf((strength*64.0+4.0-float(i))/6.0,0.0,1.0)
		if presence <= 0: continue
		var phase := fposmod(time*(0.23+s.w*0.13)+s.w,1.0)
		var fade := smoothstep(0.0,0.18,phase)*(1.0-smoothstep(0.65,1.0,phase))*presence
		var along := fposmod(s.x+travel*(0.85+s.w*0.25)+55.0,110.0)-55.0
		var base := global_position + flow*along+side*s.y
		base.y = ocean.height_sampler.height_at(Vector2(base.x,base.z))+s.z
		var length := 3.0+strength*8.0+s.w*3.0
		for j in range(20):
			var u := float(j)/20.0
			var v := float(j+1)/20.0
			var a := trail_point(base,flow,side,u,length,s.w,i)
			var b := trail_point(base,flow,side,v,length,s.w,i)
			var wa := sin(u*PI)*(0.028+strength*0.04)
			var wb := sin(v*PI)*(0.028+strength*0.04)
			var ca := Color(0.92,0.98,1.0,fade*(0.42+0.35*strength)*sin(u*PI))
			var cb := Color(ca,fade*(0.42+0.35*strength)*sin(v*PI))
			vertex(ribbons,a-camera_up*wa,ca)
			vertex(ribbons,a+camera_up*wa,ca)
			vertex(ribbons,b+camera_up*wb,cb)
			vertex(ribbons,a-camera_up*wa,ca)
			vertex(ribbons,b+camera_up*wb,cb)
			vertex(ribbons,b-camera_up*wb,cb)
	ribbons.surface_end()

func trail_point(base: Vector3, flow: Vector3, side: Vector3, u: float, length: float, seed_value: float, index: int) -> Vector3:
	var p := base + flow*(u-0.5)*length
	p += side*sin(u*TAU+seed_value*TAU+time*0.6)*0.32
	p.y += sin(u*PI+seed_value*TAU)*0.45
	# An occasional open curl gives the air a hand-drawn, stylized gesture.
	if index%7 == 0:
		p += flow*sin(u*TAU)*length*0.13
		p.y += (1.0-cos(u*TAU))*0.85
	return p

func vertex(mesh: ImmediateMesh, world_position: Vector3, color: Color) -> void:
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(to_local(world_position))

func draw_pennant(flow: Vector3) -> void:
	pennant.clear_surfaces()
	pennant.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var anchor := ship.to_global(pennant_anchor)
	for j in range(18):
		var u := float(j)/18.0
		var v := float(j+1)/18.0
		var a := cloth_point(anchor,flow,u)
		var b := cloth_point(anchor,flow,v)
		var width_a := (1.0-u)*0.65
		var width_b := (1.0-v)*0.65
		var color := Color("eec66f")
		vertex(pennant,a,color)
		vertex(pennant,a-Vector3.UP*width_a,color)
		vertex(pennant,b-Vector3.UP*width_b,color)
		vertex(pennant,a,color)
		vertex(pennant,b-Vector3.UP*width_b,color)
		vertex(pennant,b,color)
	pennant.surface_end()

func cloth_point(anchor: Vector3, flow: Vector3, u: float) -> Vector3:
	var side := Vector3(-flow.z,0,flow.x)
	return anchor + flow*u*(0.2+2.8*strength) - Vector3.UP*u*(1.0-strength)*1.4 + side*sin(u*10-time*(3+strength*15))*u*strength*0.2
