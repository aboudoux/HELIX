extends RefCounted

const ROUTES := preload("res://missions/lunar_escape/lunar_routes.gd")
const COLONY := preload("res://missions/lunar_escape/colony_details.gd")
const X_LIMIT := 170
const Z_MIN := -2586
const Z_MAX := 160
const SAMPLE := 3.0
# Align the landing apron with the terrain grid. A single collider keeps
# wide vehicle hulls from snagging on individual triangle edges here.
const ARRIVAL_APRON := Rect2(-17.0, ROUTES.BASE_Z[2]+18.0, 33.0, 42.0)

var hills := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var craters: Array[Vector3] = []
var crater_cells: Dictionary = {}
var stations: Array[float]
const LOOP_MIN := Vector2(-600, -2700)
const LOOP_SIZE := Vector2(1200, 3600)

static func wrapped(point: Vector3) -> Vector3:
	return Vector3(wrapf(point.x, LOOP_MIN.x, LOOP_MIN.x+LOOP_SIZE.x), point.y,
		wrapf(point.z, LOOP_MIN.y, LOOP_MIN.y+LOOP_SIZE.y))

static func nearest_image(point: Vector3, observer: Vector3) -> Vector3:
	return Vector3(observer.x+wrapf(point.x-observer.x,-LOOP_SIZE.x*.5,LOOP_SIZE.x*.5),point.y,
		observer.z+wrapf(point.z-observer.z,-LOOP_SIZE.y*.5,LOOP_SIZE.y*.5))


func _init(base_coordinates: Array[float]) -> void:
	stations = base_coordinates
	hills.seed = 54
	hills.frequency = 0.011
	detail.seed = 319
	detail.frequency = 0.043
	var random := RandomNumberGenerator.new()
	random.seed = 5024
	for index in range(100):
		var side := -1.0 if index % 2 else 1.0
		craters.append(Vector3(side * random.randf_range(24, 159), random.randf_range(Z_MIN + 20, 46), random.randf_range(9, 32)))
	var bypass_start := ROUTES.shortcut_start()
	var bypass_end := ROUTES.shortcut_end()
	var verge := bypass_start.direction_to(bypass_end).cross(Vector3.UP)
	var first := bypass_start.lerp(bypass_end, 0.38) + verge * 11.0
	var second := bypass_start.lerp(bypass_end, 0.64) - verge * 13.0
	craters.append(Vector3(first.x, first.z, 10.0))
	craters.append(Vector3(second.x, second.z, 12.0))
	craters.append(Vector3(78,stations[2]-26,18.0))
	# Sample only nearby craters when building the enlarged terrain.
	for crater in craters:
		var radius := crater.z*1.33
		for cx in range(floori((crater.x-radius)/64),floori((crater.x+radius)/64)+1):
			for cz in range(floori((crater.y-radius)/64),floori((crater.y+radius)/64)+1):
				var cell := Vector2i(cx,cz)
				if not crater_cells.has(cell): crater_cells[cell]=[]
				crater_cells[cell].append(crater)


func elevation(x: float, z: float) -> float:
	var outer := maxf(smoothstep(170,260,absf(x)),maxf(smoothstep(162,252,z),smoothstep(-Z_MIN,-Z_MIN+90,-z)))
	if outer>=1.0: return outer_elevation(x,z)
	return preload("res://missions/lunar_escape/bunker_sites.gd").grade(x,z,lerpf(inner_elevation(x,z),outer_elevation(x,z),outer))

func outer_elevation(x: float, z: float) -> float:
	# Periodic noise: height and slope agree on opposite sides, including the corners.
	var a := x*TAU/LOOP_SIZE.x
	var b := (z+300)*TAU/LOOP_SIZE.y
	var terrain := hills.get_noise_3d(cos(a)*190,sin(a)*190,sin(b)*210)*13.0 + detail.get_noise_3d(cos(b)*150,sin(b)*150,cos(a)*140)*2.5
	var cell := Vector2(x/200.0,z/225.0)
	var id := Vector2(posmod(floori(cell.x),6),posmod(floori(cell.y),16))
	var seed_value := sin(id.dot(Vector2(73.1,91.7)))
	var center := Vector2(0.5+seed_value*0.1,0.5+cos(id.x*17+id.y*23)*0.1)
	var offset := (Vector2(fposmod(cell.x,1),fposmod(cell.y,1))-center)*Vector2(200,225)
	var radius := 39.0+17.0*(seed_value*0.5+0.5)
	var r := offset.length()/radius
	return terrain-radius*0.10*(1-smoothstep(0,0.88,r))+radius*0.035*maxf(0,1-absf(r-1)*4)

