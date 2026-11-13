extends RefCounted
## Collision sampled, two-storey routes. Door state is refreshed without rebuilding the map.
var graph := AStar3D.new()
var cells: Dictionary = {}
var door_points: Dictionary = {}
var regions: Dictionary = {}
var obstructed: Dictionary = {}
var probe: PhysicsShapeQueryParameters3D
var excluded: Array[RID] = []
var center := 0.0
var game: Node3D
var levels := 2

func build(campaign: Node3D, base: int) -> void:
	game = campaign
	center = game.WORLD.BASE_Z[base]
	levels = 3 if base==2 else 2
	graph.clear(); cells.clear(); door_points.clear(); regions.clear(); excluded.clear()
	for door in game.world.doors.values():
		for leaf in door.leaves: excluded.append(leaf.get_child(0).get_rid())
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28; shape.height = 1.72
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape; query.collision_mask = 1; query.exclude = excluded
	probe = query
	var space := game.get_world_3d().direct_space_state
	for level in range(levels):
		for x in range(-73,74):
			for z in range(-65,57):
				if level==1 and (abs(x)>44 or abs(z)>21): continue
				var y := 5.0*level
				if level==2:
					if abs(x)>44 or z>35 or z<-50: continue
					y = game.WORLD.ROOF_HEIGHT
					if x>=20 and x<=24 and z<=-18:
						y = clampf((z+50.0)/32.0,0,1)*game.WORLD.ROOF_HEIGHT
				if level==1 and x>=36 and x<=42 and z>=-12 and z<=5:
					y = clampf((4.2-z)/16.2,0,1)*5
				var p := Vector3(x,y,center+z)
				var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.4,p-Vector3.UP*0.45,1,excluded))
				if floor_hit.is_empty() or floor_hit.normal.y<0.65: continue
				p.y = floor_hit.position.y+0.025
				query.transform = Transform3D(Basis.IDENTITY,p+Vector3.UP*0.89)
				if not space.intersect_shape(query,1).is_empty(): continue
				var id := graph.get_available_point_id()
				graph.add_point(id,p)
				cells[Vector3i(x,z,level)] = id
	for key in cells:
		var id: int = cells[key]
		var p := graph.get_point_position(id)
		for offset in [Vector3i(1,0,0),Vector3i(0,1,0),Vector3i(0,0,1)]:
			var other: Vector3i = key+offset
			if not cells.has(other): continue
			var q := graph.get_point_position(cells[other])
			if absf(p.y-q.y)>0.65: continue
			query.transform = Transform3D(Basis.IDENTITY,p+Vector3.UP*0.89)
			query.motion = q-p
			if space.cast_motion(query)[0]<0.99: continue
			graph.connect_points(id,cells[other])
	for door in game.world.doors.values():
		if absf(door.global_position.z-center)>65: continue
		var nearby: Array[int] = []
		var radius := ceili(door.width*0.5+1.5)
		for level in range(levels):
			for x in range(roundi(door.global_position.x)-radius,roundi(door.global_position.x)+radius+1):
				for z in range(roundi(door.global_position.z-center)-radius,roundi(door.global_position.z-center)+radius+1):
					var key := Vector3i(x,z,level)
					if not cells.has(key): continue
					var id: int = cells[key]
					var local: Vector3 = door.to_local(graph.get_point_position(id))
					if absf(local.x)<door.width*0.5+0.4 and absf(local.z)<0.9 and absf(local.y)<0.5: nearby.append(id)
		door_points[door] = nearby
	# Avoid repeated A* searches into physically disconnected pockets or roofs.
	for seed in graph.get_point_ids():
		if regions.has(seed): continue
		var stack: Array[int] = [seed]
		regions[seed] = seed
		while not stack.is_empty():
			var next: int = stack.pop_back()
			for adjacent in graph.get_point_connections(next):
				if not regions.has(adjacent): regions[adjacent] = seed; stack.append(adjacent)

func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	probe.motion = Vector3.ZERO
	var space := game.get_world_3d().direct_space_state
	for id in obstructed.keys():
		probe.transform = Transform3D(Basis.IDENTITY,graph.get_point_position(id)+Vector3.UP*0.89)
		if space.intersect_shape(probe,1).is_empty(): graph.set_point_disabled(id,false); obstructed.erase(id)
	for door in door_points:
		for id in door_points[door]: graph.set_point_disabled(id,false)
	for door in door_points:
		if door.secured or door.get_meta("closed_by_player",false):
			for id in door_points[door]: graph.set_point_disabled(id,true)
	var starts := reachable_near(from)
	var ends := reachable_near(to)
	var attempted: Dictionary = {}
	for start in starts:
		for end in ends:
			if regions[start]!=regions[end] or attempted.has(regions[start]): continue
			attempted[regions[start]] = true
			for retry in range(3):
				var ids := graph.get_id_path(start,end)
				if ids.is_empty(): break
				var blocked := false
				for id in ids.slice(1,25):
					probe.transform = Transform3D(Basis.IDENTITY,graph.get_point_position(id)+Vector3.UP*0.89)
					if not space.intersect_shape(probe,1).is_empty():
						graph.set_point_disabled(id,true); obstructed[id] = true; blocked = true
				if not blocked:
					var path := PackedVector3Array([from])
					for id in ids: path.append(graph.get_point_position(id))
					return path
	return PackedVector3Array()

func reachable_near(point: Vector3) -> Array[int]:
	var choices: Array[int] = []
	for level in range(levels):
		for x in range(roundi(point.x)-2,roundi(point.x)+3):
			for z in range(roundi(point.z-center)-2,roundi(point.z-center)+3):
				var key := Vector3i(x,z,level)
				if not cells.has(key): continue
				var id: int = cells[key]
				var p := graph.get_point_position(id)
				if graph.is_point_disabled(id) or graph.get_point_connections(id).is_empty() or absf(p.y-point.y)>0.45: continue
				var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.9,p+Vector3.UP*0.9,1,excluded)
				if game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): choices.append(id)
	choices.sort_custom(func(a,b): return graph.get_point_position(a).distance_squared_to(point)<graph.get_point_position(b).distance_squared_to(point))
	return choices.slice(0,4)
