class_name OceanMeshBuilder
extends RefCounted


static func build(extent: float, subdivisions: int, center_density: float) -> ArrayMesh:
	var axis := warped_axis(extent, subdivisions, center_density)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for z in axis:
		for x in axis:
			vertices.append(Vector3(x, 0.0, z))
			normals.append(Vector3.UP)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = grid_indices(axis.size())

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func warped_axis(extent: float, subdivisions: int, center_density: float) -> PackedFloat32Array:
	var axis := PackedFloat32Array()
	for i in subdivisions + 1:
		var u := lerpf(-1.0, 1.0, float(i) / subdivisions)
		axis.append(extent * warp(u, center_density))
	return axis


static func warp(u: float, center_density: float) -> float:
	return center_density * u + (1.0 - center_density) * u * u * u


static func center_spacing(extent: float, subdivisions: int, center_density: float) -> float:
	return extent * center_density * 2.0 / subdivisions


static func grid_indices(row_length: int) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for row in row_length - 1:
		for column in row_length - 1:
			var top_left := row * row_length + column
			var top_right := top_left + 1
			var bottom_left := top_left + row_length
			var bottom_right := bottom_left + 1
			indices.append_array([top_left, top_right, bottom_left, top_right, bottom_right, bottom_left])
	return indices
