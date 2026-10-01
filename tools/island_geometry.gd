extends RefCounted
const LAND_SCALE := 3.0
const SEABED_Y := -18.0
const LAND_LIFT := 2.8
const ISLANDS := ["food", "timber", "gold", "metal", "harbor-player", "harbor-enemy"]

static func enlarge(model: Node3D, id: String) -> void:
	model.position.y = LAND_LIFT
	var assembly := model.get_child(0)
	var dock_shift := 18.0 * (1.18 if id.begins_with("harbor") else 1.0)
	for node in assembly.get_children():
		if not node is Node3D: continue
		var label := str(node.name).to_lower()
		if label.begins_with("beach") or label.begins_with("wet sand") or label.begins_with("island ground"):
			node.position.x *= LAND_SCALE
			node.position.z *= LAND_SCALE
			node.scale.x *= LAND_SCALE
			node.scale.z *= LAND_SCALE
		elif "dock" in label or "mooring" in label or "structure-platform" in label:
			node.position.z += dock_shift
		elif label.begins_with("palm"):
			node.position.x *= 2.6
			node.position.z *= 2.6
	# Place additional trees at normal scale to break up the expanded coastline.
	var palms: Array = assembly.get_children().filter(func(n): return str(n.name).begins_with("palm"))
	for i in range(8):
		if palms.is_empty(): break
		var copy: Node3D = palms[i % palms.size()].duplicate()
		copy.name = "CoastalPalm%d" % i
		var angle := (float(i)+0.4)*TAU/8.0
		var radius := 19.0 * (1.18 if id.begins_with("harbor") else 1.0)
		copy.position = Vector3(cos(angle)*radius,1.3,sin(angle)*radius*0.72)
		assembly.add_child(copy)

	fit_ground_cover(assembly)
	align_docks(assembly)
	settle_trees(assembly)

static func foundation(body: StaticBody3D, model: Node3D) -> void:
	var shelf: MeshInstance3D
	for n in model.find_children("*", "MeshInstance3D",true,false):
		if str(n.name).begins_with("Wet sand shelf"): shelf = n; break
	assert(shelf != null)
	var faces: PackedVector3Array = (body.global_transform.affine_inverse()*shelf.global_transform) * shelf.mesh.get_faces()
	var bottom := INF
	for v in faces: bottom = minf(bottom,v.y)
	var unique := {}
	for v in faces:
		if v.y <= bottom+0.005:unique[Vector2(v.x,v.z)] = true
	var ring: Array = unique.keys()
	ring.sort_custom(func(a: Vector2,b: Vector2): return atan2(a.y,a.x)<atan2(b.y,b.x))
	assert(ring.size()>=8)
	var heights := [bottom+0.025,-2.6,-8.0,SEABED_Y-0.2]
	var scales := [1.0,1.055,1.24,1.6]
	var colors := [Color("c9b58d"),Color("a49776"),Color("64736f"),Color("485c65")]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in range(3):
		for i in range(ring.size()):
			var j := (i+1)%ring.size()
			var a := Vector3(ring[i].x*scales[level],heights[level],ring[i].y*scales[level])
			var b := Vector3(ring[j].x*scales[level],heights[level],ring[j].y*scales[level])
			var c := Vector3(ring[j].x*scales[level+1],heights[level+1],ring[j].y*scales[level+1])
			var d := Vector3(ring[i].x*scales[level+1],heights[level+1],ring[i].y*scales[level+1])
			triangle(st,a,b,c,colors[level],colors[level],colors[level+1])
			triangle(st,a,c,d,colors[level],colors[level+1],colors[level+1])
	# Closed underside connects to the seabed even when inspected from below.
	for i in range(ring.size()):
		var j := (i+1)%ring.size()
		triangle(st,Vector3(0,heights[3],0),Vector3(ring[i].x*scales[3],heights[3],ring[i].y*scales[3]),Vector3(ring[j].x*scales[3],heights[3],ring[j].y*scales[3]),colors[3],colors[3],colors[3])
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(material)
	var mesh := MeshInstance3D.new()
	mesh.name = "UnderwaterFoundation"
	mesh.mesh = st.commit()
	body.add_child(mesh)
	mesh.owner = body
	var collider := CollisionShape3D.new()
	collider.name = "FoundationCollision"
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(mesh.mesh.get_faces())
	collider.shape = shape
	body.add_child(collider)
	collider.owner = body
	body.set_meta("land_scale", LAND_SCALE)
	body.set_meta("land_lift", LAND_LIFT)
	body.set_meta("foundation_depth", SEABED_Y-0.2)
	# Extend the pier piles into the ground instead of leaving their feet suspended.
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("665243")
	for dock: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if "Dock • pier" not in str(dock.name) and not str(dock.name).begins_with("structure-platform-dock"):continue
		var box: AABB = (body.global_transform.affine_inverse()*dock.global_transform)*dock.mesh.get_aabb()
		for side in [-1,1]:
			var at := box.get_center()
			at.x += side*box.size.x*0.37
			at.y = (SEABED_Y+box.position.y)*0.5
			var height := box.position.y-SEABED_Y+0.12
			var pile := MeshInstance3D.new()
			pile.name = "DeepPierPile"
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.10
			cylinder.bottom_radius = 0.13
			cylinder.height = height
			cylinder.radial_segments = 8
			pile.mesh = cylinder
			pile.material_override = wood
			pile.position = at
			body.add_child(pile)
			pile.owner = body
			var col := CollisionShape3D.new()
			col.name = "PierPileCollision"
			var solid := CylinderShape3D.new()
			solid.radius = 0.13
			solid.height = height
			col.shape = solid
			col.position = at
			body.add_child(col)
			col.owner = body

