extends RefCounted
## Empreinte indépendante des modèles : formes et carte de vol réellement utilisées.


static func snapshot(arena: Node3D) -> Array:
	var records: Array = []
	for collider in arena.find_children("*", "CollisionShape3D", true, false):
		var shape: Shape3D = collider.shape
		var body: CollisionObject3D = collider.get_parent()
		var transform: Transform3D = collider.global_transform
		var values: Array = []
		for vector in [transform.basis.x, transform.basis.y, transform.basis.z, transform.origin]:
			values.append_array([vector.x, vector.y, vector.z])
		var dimensions: Array = []
		if shape is BoxShape3D:
			dimensions = [shape.size.x, shape.size.y, shape.size.z]
		elif shape is CylinderShape3D or shape is CapsuleShape3D:
			dimensions = [shape.radius, shape.height]
		elif shape is SphereShape3D:
			dimensions = [shape.radius]
		records.append({"path": str(arena.get_path_to(collider)), "shape": shape.get_class(),
			"dimensions": dimensions, "transform": values, "disabled": collider.disabled,
			"layer": body.collision_layer, "mask": body.collision_mask})
	records.sort_custom(func(a: Dictionary, b: Dictionary): return a.path < b.path)
	return records


static func solid_cells(director: Node3D) -> Array:
	var cells: Array = []
	for x in range(-19, 20):
		for z in range(-23, 24):
			if director.grid.is_point_solid(Vector2i(x, z)):
				cells.append([x, z])
	return cells
