extends RefCounted

## Original, vertex-painted toy geometry, batched into one surface per object.
## UV2 identifies rigid parts for the chicken's vertex animation.

var _surface := SurfaceTool.new()


func _init() -> void:
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)


## Adds a primitive without retaining its nodes, materials or draw calls.
func append(
	mesh: Mesh,
	transform: Transform3D,
	color: Color,
	part := 0.0
) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var colors := PackedColorArray()
	if arrays[Mesh.ARRAY_COLOR] != null:
		colors = arrays[Mesh.ARRAY_COLOR]
	var normal_basis := transform.basis.inverse().transposed()
	for offset in range(0, indices.size(), 3):
		var a := vertices[indices[offset]]
		var b := vertices[indices[offset + 1]]
		var c := vertices[indices[offset + 2]]
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot(normals[indices[offset]]) < 0.0:
			normal = -normal
		_surface.set_normal((normal_basis * normal).normalized())
		_surface.set_uv(Vector2.ZERO)
		_surface.set_uv2(Vector2(part, 0.0))
		for corner in 3:
			var index := indices[offset + corner]
			_surface.set_color(color if colors.is_empty() else color * colors[index])
			_surface.add_vertex(transform * vertices[index])


## Dimensions are full extents, including for ellipsoids.
func box(
	at: Vector3, size: Vector3, color: Color,
	rotation := Vector3.ZERO, part := 0.0
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	append(mesh, Transform3D(Basis.from_euler(rotation), at), color, part)


func ellipsoid(
	at: Vector3, size: Vector3, color: Color,
	rotation := Vector3.ZERO, part := 0.0, segments := 12, rings := 6
) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = segments
	mesh.rings = rings
	append(
		mesh, Transform3D(Basis.from_euler(rotation).scaled(size), at), color, part
	)


func cylinder(
	at: Vector3, radius: float, height: float, color: Color,
	rotation := Vector3.ZERO, top_radius := -1.0, part := 0.0
) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	append(mesh, Transform3D(Basis.from_euler(rotation), at), color, part)


func beam(start: Vector3, end: Vector3, radius: float, color: Color) -> void:
	var direction := end - start
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius
	mesh.height = direction.length()
	mesh.radial_segments = 6
	var basis := Basis(Quaternion(Vector3.UP, direction.normalized()))
	append(mesh, Transform3D(basis, (start + end) * 0.5), color)


func torus(
	at: Vector3, inner: float, outer: float, color: Color,
	rotation := Vector3.ZERO
) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 16
	mesh.ring_segments = 6
	append(mesh, Transform3D(Basis.from_euler(rotation), at), color)


func triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	_surface.set_normal((b - a).cross(c - a).normalized())
	_surface.set_color(color)
	_surface.set_uv(Vector2.ZERO)
	_surface.set_uv2(Vector2.ZERO)
	# Godot's front faces are clockwise; preserve the intended outward normal.
	for vertex: Vector3 in [a, c, b]:
		_surface.add_vertex(vertex)


## An octagonal edge makes the farm read as a little wooden diorama.
## An optional world-space XZ opening leaves the bowl to supply its inner walls.
func plinth(
	at: Vector3, size: Vector3, bevel: float, color: Color,
	opening := PackedVector2Array()
) -> void:
	var outline := plinth_outline(Vector2(size.x, size.z), bevel)
	if not opening.is_empty() and opening.size() != outline.size():
		push_error("A plinth opening must have the same eight corners as its outline.")
		return
	for index in outline.size():
		var next := (index + 1) % outline.size()
		var a := at + Vector3(outline[index].x, size.y * 0.5, outline[index].y)
		var b := at + Vector3(outline[next].x, size.y * 0.5, outline[next].y)
		var c := a - Vector3.UP * size.y
		var d := b - Vector3.UP * size.y
		if opening.is_empty():
			triangle(at + Vector3.UP * size.y * 0.5, b, a, color)
		else:
			var inner_a := Vector3(opening[index].x, a.y, opening[index].y)
			var inner_b := Vector3(opening[next].x, a.y, opening[next].y)
			triangle(a, inner_a, inner_b, color)
			triangle(a, inner_b, b, color)
		triangle(a, b, c, color.darkened(0.10))
		triangle(b, d, c, color.darkened(0.10))


static func plinth_outline(size: Vector2, bevel: float) -> PackedVector2Array:
	var x := size.x * 0.5
	var z := size.y * 0.5
	return PackedVector2Array([
		Vector2(-x + bevel, -z), Vector2(x - bevel, -z),
		Vector2(x, -z + bevel), Vector2(x, z - bevel),
		Vector2(x - bevel, z), Vector2(-x + bevel, z),
		Vector2(-x, z - bevel), Vector2(-x, -z + bevel),
	])


func finish() -> ArrayMesh:
	_surface.index()
	return _surface.commit()


## One matte material can paint an entire farm without texture dependencies.
static func material(unshaded := false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.vertex_color_use_as_albedo = true
	result.vertex_color_is_srgb = true
	result.roughness = 0.92
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result