static func triangle(st: SurfaceTool, a: Vector3,b: Vector3,c: Vector3,ca: Color,cb: Color,cc: Color) -> void:
	var normal := (c-a).cross(b-a).normalized()
	var center := (a+b+c)/3.0
	if normal.dot(Vector3(center.x,0,center.z)) < 0: normal = -normal
	st.set_normal(normal)
	st.set_color(ca);st.add_vertex(a)
	st.set_color(cb);st.add_vertex(b)
	st.set_color(cc);st.add_vertex(c)

static func seabed() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Seabed"
	body.position.y = SEABED_Y-1.0
	var mesh := MeshInstance3D.new()
	mesh.name = "SandyGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(3200,3200)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("7d8d87")
	material.roughness = 1
	plane.material = material
	mesh.mesh = plane
	mesh.position.y = 1.0
	body.add_child(mesh)
	mesh.owner = body
	var collider := CollisionShape3D.new()
	collider.name = "GroundCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(3200,2,3200)
	collider.shape = shape
	body.add_child(collider)
	collider.owner = body
	return body

# Use the sand plateau itself as the grass boundary rather than scaling an
# unrelated patch silhouette. All coordinates here are assembly-local.
static func local_faces(mesh: MeshInstance3D, space: Node3D) -> PackedVector3Array:
	return (space.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_faces()

static func ground_faces(space: Node3D) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for mesh: MeshInstance3D in space.find_children("*","MeshInstance3D",true,false):
		var label := str(mesh.name)
		if label.begins_with("Beach") or label.begins_with("Island ground cover"):
			faces.append_array(local_faces(mesh,space))
	return faces

static func surface_height(faces: PackedVector3Array, x: float,z: float) -> float:
	var highest := -INF
	var origin := Vector3(x,100,z)
	for i in range(0,faces.size(),3):
		var hit = Geometry3D.ray_intersects_triangle(origin,Vector3.DOWN,faces[i],faces[i+1],faces[i+2])
		if hit != null: highest = maxf(highest,hit.y)
	return highest

static func fit_ground_cover(assembly: Node3D) -> void:
	var beach: MeshInstance3D
	var cover: MeshInstance3D
	for node in assembly.get_children():
		if str(node.name).begins_with("Beach"): beach = node
		if str(node.name).begins_with("Island ground cover"): cover = node
	assert(beach != null and cover != null)
	var faces := local_faces(beach,assembly)
	var top := -INF
	for point in faces: top = maxf(top,point.y)
	var unique := {}
	for point in faces:
		if point.y > top-0.001: unique[Vector2(point.x,point.z)] = true
	var ring: Array = unique.keys()
	ring.sort_custom(func(a: Vector2,b: Vector2): return atan2(a.y,a.x)<atan2(b.y,b.x))
	var outline := PackedVector2Array(ring)
	var inset := Geometry2D.offset_polygon(outline,-1.25)
	assert(not inset.is_empty())
	var polygon: PackedVector2Array = inset[0]
	var indices := Geometry2D.triangulate_polygon(polygon)
	assert(not indices.is_empty())
	var uv: Vector2 = cover.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV][0]
	var material := cover.get_active_material(0)
	var old_top := (assembly.global_transform.affine_inverse()*cover.global_transform*cover.mesh.get_aabb()).end.y
	var height := top+0.012
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	for index in indices:
		st.set_normal(Vector3.UP)
		st.set_uv(uv)
		st.add_vertex(Vector3(polygon[index].x,height,polygon[index].y))
	cover.transform = Transform3D.IDENTITY
	cover.mesh = st.commit()
	assembly.set_meta("ground_height",height)
	for node in assembly.get_children():
		if not node is Node3D: continue
		var label := str(node.name).to_lower()
		if label.begins_with("beach") or label.begins_with("wet sand") or label.begins_with("island ground") or "foam" in label or "dock" in label or "mooring" in label or "structure-platform" in label: continue
		node.position.y += height-old_top

