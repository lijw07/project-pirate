class_name OceanMeshGenerator
extends RefCounted

enum Seam { UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8 }

const SEAM_CORNERS := {
	Seam.UP: [0, 1],
	Seam.DOWN: [2, 3],
	Seam.LEFT: [0, 3],
	Seam.RIGHT: [1, 2],
}


static func build_plane(resolution: int, unit_size: float, seams: int) -> ArrayMesh:
	var surface := _begin_surface()
	var midpoint := Vector3(resolution, 0.0, resolution) / 2.0
	for z in resolution:
		for x in resolution:
			var vertices := PackedVector3Array()
			var uvs := PackedVector2Array()
			for corner in _welded_corners(x, z, resolution, seams):
				vertices.append((Vector3(corner.x, 0.0, corner.y) - midpoint) * unit_size)
				uvs.append(Vector2(corner) / float(resolution))
			surface.add_triangle_fan(vertices, uvs)
	return _commit(surface)


static func build_ring(near: float, far: float, uv_scale: float) -> ArrayMesh:
	var surface := _begin_surface()
	var inner := [Vector2(-near, -near), Vector2(near, -near), Vector2(near, near), Vector2(-near, near)]
	var outer := [Vector2(-far, -far), Vector2(far, -far), Vector2(far, far), Vector2(-far, far)]
	for side in 4:
		var next := (side + 1) % 4
		var vertices := PackedVector3Array()
		var uvs := PackedVector2Array()
		for corner: Vector2 in [outer[side], outer[next], inner[next], inner[side]]:
			vertices.append(Vector3(corner.x, 0.0, corner.y))
			uvs.append(corner / uv_scale - Vector2(0.5, 0.5))
		surface.add_triangle_fan(vertices, uvs)
	return _commit(surface)


static func _begin_surface() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface


static func _commit(surface: SurfaceTool) -> ArrayMesh:
	surface.generate_normals()
	surface.index()
	return surface.commit()


static func _welded_corners(x: int, z: int, resolution: int, seams: int) -> Array[Vector2i]:
	var corners: Array[Vector2i] = [
		Vector2i(x, z), Vector2i(x + 1, z), Vector2i(x + 1, z + 1), Vector2i(x, z + 1)
	]
	var on_edge := {
		Seam.UP: z == 0,
		Seam.DOWN: z == resolution - 1,
		Seam.LEFT: x == 0,
		Seam.RIGHT: x == resolution - 1,
	}
	for seam in SEAM_CORNERS:
		if seams & seam and on_edge[seam]:
			for index in SEAM_CORNERS[seam]:
				corners[index] = Vector2i(corners[index].x - corners[index].x % 2, corners[index].y - corners[index].y % 2)
	return corners