func inner_elevation(x: float, z: float) -> float:
	var relief := hills.get_noise_2d(x, z) * 15.5 + detail.get_noise_2d(x, z) * 1.95
	var ridge := smoothstep(130.0, 176.0, absf(x))
	relief += ridge * (5.0 + 11.0 * absf(hills.get_noise_2d(x * 0.64, z * 0.72)))
	for crater: Vector3 in crater_cells.get(Vector2i(floori(x/64),floori(z/64)),[]):
		var offset := Vector2(x - crater.x, z - crater.y)
		if absf(offset.x) > crater.z * 1.33 or absf(offset.y) > crater.z * 1.33:
			continue
		var radius := offset.length() / crater.z
		var bowl := -crater.z * 0.21 * (1.0 - smoothstep(0.0, 0.91, radius))
		var rim := crater.z * 0.095 * maxf(0.0, 1.0 - absf(radius - 0.99) * 3.3)
		relief += bowl + rim
	var flat := 1.0
	# Enclosed north corridor and turn at the foot of Copernic's stair tower.
	flat = minf(flat,maxf(smoothstep(4,7,absf(x)),smoothstep(17,21,absf(z-(stations[2]-35)))))
	flat = minf(flat,maxf(smoothstep(16,20,absf(x-11)),smoothstep(4,7,absf(z-(stations[2]-50)))))
	flat = minf(flat,maxf(smoothstep(4,8,absf(x-22)),smoothstep(4,8,absf(z-(stations[2]-50)))))
	# Arrival pad and its walkway remain level, with terrain extending behind the landing camera.
	flat = minf(flat,maxf(smoothstep(12.0,22.0,absf(x)),smoothstep(18.0,26.0,absf(z-42.0))))
	for leg in range(2):
		if z >= ROUTES.finish(leg) - 28.0 and z <= ROUTES.start(leg) + 28.0:
			# A wide flat shoulder keeps the heavy hull clear of interpolated slopes
			# on the 6 m terrain grid, including diagonally crossed triangle seams.
			flat = minf(flat, smoothstep(14.0, 26.0, ROUTES.distance_from_road(leg, x, z)))
	var plan := Vector2(x, z)
	if absf(z-ROUTES.wreck_point().z)<30:
		flat = minf(flat,smoothstep(7.0,13.0,ROUTES.wreck_distance(plan)))
	if z <= ROUTES.shortcut_start().z + 7.0 and z >= ROUTES.shortcut_end().z - 7.0:
		flat = minf(flat, smoothstep(3.1, 8.0, ROUTES.shortcut_distance(plan)))
	if absf(z - ROUTES.service_point().z) < 13.0:
		flat = minf(flat, smoothstep(6.0, 13.0, ROUTES.service_distance(plan)))
	for index in range(stations.size()):
		var station := stations[index]
		flat = minf(flat, maxf(smoothstep(46.0, 59.0, absf(x)), smoothstep(24.0, 43.0, absf(z - station))))
		var pod_offset := Vector2(absf(x) - COLONY.pod_x(index), z - station - COLONY.POD_Z)
		flat = minf(flat, smoothstep(13.0, 19.0, pod_offset.length()))
	var pad_center := stations[stations.size() - 1] - 55.0
	flat = minf(flat, maxf(smoothstep(19.0, 32.0, absf(x)), smoothstep(28.0, 46.0, absf(z - pad_center))))
	var apron_offset := (Vector2(x, z) - ARRIVAL_APRON.get_center()).abs() - ARRIVAL_APRON.size * 0.5
	flat = minf(flat, smoothstep(0.0, 8.0, maxf(apron_offset.x, apron_offset.y)))
	# Recess ground below metal slabs: coplanar ground caused the black triangles
	# and sand patches in the hangar and Courier wreck screenshots.
	var hangar := (plan-Vector2(0,stations[1]-30)).abs()-Vector2(11,11)
	var wreck := (plan-Vector2(ROUTES.wreck_point().x,ROUTES.wreck_point().z)).abs()-Vector2(6.5,5.5)
	var slab := maxf(1-smoothstep(0,4,maxf(hangar.x,hangar.y)),1-smoothstep(0,3,maxf(wreck.x,wreck.y)))
	for station in stations:
		for end in [-22.0,22.0]:
			var sas := (plan-Vector2(0,station+end)).abs()-Vector2(3.6,3.7)
			slab = maxf(slab,1-smoothstep(0,2,maxf(sas.x,sas.y)))
	for corridor in [Vector4(0,stations[2]-34.5,3.6,16.0),Vector4(11,stations[2]-50,14.6,3.6)]:
		var offset := (plan-Vector2(corridor.x,corridor.y)).abs()-Vector2(corridor.z,corridor.w)
		slab = maxf(slab,1-smoothstep(0,2,maxf(offset.x,offset.y)))
	return lerpf(relief*flat,-0.18,slab)


