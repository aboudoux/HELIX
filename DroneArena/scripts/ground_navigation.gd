extends RefCounted
## Grille au sol indépendante de la carte de vol des sentinelles.

var grid := AStarGrid2D.new()
var ready: bool = false


func build(director: Node3D) -> void:
	grid.region = director.grid.region
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var shape := CylinderShape3D.new()
	shape.radius = director.ground_radius
	shape.height = director.ground_height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	var space := director.get_world_3d().direct_space_state
	for x in range(grid.region.position.x, grid.region.end.x):
		for z in range(grid.region.position.y, grid.region.end.y):
			var inside := true
			if "layout" in director:
				inside = false
				for rect in director.layout.floors:
					inside = inside or Rect2(rect[0],rect[1],rect[2],rect[3]).has_point(Vector2(x,z))
			query.transform = Transform3D(Basis.IDENTITY, Vector3(x,director.floor_height+shape.height*.5+.035,z))
			var blocked := not inside or not space.intersect_shape(query,1).is_empty()
			if not blocked:
				var floor_ray := PhysicsRayQueryParameters3D.create(Vector3(x,director.floor_height+.12,z),Vector3(x,director.floor_height-.4,z),1)
				blocked = space.intersect_ray(floor_ray).is_empty()
			grid.set_point_solid(Vector2i(x,z),blocked)
	ready = true


func nearest(point: Vector3) -> Vector2i:
	var cell := Vector2i(roundi(point.x),roundi(point.z))
	var best := Vector2i(-9999,-9999)
	var distance := INF
	for x in range(cell.x-5,cell.x+6):
		for z in range(cell.y-5,cell.y+6):
			var candidate := Vector2i(x,z)
			if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate):
				var d := Vector2(point.x,point.z).distance_squared_to(Vector2(x,z))
				if d < distance:
					distance = d
					best = candidate
	return best


func route(director: Node3D, from: Vector3, to: Vector3) -> PackedVector3Array:
	if not ready:
		build(director)
	var result := PackedVector3Array()
	var start := nearest(from)
	var end := nearest(to)
	if not grid.is_in_boundsv(start) or not grid.is_in_boundsv(end):
		return result
	for cell in grid.get_id_path(start,end,true):
		result.append(Vector3(cell.x,director.floor_height,cell.y))
	return result