static func settle_trees(assembly: Node3D) -> void:
	var faces := ground_faces(assembly)
	for node in assembly.get_children():
		if not node is MeshInstance3D: continue
		var label := str(node.name).to_lower()
		if not label.begins_with("palm") and not label.begins_with("coastalpalm"):continue
		var height := surface_height(faces,node.position.x,node.position.z)
		assert(is_finite(height))
		var bounds: AABB = (assembly.global_transform.affine_inverse()*node.global_transform)*node.mesh.get_aabb()
		node.position.y += height-bounds.position.y-0.015
		node.set_meta("grounded_tree",true)

static func align_docks(assembly: Node3D) -> void:
	var faces := ground_faces(assembly)
	var anchors: Array = []
	for node: Node3D in assembly.get_children():
		if not str(node.name).begins_with("Dock • pier 0"):continue
		var bounds: AABB = (assembly.global_transform.affine_inverse()*node.global_transform)*node.mesh.get_aabb()
		var center := bounds.get_center()
		var deck_y := surface_height(local_faces(node,assembly),center.x,center.z)
		var last_z := 0.0
		for step in range(1000):
			var z := step*0.05
			if surface_height(faces,center.x,z) >= deck_y-0.08: last_z = z
		anchors.append(Vector2(center.x,last_z-bounds.position.z-0.25))
	for node: Node3D in assembly.get_children():
		var label := str(node.name).to_lower()
		if "dock" not in label and "mooring" not in label and "structure-platform" not in label: continue
		var best := Vector2(INF,0)
		for anchor: Vector2 in anchors:
			if absf(anchor.x-node.position.x)<absf(best.x-node.position.x): best = anchor
		if is_finite(best.x): node.position.z += best.y

static func place_detail(body: Node3D, detail: Node3D) -> void:
	var faces := ground_faces(body)
	var box: AABB = detail.get_meta("visual_bounds")
	# Keep the whole building footprint on level ground, including near coves.
	for attempt in range(30):
		var low := INF
		var high := -INF
		for point in [Vector2.ZERO,Vector2(box.position.x,box.position.z),Vector2(box.end.x,box.position.z),Vector2(box.end.x,box.end.z),Vector2(box.position.x,box.end.z)]:
			var height := surface_height(faces,detail.position.x+point.x,detail.position.z+point.y)
			low = minf(low,height)
			high = maxf(high,height)
		if is_finite(low) and high-low<0.025:
			detail.position.y = high-box.position.y-0.015
			detail.set_meta("grounded_detail",true)
			return
		detail.position.x *= 0.96
		detail.position.z *= 0.96
	assert(false,"Unable to seat " + str(detail.name))