func build(parent: Node3D, material: Material) -> void:
	# Preserve the campaign's exact grid; coarser outer ground and horizon cost less.
	var xs := PackedFloat32Array()
	var zs := PackedFloat32Array()
	for x in range(-1200,-690,24): xs.append(x)
	for x in range(-690,-170,6): xs.append(x)
	for x in range(-170,173,3): xs.append(x)
	for x in range(174,691,6): xs.append(x)
	for x in range(714,1201,24): xs.append(x)
	# Detailed around habitats, 6 m along roads, coarse horizon beyond the loop.
	for z in range(-3300,-2790,24): zs.append(z)
	for z in range(-2790,Z_MIN,6): zs.append(z)
	var sample_z := Z_MIN
	while sample_z<=162:
		zs.append(sample_z)
		var near_base := false
		for station in stations:
			if absf(sample_z-station)<96: near_base=true
		sample_z += 3 if near_base else 6
	for z in range(168,991,6): zs.append(z)
	for z in range(1014,1501,24): zs.append(z)
	var columns := xs.size()
	var rows := zs.size()
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var faces := PackedInt32Array()
	points.resize(columns * rows)
	normals.resize(points.size())
	for row in range(rows):
		for column in range(columns):
			var x := xs[column]
			var z := zs[row]
			var index := row * columns + column
			points[index] = Vector3(x, elevation(x, z), z)
			var dx := elevation(x + 0.5, z) - elevation(x - 0.5, z)
			var dz := elevation(x, z + 0.5) - elevation(x, z - 0.5)
			normals[index] = Vector3(-dx, 1, -dz).normalized()
			if row < rows - 1 and column < columns - 1:
				faces.append_array([index, index + 1, index + columns,
					index + 1, index + columns + 1, index + columns])
	var data := []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = points
	data[Mesh.ARRAY_NORMAL] = normals
	data[Mesh.ARRAY_INDEX] = faces
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	var surface := MeshInstance3D.new()
	surface.name = "ReliefLunaire"
	surface.mesh = mesh
	surface.material_override = material
	parent.add_child(surface)
	var body := StaticBody3D.new()
	body.set_meta("impact_surface","dust")
	surface.add_child(body)
	var collider := CollisionShape3D.new()
	var collision_faces := PackedVector3Array()
	for i in range(0, faces.size(), 3):
		var a := points[faces[i]]
		var b := points[faces[i + 1]]
		var c := points[faces[i + 2]]
		var middle := (a + b + c) / 3.0
		if not ARRIVAL_APRON.has_point(Vector2(middle.x, middle.z)):
			collision_faces.append_array([a, b, c])
	var ground := ConcavePolygonShape3D.new()
	ground.set_faces(collision_faces)
	ground.backface_collision = true
	collider.shape = ground
	body.add_child(collider)
	var apron := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(ARRIVAL_APRON.size.x, 0.5, ARRIVAL_APRON.size.y)
	var center := ARRIVAL_APRON.get_center()
	apron.position = Vector3(center.x, -0.25, center.y)
	apron.shape = slab
	body.add_child(apron)
