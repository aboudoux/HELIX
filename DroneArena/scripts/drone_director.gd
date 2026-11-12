extends Node3D
## Une carte de vol est échantillonnée dans la vraie physique de l'arène.
## Les drones passent au-dessus des petits obstacles et contournent les grands.

const BOLT := preload("res://scenes/enemy_bolt.tscn")
const HOUND_BOLT := preload("res://scenes/hound_bolt.tscn")
const FLIGHT_HEIGHT: float = 2.4
@export var floor_height: float = 0.0
@export var flight_height: float = 2.4
@export var ground_radius: float = 1.5
@export var ground_height: float = 1.75
var grid := AStarGrid2D.new()
var navigation_ready: bool = false
var ground_navigation := preload("res://scripts/ground_navigation.gd").new()
var projectile_damage: int = 10
var projectile_speed: float = 16.0
@onready var player: CharacterBody3D = get_parent().get_node("Player")


func _physics_process(_delta: float) -> void:
	if not navigation_ready:
		build_flight_map()


func build_flight_map() -> void:
	ground_navigation.ready = false
	grid.region = Rect2i(-19, -23, 39, 47)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	# Cette enveloppe couvre les coins du drone quelle que soit son orientation.
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 0.85, 2.4)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	var space := get_world_3d().direct_space_state
	for x in range(-19, 20):
		for z in range(-23, 24):
			query.transform = Transform3D(Basis.IDENTITY, Vector3(x, flight_height, z))
			grid.set_point_solid(Vector2i(x, z), not space.intersect_shape(query, 1).is_empty())
	navigation_ready = true


func nearest_cell(point: Vector3) -> Vector2i:
	var cell := Vector2i(clampi(roundi(point.x), -19, 19), clampi(roundi(point.z), -23, 23))
	if not grid.is_point_solid(cell):
		return cell
	var best := cell
	var best_distance := INF
	for x in range(cell.x - 4, cell.x + 5):
		for z in range(cell.y - 4, cell.y + 5):
			var candidate := Vector2i(x, z)
			if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate):
				var distance := Vector2(point.x, point.z).distance_squared_to(Vector2(candidate))
				if distance < best_distance:
					best = candidate
					best_distance = distance
	return best


func flight_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	if not navigation_ready:
		return result
	var start := nearest_cell(from)
	var finish := nearest_cell(to)
	if grid.is_point_solid(start) or grid.is_point_solid(finish):
		return result
	for cell in grid.get_id_path(start, finish, true):
		result.append(Vector3(cell.x, flight_height, cell.y))
	return result


func spawn_bolt(origin: Vector3, direction: Vector3, shooter: RID) -> void:
	var bolt := BOLT.instantiate()
	bolt.damage = projectile_damage
	bolt.speed = projectile_speed
	get_parent().get_node("Projectiles").add_child(bolt)
	bolt.launch(origin, direction, shooter)


func ground_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return ground_navigation.route(self,from,to)


func report_sighting(source: CharacterBody3D, point: Vector3) -> void:
	for ally in get_children():
		if ally!=source and ally.alive and ally.global_position.distance_to(source.global_position)<36:
			ally.tactics.alert(point)


func spawn_hound_bolt(origin: Vector3, direction: Vector3, shooter: RID) -> void:
	var bolt := HOUND_BOLT.instantiate()
	bolt.damage = roundi(projectile_damage*.6)
	bolt.speed = projectile_speed+4
	get_parent().get_node("Projectiles").add_child(bolt)
	bolt.launch(origin,direction,shooter)


func reset_encounter() -> void:
	navigation_ready = false
	for drone in get_children():
		drone.reset_drone()
