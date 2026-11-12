extends "res://scripts/drone_director.gd"
## Même combat, avec une grille adaptée aux cours et des activations par secteur.

@export_file("*.json") var layout_path: String = "res://missions/relay_run/layout.json"
var current_sector: int = -1
var layout: Dictionary
var bounds: Rect2i


func _ready() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	var region: Array = layout.nav_bounds
	bounds = Rect2i(region[0], region[1], region[2], region[3])
	reset_encounter()


func reset_encounter() -> void:
	navigation_ready = false
	current_sector = -1
	for actor in get_children():
		actor.reset_drone()
		actor.alive = false
		actor.hide()
		actor.set_physics_process(false)
		actor.set_process(false)
		actor.hit_shape.set_deferred("disabled", true)


func engage_sector(index: int) -> void:
	if current_sector == index:
		return
	current_sector = index
	for actor in get_children():
		if int(actor.get_meta("sector")) == index:
			actor.reset_drone()
			actor.show()
			actor.set_physics_process(true)
			actor.set_process(true)


func remaining(index: int) -> int:
	var count := 0
	for actor in get_children():
		if int(actor.get_meta("sector")) == index and actor.alive:
			count += 1
	return count


func build_flight_map() -> void:
	ground_navigation.ready = false
	grid.region = bounds
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 0.85, 2.4)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	var space := get_world_3d().direct_space_state
	for x in range(bounds.position.x, bounds.end.x):
		for z in range(bounds.position.y, bounds.end.y):
			var inside := false
			for floor_rect in layout.floors:
				inside = inside or Rect2(floor_rect[0], floor_rect[1], floor_rect[2], floor_rect[3]).has_point(Vector2(x, z))
			query.transform = Transform3D(Basis.IDENTITY, Vector3(x, flight_height, z))
			grid.set_point_solid(Vector2i(x, z), not inside or not space.intersect_shape(query, 1).is_empty())
	navigation_ready = true


func nearest_cell(point: Vector3) -> Vector2i:
	var cell := Vector2i(clampi(roundi(point.x), bounds.position.x, bounds.end.x - 1), clampi(roundi(point.z), bounds.position.y, bounds.end.y - 1))
	if not grid.is_point_solid(cell):
		return cell
	var best := cell
	var distance := INF
	for x in range(cell.x - 5, cell.x + 6):
		for z in range(cell.y - 5, cell.y + 6):
			var candidate := Vector2i(x, z)
			if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate):
				var d := Vector2(point.x, point.z).distance_squared_to(Vector2(candidate))
				if d < distance:
					distance = d
					best = candidate
	return best
