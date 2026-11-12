extends Node3D
## Grille propre au colosse : marge de rotation de 4,1 m et confinement au cœur.

const FLIGHT_HEIGHT := 4.2
var flight_height: float = 4.2
const BOLT := preload("res://scenes/enemy_bolt.tscn")
var navigation_ready: bool = false
var grid := AStarGrid2D.new()
var bounds := Rect2i(-28, -71, 57, 42)


func _physics_process(_delta: float) -> void:
	if $Cerbere.alive and not navigation_ready:
		build_flight_map()


func build_flight_map() -> void:
	grid.region = bounds
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.2, 2.6, 8.2)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	for x in range(bounds.position.x, bounds.end.x):
		for z in range(bounds.position.y, bounds.end.y):
			query.transform = Transform3D(Basis.IDENTITY, Vector3(x, FLIGHT_HEIGHT, z))
			grid.set_point_solid(Vector2i(x,z), not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty())
	navigation_ready = true


func nearest_cell(point: Vector3) -> Vector2i:
	var best := Vector2i.ZERO
	var best_distance := INF
	for x in range(bounds.position.x, bounds.end.x):
		for z in range(bounds.position.y, bounds.end.y):
			var cell := Vector2i(x,z)
			if not grid.is_point_solid(cell):
				var distance := Vector2(point.x,point.z).distance_squared_to(Vector2(cell))
				if distance < best_distance:
					best = cell
					best_distance = distance
	return best


func flight_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	if not navigation_ready:
		return result
	for cell in grid.get_id_path(nearest_cell(from), nearest_cell(to)):
		result.append(Vector3(cell.x, FLIGHT_HEIGHT, cell.y))
	return result


func spawn_round(origin: Vector3, aim: Vector3, shooter: RID, damage: int, speed: float) -> void:
	var bolt := BOLT.instantiate()
	bolt.damage = damage
	bolt.speed = speed
	get_parent().get_node("Projectiles").add_child(bolt)
	bolt.launch(origin, origin.direction_to(aim), shooter)
