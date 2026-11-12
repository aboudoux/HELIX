extends RefCounted
## Perception et choix d'angles communs. Aucun tir ne contourne le test de visibilité.

var last_known_position := Vector3.ZERO
var last_known_aim := Vector3.ZERO
var memory_left: float = 0.0
var visible_contact: bool = false
var decision_left: float = 0.0
var report_left: float = 0.0
var destination := Vector3.ZERO
var planned_around := Vector3.ZERO
var flank_sign: float = 1.0
var search_phase: float = 0.0


func reset(entry_point: Vector3, side: float) -> void:
	last_known_position = entry_point
	last_known_aim = entry_point+Vector3.UP
	memory_left = 8.0
	visible_contact = false
	decision_left = 0.0
	report_left = 0.0
	flank_sign = side
	search_phase = 0.0
	destination = entry_point
	planned_around = entry_point


func alert(point: Vector3, memory: float = 6.0) -> void:
	# Une information radio ou sonore est une position datée, pas un suivi caché.
	if point.distance_to(last_known_position)>2:
		decision_left = 0
	last_known_position = point
	last_known_aim = point+Vector3.UP
	memory_left = maxf(memory_left,memory)


func observe(actor: CharacterBody3D, delta: float, sees_player: bool) -> void:
	decision_left = maxf(0,decision_left-delta)
	report_left = maxf(0,report_left-delta)
	memory_left = maxf(0,memory_left-delta)
	visible_contact = sees_player
	if sees_player:
		last_known_position = actor.player.global_position
		last_known_aim = actor.player.get_aim_point()
		memory_left = 8.0
		if report_left<=0 and actor.director.has_method("report_sighting"):
			actor.director.report_sighting(actor,last_known_position)
			report_left = .8+actor.get_index()*.035


func react_to_hit() -> void:
	flank_sign *= -1
	decision_left = 0


func choose_destination(actor: CharacterBody3D, grounded: bool, radius: float) -> Vector3:
	var target := last_known_position
	if decision_left>0 and planned_around.distance_to(target)<4:
		return destination
	decision_left = .9+actor.get_index()*.025
	planned_around = target
	var away := actor.global_position-target
	away.y = 0
	# À longue distance, rejoindre d'abord la dernière position signalée.
	if not visible_contact and away.length()>18:
		destination = target
		return destination
	if memory_left<=0 and away.length()<5:
		search_phase += 1.3
		destination = target+Vector3(cos(search_phase),0,sin(search_phase))*3
		return destination
	if away.length()<.1:
		away = actor.global_basis.z
	away = away.normalized()
	var nav: AStarGrid2D = actor.director.grid
	var start: Vector2i
	var height: float = actor.director.flight_height
	if grounded:
		if not actor.director.ground_navigation.ready:
			actor.director.ground_navigation.build(actor.director)
		nav = actor.director.ground_navigation.grid
		start = actor.director.ground_navigation.nearest(actor.global_position)
		height = actor.director.floor_height+.03
	else:
		start = actor.director.nearest_cell(actor.global_position)
	var options: Array[Dictionary] = []
	var preferred := .65*flank_sign
	for angle in [preferred,-preferred,0.0,1.3*flank_sign,-1.3*flank_sign]:
		var candidate: Vector3 = target+away.rotated(Vector3.UP,angle)*radius
		candidate.y = height
		var cell := Vector2i(roundi(candidate.x),roundi(candidate.z))
		if not nav.is_in_boundsv(cell) or nav.is_point_solid(cell):
			continue
		candidate = Vector3(cell.x,height,cell.y)
		var origin := candidate+Vector3.UP*(1.4 if grounded else 0.0)
		var ray := PhysicsRayQueryParameters3D.create(origin,last_known_aim,1)
		var blocked := not actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		var score: float = actor.global_position.distance_to(candidate)*.45+absf(angle-preferred)*5+(16 if blocked else 0)
		for ally in actor.director.get_children():
			if ally!=actor and ally is CharacterBody3D and ally.alive:
				score += maxf(0,4-ally.global_position.distance_to(candidate))*3
		options.append({"position":candidate,"cell":cell,"score":score})
	options.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.score<b.score)
	# Vérifier la connexion réelle : un bon angle derrière une porte fermée est inutile.
	for option in options:
		if nav.is_in_boundsv(start) and not nav.get_id_path(start,option.cell,false).is_empty():
			destination = option.position
			return destination
	destination = target
	return destination
