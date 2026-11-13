extends Node
## A continuous surface with paired edges; no state reset when crossing a seam.
const TERRAIN := preload("res://missions/lunar_escape/regolith.gd")
var crossings := 0

func _ready() -> void:
	process_physics_priority = 100

func wrap_actor(actor: Node3D) -> Vector3:
	var offset := TERRAIN.wrapped(actor.global_position)-actor.global_position
	if offset.length_squared()>1:
		actor.global_position += offset
		actor.reset_physics_interpolation()
	return offset

func _physics_process(_delta: float) -> void:
	var game := get_tree().current_scene
	if game==null or game.get("pilot")==null or not game.pilot.in_control: return
	var pilot: CharacterBody3D = game.pilot
	var offset := wrap_actor(pilot)
	# A parked vehicle beside a seam remains reachable from either side.
	for ride in [game.world.bike,game.world.transport,game.world.scout]:
		if not is_instance_valid(ride) or ride==pilot.vehicle: continue
		var image := TERRAIN.nearest_image(ride.global_position,pilot.global_position)
		var destination := image if image.distance_to(pilot.global_position)<60 else TERRAIN.wrapped(ride.global_position)
		if destination.distance_squared_to(ride.global_position)>1:
			ride.global_position = destination
			ride.reset_physics_interpolation()
	if offset.length_squared()>1:
		crossings += 1
		if is_instance_valid(pilot.vehicle):
			pilot.vehicle.global_position = pilot.global_position
			pilot.vehicle.reset_physics_interpolation()
		# Translate only nearby companions with the player; distant ones walk to the seam.
		for actor in game.squad.members:
			if actor.recruited and actor.alive and actor.global_position.distance_to(pilot.global_position-offset)<60:
				actor.global_position += offset
				actor.path.clear(); actor.route_clock = 0
				actor.reset_physics_interpolation()
	for actor in game.squad.members:
		if not actor.recruited or not actor.alive or actor.embarked: continue
		# Keep close actors on the same image, avoiding a visible jump across the squad.
		var image := TERRAIN.nearest_image(actor.global_position,pilot.global_position)
		var near := image.distance_to(pilot.global_position)<60
		var destination := image if near else TERRAIN.wrapped(actor.global_position)
		if destination.distance_squared_to(actor.global_position)>1:
			actor.global_position = destination
			actor.path.clear(); actor.route_clock = 0
			actor.reset_physics_interpolation()
