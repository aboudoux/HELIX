extends RefCounted

const FINISH := preload("res://missions/lunar_escape/finishes.gd")
static var boxes: Dictionary = {}


static func bevel(parent: Node3D, point: Vector3, size: Vector3, radius: float, material: Material, solid := false) -> MeshInstance3D:
	var half := size * 0.5
	radius = clampf(radius, 0.001, minf(half.x, minf(half.y, half.z)) * 0.94)
	var key := Vector4(size.x, size.y, size.z, radius)
	if not boxes.has(key):
		boxes[key] = rounded_box(half, radius)
	var visual := MeshInstance3D.new()
	visual.mesh = boxes[key]
	visual.material_override = FINISH.material(material)
	visual.position = point
	parent.add_child(visual)
	if solid:
		collision_box(visual, Vector3.ZERO, size)
	return visual


static func collision_box(parent: Node3D, point: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.position = point
	body.add_child(collider)
	parent.add_child(body)


static func model_collision(model: Node3D) -> void:
	var bounds := AABB()
	var inverse := model.global_transform.affine_inverse()
	for part in model.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null or not part.is_visible_in_tree():
			continue
		var local_bounds: AABB = (inverse * part.global_transform) * part.get_aabb()
		bounds = local_bounds if not bounds.has_volume() else bounds.merge(local_bounds)
	if bounds.has_volume():
		collision_box(model, bounds.get_center(), bounds.size)


static func rounded_box(half: Vector3, radius: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var core := half - Vector3.ONE * radius
	for normal in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var u: Vector3 = Vector3.FORWARD if absf(normal.x) > 0.5 else Vector3.RIGHT
		var v: Vector3 = normal.cross(u)
		var w: float = half.dot(u.abs())
		var h: float = half.dot(v.abs())
		var xs := edge_samples(w, radius)
		var ys := edge_samples(h, radius)
		var plane: Vector3 = normal * half.dot(normal.abs())
		for j in range(ys.size() - 1):
			for i in range(xs.size() - 1):
				for corner in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					var a: float = xs[i + corner.x]
					var b: float = ys[j + corner.y]
					var box: Vector3 = plane + u * a + v * b
					var center := box.clamp(-core, core)
					var direction := (box - center).normalized()
					surface.set_normal(direction)
					surface.set_uv(Vector2((a + w) / (2.0 * w), (b + h) / (2.0 * h)))
					surface.add_vertex(center + direction * radius)
	surface.index()
	return surface.commit()


static func edge_samples(half_width: float, radius: float) -> PackedFloat32Array:
	return PackedFloat32Array([-half_width, -half_width + radius * 0.5, -half_width + radius,
		half_width - radius, half_width - radius * 0.5, half_width])


static func rod(parent: Node3D, start: Vector3, end: Vector3, radius: float, material: Material, sides := 12) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(end)
	mesh.radial_segments = sides
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = FINISH.material(material)
	instance.position = (start + end) * 0.5
	instance.basis = Basis(Quaternion(Vector3.UP, start.direction_to(end)))
	parent.add_child(instance)
	return instance
