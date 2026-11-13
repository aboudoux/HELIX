extends Node3D

const COLONY := preload("res://missions/lunar_escape/colony_details.gd")
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const FINISH := preload("res://missions/lunar_escape/finishes.gd")
const REGOLITH := preload("res://missions/lunar_escape/regolith.gd")
const ROUTES := preload("res://missions/lunar_escape/lunar_routes.gd")
const FURNITURE := preload("res://missions/lunar_escape/furnishings.gd")
const ARMORY := preload("res://missions/lunar_escape/armory.gd")
const DOOR := preload("res://missions/lunar_escape/door.gd")
const VEHICLE_COLLISION := preload("res://missions/lunar_escape/vehicle_collision.gd")
const FLOOR := preload("res://materials/Floor.tres")
const TILE := preload("res://materials/TileA.tres")
const INSET := preload("res://materials/Inset.tres")
const FRAME := preload("res://materials/Frame.tres")
const CYAN := preload("res://materials/Cyan.tres")
const AMBER := preload("res://materials/Amber.tres")
const RED := preload("res://materials/EnemyGlow.tres")
const WHITE := preload("res://materials/Ivory.tres")
const STEEL := preload("res://materials/WeaponSilver.tres")
const GRIP := preload("res://materials/WeaponGrip.tres")
const ARMOR := preload("res://materials/EnemyArmor.tres")
const COVER := preload("res://assets/models/helix_cover.glb")
const STORAGE := preload("res://assets/models/helix_storage.glb")
const RELAY := preload("res://assets/models/helix_mission_relay.glb")
const EARTH_TEXTURE := preload("res://missions/lunar_escape/earth.jpg")
const BASE_Z := ROUTES.BASE_Z
const COPERNIC_Z := BASE_Z[2]
const EARTH_DIRECTION := Vector3(0.24, 0.58, -0.78)
const ROOF_HEIGHT := 16.5
const PAD_ORIGIN := Vector3(0, ROOF_HEIGHT, COPERNIC_Z + 238.0)
const ROOF_STAIRS_BOTTOM := Vector3(22, 0, COPERNIC_Z-50)
const ROOF_STAIRS_TOP := Vector3(22, ROOF_HEIGHT, COPERNIC_Z-18)
const BASE_NAMES: Array[String] = ["01  HABITAT KAREN", "02  ATELIER TYCHO", "03  CONTRÔLE COPERNIC"]
const UPPER_HEIGHT := 5.0
const STAIR_BOTTOM := Vector3(39.0, 0, 4.2)
const STAIR_TOP := Vector3(39.0, UPPER_HEIGHT, -12.0)
const RELAY_POINT := Vector3(-8, UPPER_HEIGHT, -9)
const ROOM_DIVIDERS := [[-19.0, -6.33, 6.33, 19.0], [-19.0, -5.7, 7.8, 19.0], [-19.0, -7.6, 7.25, 19.0]]
const EAST_ROOMS := [["Cuisine", "Ferme", "Controle"], ["Controle", "Cuisine", "Ferme"], ["Ferme", "Controle", "Cuisine"]]
const ROOM_TITLES := {"Cuisine": "CUISINE", "Ferme": "FERME HYDROPONIQUE", "Controle": "POSTE DE CONTRÔLE"}

var doors: Dictionary = {}
var bike: Node3D
var transport: Node3D
var scout: Node3D
var rocket: Node3D
var rocket_flame: Node3D
var pad_barriers: Array[MeshInstance3D] = []
var furnishings := FURNITURE.new()
var room_racks: Array[Marker3D] = []
var relays: Array[Node3D] = []
var sky_environment: WorldEnvironment
var surface_profile: RefCounted
var airlocks: Array[Node3D] = []


func _ready() -> void:
	var gravity_field := Area3D.new()
	gravity_field.name = "GraviteLunaire"
	gravity_field.add_to_group("lunar_gravity")
	gravity_field.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	gravity_field.gravity = 1.62
	gravity_field.collision_layer = 0; gravity_field.collision_mask = 31
	gravity_field.position.z=REGOLITH.LOOP_MIN.y+REGOLITH.LOOP_SIZE.y*.5
	var gravity_shape := CollisionShape3D.new()
	var volume := BoxShape3D.new(); volume.size = Vector3(5000,2000,5000)
	gravity_shape.shape = volume; gravity_field.add_child(gravity_shape)
	add_child(gravity_field)
	build_sky()
	build_surface()
	for index in range(BASE_Z.size()):
		build_base(index)
	build_quarters()
	build_vehicles()
	build_launch_pad()
	build_airlocks()
	preload("res://missions/lunar_escape/vehicle_finish.gd").dress(self)
	FINISH.apply_tree(self)

func air_at(point: Vector3) -> bool:
	for lock in airlocks:
		if lock.contains(point): return lock.pressure>0.95
	return interior_at(point)

func movement_gravity(point: Vector3) -> Vector3:
	# Artificial gravity inside the habitats; the exposed roof stays lunar.
	return Vector3.DOWN*(9.81 if interior_at(point) else 1.62)

func interior_at(point: Vector3) -> bool:
	for site in preload("res://missions/lunar_escape/bunker_sites.gd").POINTS:
		if AABB(site+Vector3(-6,0,-6.8),Vector3(12,3.5,13.8)).has_point(point+Vector3.UP*.1): return true
	# Gravity in an airlock is independent of its pressure cycle.
	for lock in airlocks:
		if lock.contains(point): return true
	var p := Vector3(point.x,point.y,point.z-COPERNIC_Z)
	if p.y>=-0.12 and p.y<3.4 and (Rect2(-3,-53,6,34).has_point(Vector2(p.x,p.z)) or Rect2(-3,-53,28,6).has_point(Vector2(p.x,p.z))): return true
	if p.x>19.7 and p.x<24.3 and p.z>=-50 and p.z<=-18:
		var height := (p.z+50)/32*ROOF_HEIGHT
		if p.y>=height-0.3 and p.y<height+3.3: return true
	return pressurized(point)

func build_airlocks() -> void:
	for index in range(3):
		add_airlock(["habitat_entry","workshop_entry","control_entry"][index],at(index,0,0,25))
		if index<2: add_airlock(["habitat_exit","garage"][index],at(index,0,0,-25))
	build_door(self,"roof_inner",at(2,22,ROOF_HEIGHT,-17.7),4.4,"Sas du toit",false)
	add_airlock("roof_inner",at(2,22,ROOF_HEIGHT,-11.7))

func add_airlock(key: String, outside: Vector3) -> void:
	var inside: Node3D = doors[key]
	build_door(self,key+"_outer",outside,inside.width,"Porte extérieure · "+inside.title,false)
	var center: Vector3 = (inside.global_position+outside)*0.5
	var width: float = inside.width+0.5
	var depth: float = absf(outside.z-inside.global_position.z)
	var finish := FINISH.architecture(WHITE,FINISH.Detail.USER_WALL_PHOTO)
	for side in [-1,1]:
		block(self,center+Vector3(side*width*0.5,1.85,0),Vector3(0.25,3.7,depth+0.4),finish,true)
	block(self,center+Vector3(0,3.6,0),Vector3(width,0.25,depth+0.4),finish,true)
	block(self,center-Vector3.UP*0.12,Vector3(width,0.24,depth+0.4),FLOOR,true)
	if outside.y<1:
		var direction := signf(outside.z-inside.global_position.z)
		var threshold := block(self,outside+Vector3(0,-0.18,direction*1.1),Vector3(width,0.16,2.6),FLOOR,true)
		threshold.rotation.x = direction*atan2(0.2,2.6)
	for end in [inside.global_position,outside]:
		block(self,end+Vector3(0,3.4,0),Vector3(width,0.5,0.45),FRAME,true)
	ceiling_light(self,center+Vector3.UP*3.35,CYAN)
	var lock := preload("res://missions/lunar_escape/airlock.gd").new()
	lock.name = "Sas_"+key; add_child(lock)
	lock.setup(inside,doors[key+"_outer"],AABB(center-Vector3(width*0.5,0,depth*0.5),Vector3(width,3.5,depth)))
	airlocks.append(lock)

static func at(base: int, x: float, y: float, local_z: float) -> Vector3:
	return Vector3(x, y, BASE_Z[base] + local_z)


static func pad(x: float, y: float, z: float) -> Vector3:
	return PAD_ORIGIN + Vector3(x, y, z)


static func pressurized(point: Vector3) -> bool:
	if point.y < -0.12:
		return false
	var plan := Vector2(point.x, point.z)
	for index in range(BASE_Z.size()):
		plan.y = point.z - BASE_Z[index]
		if COLONY.breathable(Vector3(point.x, point.y, plan.y), index):
			return true
		if point.y < 4.65 and Rect2(-44.1, -18.96, 79.12, 37.92).has_point(plan):
			return true
		if point.y >= 4.65 and point.y < 9.49 and Rect2(-28.96, -16.97, 63.98, 29.94).has_point(plan):
			return true
		if point.y < 9.50 and Rect2(34.98, -16.97, 8.03, 23.65).has_point(plan):
			return true
	return false


func build_sky() -> void:
	var environment := WorldEnvironment.new()
	sky_environment = environment
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_SKY
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://missions/lunar_escape/lunar_sky.gdshader")
	sky_material.set_shader_parameter("earth_map",EARTH_TEXTURE)
	sky_material.set_shader_parameter("earth_direction",EARTH_DIRECTION)
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.environment.sky = sky
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("cbd3df")
	environment.environment.ambient_light_energy = 0.38
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment.tonemap_exposure = 1.05
	environment.environment.tonemap_white = 4.0
	environment.environment.ssao_enabled = true
	environment.environment.ssao_radius = 0.85
	environment.environment.ssao_intensity = 1.35
	environment.environment.ssao_light_affect = 0.06
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24, -38, 0)
	sun.light_color = Color("fff3df")
	sun.light_energy = 1.22
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110
	add_child(sun)
	sky_material.set_shader_parameter("sunlight",sun.basis.z)


func build_surface() -> void:
	var terrain_material := FINISH.create(Color("737374"), 0, 0.96, 0.95, true)
	var rock_material := FINISH.create(Color("66676a"),0,.96,.7,true,FINISH.RESEARCH.Kind.ROCK)
	var relief := REGOLITH.new(BASE_Z)
	surface_profile = relief
	relief.build(self, terrain_material)
	var loop := preload("res://missions/lunar_escape/lunar_loop.gd").new()
	loop.name = "LunarLoop"
	add_child(loop)
	var random := RandomNumberGenerator.new()
	random.seed = 430
	var stone_meshes: Array[ArrayMesh] = []
	var stone_shapes: Array[Shape3D] = []
	for i in range(6):
		stone_meshes.append(rock_mesh(i))
		stone_shapes.append(stone_meshes[-1].create_convex_shape())
	for i in range(600):
		var x := random.randf_range(11, 165) * (-1 if i % 2 == 0 else 1)
		var z := random.randf_range(REGOLITH.Z_MIN+17, 56)
		if i>=350:
			x = random.randf_range(210,525)*(-1 if i%2==0 else 1)
			z = random.randf_range(REGOLITH.LOOP_MIN.y+90,REGOLITH.LOOP_MIN.y+REGOLITH.LOOP_SIZE.y-90)
		if absf(x) < 46 and (absf(z) < 25 or absf(z - BASE_Z[1]) < 25 or absf(z - BASE_Z[2]) < 83):
			continue
		if ROUTES.distance_from_road(0, x, z) < 10.0 or ROUTES.distance_from_road(1, x, z) < 10.0:
			continue
		var size := random.randf_range(0.4, 4.9)
		var yaw := random.randf_range(0.0, TAU)
		if preload("res://missions/lunar_escape/bunker_sites.gd").reserved(x,z): continue
		if ROUTES.shortcut_distance(Vector2(x, z)) < 6.0 or ROUTES.service_distance(Vector2(x, z)) < 8.0:
			continue
		var rock := mesh_node(self, Vector3(x, relief.elevation(x, z) + size * 0.08, z), stone_meshes[i % stone_meshes.size()], rock_material)
		rock.rotation.y = yaw
		rock.scale = Vector3(size, size * 0.65, size * 0.87)
		if size > 1.75:
			var obstacle := StaticBody3D.new()
			obstacle.transform = rock.transform
			add_child(obstacle)
			var collider := CollisionShape3D.new()
			collider.shape = stone_shapes[i%stone_shapes.size()]
			obstacle.add_child(collider)
	var road_surface := FINISH.create(Color("4b4b49"), 0, 0.95, 0.8, true)
	for leg in range(2):
		build_route(leg, road_surface)
		placard(self, "%s   /   %d m" % [["TYCHO", "COPERNIC"][leg], roundi(ROUTES.length(leg))],
			at(leg, 6.4, 1.65, -30), Color("80e9fa") if leg == 0 else Color("ffe2b0"))
	build_surface_stops(road_surface)
	for leg in range(2):
		for index in range(ROUTES.AIR_STOPS.size()):
			var point := ROUTES.air_stop(leg,index)
			var post := Node3D.new()
			post.name="BorneO2_%d_%d"%[leg,index]
			post.position=point
			add_child(post)
			KIT.bevel(post,Vector3(0,.65,0),Vector3(.8,1.3,.7),.08,FRAME,true)
			for x in [-.6,.6]: cylinder(post,Vector3(x,.8,0),.18,.18,1.4,WHITE)
			KIT.bevel(post,Vector3(0,1.35,0),Vector3(.55,.12,.45),.03,CYAN)
			placard(post,"O₂ · RECHARGE\nE à l'arrêt",Vector3(0,2.1,0),Color("a0f5dc"))


func build_surface_stops(road_surface: Material) -> void:
	var start := ROUTES.shortcut_start()
	var finish := ROUTES.shortcut_end()
	var trail := block(self, (start + finish) * 0.5 + Vector3.UP * 0.024,
		Vector3(4.6, 0.035, start.distance_to(finish)), road_surface)
	trail.look_at(finish + Vector3.UP * 0.024)
	var green := StandardMaterial3D.new()
	green.albedo_color = Color("74f5a2")
	green.emission_enabled = true
	green.emission = Color("53d980")
	var edge := start.direction_to(finish).cross(Vector3.UP) * 2.25
	for i in range(10):
		for side in [-1.0, 1.0]:
			var peg: Vector3 = start.lerp(finish, i / 9.0) + edge * side
			cylinder(self, peg + Vector3.UP * 0.32, 0.12, 0.21, 0.65, FRAME)
			cylinder(self, peg + Vector3.UP * 0.68, 0.15, 0.16, 0.14, green)
	placard(self, "PASSAGE MOTO", start + Vector3(2.7, 1.5, 0.0), Color("a5ffd0"))
	var service := ROUTES.service_point()
	block(self, service + Vector3(0, -0.07, 0), Vector3(9.0, 0.18, 7.8), FLOOR, true)
	# Open emergency shelter, approached from the road on its east side.
	block(self, service + Vector3(-3.7,1.6,0),Vector3(0.18,3.2,6.8),WHITE,true)
	for z in [-3.3,3.3]: block(self,service+Vector3(-2.3,1.6,z),Vector3(3.0,3.2,0.18),WHITE,true)
	block(self,service+Vector3(-2.3,3.2,0),Vector3(3.0,0.18,6.8),FRAME,true)
	furnishings.bed(self,service+Vector3(-2.5,0,0.5))
	placard(self,"ABRI ÉVACUÉ · DIRECTION TYCHO",service+Vector3(-3.5,2.5,0),Color("ffe1a3"),PI/2)
	placard(self, "RAVITAILLEMENT", service + Vector3(-1.0, 2.33, 0), Color("ffe1a3"), PI / 2)
	for fraction in [0.3, 0.6]:
		cylinder(self, ROUTES.service_turnoff().lerp(service, fraction) + Vector3(0, 0.48, 3.1), 0.15, 0.20, 0.95, AMBER)


func build_route(leg: int, material: Material) -> void:
	var road := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span := ceili((ROUTES.start(leg) - ROUTES.finish(leg)) / 2.0)
	var last: Array[Vector3] = []
	var since_beacon := 0.0
	var previous := ROUTES.point(leg, ROUTES.start(leg))
	for i in range(span + 1):
		var z := lerpf(ROUTES.start(leg), ROUTES.finish(leg), float(i) / span)
		var center := ROUTES.point(leg, z)
		var tangent := ROUTES.point(leg, z + 0.4).direction_to(ROUTES.point(leg, z - 0.4))
		var shoulder := tangent.cross(Vector3.UP) * ROUTES.ROAD_HALF_WIDTH
		var edge: Array[Vector3] = [center - shoulder, center + shoulder]
		if not last.is_empty():
			for corner in [last[0], edge[0], last[1], last[1], edge[0], edge[1]]:
				road.set_normal(Vector3.UP)
				road.add_vertex(corner + Vector3.UP * 0.032)
		since_beacon += previous.distance_to(center)
		if since_beacon >= 14.0 and i < span - 2:
			since_beacon = 0.0
			for verge in edge:
				cylinder(self, verge + Vector3.UP * 0.31, 0.13, 0.23, 0.62, FRAME)
				cylinder(self, verge + Vector3.UP * 0.68, 0.15, 0.16, 0.13, CYAN if leg == 0 else AMBER)
			block(self, center + Vector3.UP * 0.042, Vector3(0.16, 0.015, 2.7), WHITE).rotation.y = atan2(-tangent.x, -tangent.z)
		last = edge
		previous = center
	mesh_node(self, Vector3.ZERO, road.commit(), material)


func rock_mesh(seed: int) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 9
	sphere.rings = 5
	var surface := SurfaceTool.new()
	surface.create_from(sphere, 0)
	var raw := surface.commit_to_arrays()
	var points: PackedVector3Array = raw[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = 554 + seed
	noise.frequency = 2.3
	for i in range(points.size()):
		var p := points[i]
		points[i] = p * (1.0 + noise.get_noise_3dv(p) * 0.89)
	raw[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, raw)
	var lit := SurfaceTool.new()
	lit.create_from(mesh,0)
	lit.generate_normals()
	return lit.commit()


func panel_wall(parent: Node3D, point: Vector3, length: float, yaw := 0.0, both_sides := true) -> void:
	var wall := Node3D.new()
	wall.position = point
	wall.rotation.y = yaw
	parent.add_child(wall)
	block(wall, Vector3(0, 2.25, 0), Vector3(length + 0.055, 4.56, 0.47), FINISH.architecture(FRAME, FINISH.Detail.WALL), true)
	var ceramic := FINISH.architecture(WHITE, FINISH.Detail.USER_WALL_PHOTO)
	var dark := FINISH.architecture(STEEL, FINISH.Detail.PAINTED_PANEL)
	var count := maxi(1, ceili(length / 2.8))
	var span := length / count
	for side in [-1.0, 1.0] if both_sides else [-1.0]:
		for i in range(count):
			var x := -length * 0.5 + (i + 0.5) * span
			KIT.bevel(wall, Vector3(x, 2.53, side * 0.28), Vector3(span - 0.09, 3.84, 0.105), 0.05, ceramic)
			KIT.bevel(wall, Vector3(x, 0.36, side * 0.28), Vector3(span - 0.09, 0.56, 0.12), 0.045, dark)
			if i % 3 == 1 and span > 1.0:
				KIT.bevel(wall, Vector3(x, 2.72, side * 0.346), Vector3(span * 0.56, 0.37, 0.05), 0.025, FRAME)
				KIT.bevel(wall, Vector3(x, 2.72, side * 0.38), Vector3(span * 0.32, 0.044, 0.04), 0.01, CYAN)

func build_base(index: int) -> void:
	var base := Node3D.new()
	base.name = ["Selene", "Tycho", "Copernic"][index]
	base.position.z = BASE_Z[index]
	add_child(base)
	COLONY.build(base, self, index)
	var accent: Material = [CYAN, AMBER, RED][index]
	for span in [Vector2(-35, -14), Vector2(-14, 14), Vector2(14, 35)]:
		block(base, Vector3((span.x + span.y) * 0.5, -0.084, 0), Vector3(span.y - span.x + 0.14, 0.20, 38.45), FLOOR, true)
	# The upper deck seals the rooms underneath. The exposed ground modules have curved pressure hulls.
	block(base, Vector3(3, 4.75, -2), Vector3(64.2, 0.5, 30.25), FLOOR, true)
	COLONY.vault(base, Vector3(-32, 4.50, -2), 3.25, 30.4, 0.85, WHITE)
	for module in [Vector2(-24.5, 10.5), Vector2(0, 14.1), Vector2(24.5, 10.5)]:
		COLONY.vault(base, Vector3(module.x, 4.50, 16.05), module.y, 6.25, 1.45, WHITE)
		COLONY.vault(base, Vector3(module.x, 4.50, -18.0), module.y, 2.25, 1.10, WHITE)
	for side in [-1.0, 1.0]:
		build_wing(base, index, side, accent)
	build_west_gallery(base, index, accent)
	build_upper_floor(base, index, accent)
	wall_with_opening(base, 19.0, 0.0, 5.4)
	wall_with_opening(base, -19.0, 0.0, 5.4)
	for z in [-15.6, -4.3, 3.4, 13.3]:
		for x in [-8, 0, 8]:
			ceiling_light(base, Vector3(x, 4.36, z), accent)
	for x in [-2.75, 2.75]:
		block(base, Vector3(x, 0.026, 0), Vector3(0.075, 0.018, 37.5), accent)
	for z in range(-17, 19, 3):
		for x in [-11, -6, 6, 11]:
			block(base, Vector3(x, 0.008, z), Vector3(4.4, 0.014, 2.78), TILE)
	placard(base, BASE_NAMES[index], Vector3(0, 3.6, 19.27), Color("ccedff"))
	placard(base, ["SORTIE DE SECOURS", "GARAGE BLINDÉ", "AIRE DE LANCEMENT"][index],
		Vector3(0, 3.5, -18.64), Color("ccedff"))
	placard(base, BASE_NAMES[index], Vector3(0, 3.57, -19.28), Color("ccedff"), PI)
	if index == 0:
		build_door(base, "habitat_entry", Vector3(0, 0, 19), 5.25, "Sas sud", true)
		build_door(base, "habitat_exit", Vector3(0, 0, -19), 5.25, "Sas de sortie", true)
		wall_with_opening(base, 8.0, 0.0, 5.4)
		build_door(base, "tutorial", Vector3(0, 0, 8), 5.25, "Couloir principal", true)
		wall_with_opening(base, -5.0, 5.0, 5.4)
		build_door(base, "north_0", Vector3(5, 0, -5), 5.25, "Secteur nord", false)
		storage(base, Vector3(9.9, 0, 4), PI * 0.5)
		storage(base, Vector3(-10, 0, -12), 0.0)
		placard(base, "RÉSERVES", Vector3(9.6, 2.6, 5.6), Color("8eeef4"))
	elif index == 1:
		build_door(base, "workshop_entry", Vector3(0, 0, 19), 5.25, "Sas de Tycho", true)
		build_door(base, "garage", Vector3(0, 0, -19), 5.25, "Sas du garage", true)
		wall_with_opening(base, 7.0, -5.4, 6.2)
		build_door(base, "ground_1", Vector3(-5.4, 0, 7), 6.02, "Sas de l’atelier", true)
		wall_with_opening(base, -8.0, 5.3, 6.2)
		build_door(base, "north_1", Vector3(5.3, 0, -8), 6.04, "Secteur du garage", false)
		storage(base, Vector3(-9, 0, 2.8), PI * 0.5)
		storage(base, Vector3(10, 0, 4.5), 0.0)
		storage(base, Vector3(-10, 0, -13.5), 0.0)
		placard(base, "ARMURERIE", Vector3(3.8, 3.25, -10), Color("ffe0a1"))
	else:
		build_door(base, "control_entry", Vector3(0, 0, 19), 5.25, "Sas de Copernic", true)
		build_door(base, "launch_exit", Vector3(0, 0, -19), 5.25, "Sas de lancement", true)
		wall_with_opening(base, 8.0, 0, 6.4)
		build_door(base, "ground_2", Vector3(0, 0, 8), 6.23, "Sas de Copernic", true)
		wall_with_opening(base, -8.0, 0, 6.4)
		build_door(base, "north_2", Vector3(0, 0, -8), 6.24, "Secteur de lancement", false)
		var console := RELAY.instantiate() as Node3D
		console.position = Vector3(-10, 0.04, -13)
		base.add_child(console)
		KIT.model_collision(console)
		placard(base, "TÉLÉMÉTRIE  /  PROCÉDURE D’ÉVACUATION", Vector3(0, 3.4, 7.7), Color("ffc6d1"))
		storage(base, Vector3(11, 0, -14.5), 0.0)
		storage(base, Vector3(-10.4, 0, 13), 0.0)
	var interior_sas := "tutorial" if index == 0 else "ground_%d" % index
	doors[interior_sas].opened.connect(doors["west_security_%d" % index].unlock)
	furnishings.service_cart(base, Vector3(6.15, 0, 15.3), 0.0)


func build_wing(base: Node3D, index: int, side: float, accent: Material) -> void:
	var x := side * 14.0
	var dividers: Array = ROOM_DIVIDERS[index]
	var centers := [float(19.0 + dividers[2]) * 0.5, 0.0, float(-19.0 + dividers[1]) * 0.5]
	if side < 0:
		build_wing_wall(base, -35, centers)
		for slot in range(3):
			var z: float = centers[slot]
			block(base, Vector3(-35, 3.86, z), Vector3(0.51, 1.30, 4.10), FRAME, true)
			build_door(base, "west_room_%d_%d" % [index, slot], Vector3(-35, 0, z), 4.07, "Galerie ouest", false, PI / 2)
	else:
		side_opening(base, 35, 0, -19.15, 19.15, 4.9, 3.2)
		build_door(base, "stair_down_%d" % index, Vector3(35, 0, 4.9), 3.05, "Escalier vers l’étage", false, PI / 2)
	for cut in range(3):
		var z: float = dividers[cut]
		if side<0 and cut>0:
			# Inter-room return routes open only from the northern room.
			for span in [Vector2(-35,-33.7),Vector2(-30.3,-14)]:
				panel_wall(base,Vector3((span.x+span.y)*0.5,0,z),span.y-span.x)
			block(base,Vector3(-32,3.85,z),Vector3(3.4,1.3,0.49),FRAME,true)
			build_door(base,"shortcut_%d_%d"%[index,cut],Vector3(-32,0,z),3.18,"Passage entre les quartiers",true)
			placard(base,"RACCOURCI · VERROU CÔTÉ NORD",Vector3(-32,3.35,z+0.31),Color("cce8df"))
		else:
			panel_wall(base, Vector3(side * 24.5, 0, z), 21.0)
	var pod_x := COLONY.pod_x(index)
	for span in [Vector2(14, pod_x - 2.66), Vector2(pod_x + 2.66, 35)]:
		panel_wall(base, Vector3(side * (span.x + span.y) * 0.5, 0, 19), span.y - span.x)
	block(base, Vector3(side * pod_x, 3.85, 19), Vector3(5.32, 1.31, 0.5), WHITE, true)
	for edge in [-1.0, 1.0]:
		block(base, Vector3(side * pod_x + edge * 2.13, 1.58, 19), Vector3(0.86, 3.18, 0.52), WHITE, true)
	build_wing_wall(base, x, centers)
	for slot in range(3):
		var z: float = centers[slot]
		var room := Node3D.new()
		var kind: String = EAST_ROOMS[index][slot]
		room.name = "Chambre%d" % (slot + 1) if side < 0 else kind
		room.position = Vector3(side * 24.5, 0, z)
		base.add_child(room)
		block(base, Vector3(x, 3.87, z), Vector3(0.52, 1.25, 4.10), FRAME, true)
		for edge in [-2.08, 2.08]:
			KIT.bevel(base, Vector3(x, 1.58, z + edge), Vector3(0.69, 3.16, 0.17), 0.067, FRAME)
			KIT.bevel(base, Vector3(x - side * 0.36, 1.63, z + edge), Vector3(0.048, 2.24, 0.055), 0.017, accent)
		var title: String = "CHAMBRE  %02d" % (index * 3 + slot + 1) if side < 0 else ROOM_TITLES[kind]
		build_door(base, "room_%d_%d_%d" % [index, 0 if side < 0 else 1, slot],
			Vector3(x, 0, z), 4.1, title.capitalize(), false, PI / 2)
		placard(base, title, Vector3(x - side * 0.30, 3.59, z), Color("e3effa"), -side * PI / 2).pixel_size = 0.0047
		for offset in [-5.2, 5.2]:
			ceiling_light(room, Vector3(offset, 4.37, 0), CYAN if side > 0 and kind == "Ferme" else accent)
		if side < 0:
			room_racks.append(furnishings.quarters(room, index * 3 + slot + 1))
		else:
			match kind:
				"Cuisine": furnishings.kitchen(room)
				"Ferme": furnishings.farm(room)
				"Controle": furnishings.control(room, index)


func build_wing_wall(base: Node3D, x: float, centers: Array) -> void:
	var start := -19.16
	for center in [centers[2], centers[1], centers[0], 21.21]:
		var stop: float = center - 2.05
		panel_wall(base, Vector3(x, 0, (start + stop) * 0.5), stop - start, PI / 2.0)
		start = center + 2.05


func build_quarters() -> void:
	var room := get_node("Selene") as Node3D
	for segment in [Vector2(8.2, 2.2), Vector2(18.1, 1.8)]:
		panel_wall(room, Vector3(-4.1, 0, segment.x), segment.y, PI / 2)
	# La porte du dortoir donne sur le couloir principal.
	panel_wall(room, Vector3(-4.1, 0, 11.1), 3.7, PI / 2)
	block(room, Vector3(-4.1, 3.85, 15.0), Vector3(0.34, 1.3, 4.2), FRAME, true)
	block(room, Vector3(-4.0, 3.15, 15), Vector3(0.12, 0.075, 4.0), CYAN)
	build_door(room, "bedroom", Vector3(-4.1, 0, 15.0), 4.10, "Chambre 07", false, PI / 2)
	placard(room, "CHAMBRE 07", Vector3(-4.0, 3.37, 15.0), Color("d8f3ff"), PI * 0.5)
	furnishings.bed(room, Vector3(-11, 0, 16.7))
	furnishings.table(room, Vector3(-8.3, 0, 13.9), Vector2(1.81, 1.16), 1.08)
	furnishings.cabinet(room, Vector3(-11.85, 0, 11.0), 2.0, 2.43, 0.88)
	furnishings.gear_shelf(room, Vector3(-6.29, 0, 9.15))
	furnishings.screen(room, Vector3(-8.7, 1.82, 12.22), 1.55, "CANAL 07\nLIAISON ACTIVE")
	KIT.rod(room, Vector3(-8.7, 1.52, 12.28), Vector3(-8.7, 1.17, 13.54), 0.026, FRAME)
	placard(room, "KAREN  /  QUARTIERS D’ÉQUIPAGE", Vector3(-9.0, 2.82, 8.27), Color("b9e4f3"))


func wall_with_opening(parent: Node3D, z: float, center: float, width: float) -> void:
	var left := center - width * 0.5
	var right := center + width * 0.5
	panel_wall(parent, Vector3((left - 14) * 0.5, 0, z), left + 14)
	panel_wall(parent, Vector3((right + 14) * 0.5, 0, z), 14 - right)
	block(parent, Vector3(center, 3.85, z), Vector3(width, 1.3, 0.48), FRAME, true)
	for x in [left + 0.08, right - 0.08]:
		block(parent, Vector3(x, 1.62, z), Vector3(0.19, 3.25, 0.52), FRAME)


func build_upper_floor(base: Node3D, index: int, accent: Material) -> void:
	var level := Node3D.new()
	level.name = "Etage01"
	level.position.y = UPPER_HEIGHT
	base.add_child(level)
	COLONY.vault(level, Vector3(-1.75, 4.50, -2.0), 13.28, 30.4, [5.1, 3.3, 5.9][index], WHITE)
	COLONY.vault(level, Vector3(23.25, 4.50, -2.0), 11.82, 30.4, [4.1, 5.4, 3.5][index], WHITE)
	for z in [-17.0, 13.0]:
		panel_wall(level, Vector3(10, 0, z), 50.45)
	build_upper_gallery(level, index, accent)
	side_opening(level, 35, 0, -17, 13, -13.9, 3.25)
	build_door(level, "stair_up_%d" % index, Vector3(35, 0, -13.9), 3.10, "Palier de l’escalier", false, PI / 2)
	side_opening(level, 11.5, 0, -17, 13, -8.8, 4.50)
	build_door(level, "upper_%d" % index, Vector3(11.5, 0, -8.8), 4.35, "Sas des transmissions", true, PI / 2)
	side_opening(level, 24, 0, 1.8, 13, 6.2, 3.55)
	build_door(level, "reserve_%d" % index, Vector3(24, 0, 6.2), 3.41, "Réserve de l’étage", false, PI / 2)
	panel_wall(level, Vector3(29.6, 0, 1.8), 11.2)
	storage(level, Vector3(18 if index==2 else 31.2, 0, 9.7), PI * 0.5)
	storage(level, Vector3(18, 0, -13.2), PI * 0.5)
	storage(level, Vector3(21.0, 0, 1.6), 0)
	for x in [-8, 2, 17, 29]:
		for z in [-11.5, -2.7, 7.7]:
			ceiling_light(level, Vector3(x, 4.36, z), accent)
	for z in [-10.75, -6.87]:
		block(level, Vector3(10, 0.019, z), Vector3(49.1, 0.025, 0.066), accent)
	var relay := RELAY.instantiate() as Node3D
	relay.position = Vector3(RELAY_POINT.x, 0.06, RELAY_POINT.z)
	level.add_child(relay)
	KIT.model_collision(relay)
	relays.append(relay)
	placard(level, "TRANSMISSIONS   /   TÉLÉMÉTRIE", Vector3(-5, 3.11, -15.4), Color("dcf1ff"))
	placard(level, "01   /   CONTRÔLE D’ACCÈS", Vector3(32.3, 2.64, -15.5), Color("dcf1ff"))
	build_stairwell(base, accent)


func build_stairwell(base: Node3D, accent: Material) -> void:
	var tower := Node3D.new()
	tower.name = "Escalier"
	base.add_child(tower)
	for height in [0.0, UPPER_HEIGHT]:
		panel_wall(tower, Vector3(43, height, -5.08), 23.8, PI / 2)
		for z in [-17.0, 6.75]:
			panel_wall(tower, Vector3(39, height, z), 8.1)
	block(tower, Vector3(43, 4.75, -5.125), Vector3(0.49, 0.53, 24.11), FRAME, true)
	for z in [-17.0, 6.75]:
		block(tower, Vector3(39, 4.75, z), Vector3(8.35, 0.53, 0.49), FRAME, true)
	block(tower, Vector3(39.0, -0.12, -5.125), Vector3(8.45, 0.28, 24.08), FLOOR, true)
	var low := STAIR_BOTTOM
	var high := STAIR_TOP
	var slope := atan2(UPPER_HEIGHT, absf(high.z - low.z))
	var ramp := block(tower, (low + high) * 0.5 - Vector3.UP * 0.19,
		Vector3(7.60, 0.38, low.distance_to(high)), FINISH.architecture(STEEL, FINISH.Detail.TREAD), true)
	ramp.rotation.x = slope
	var tread := FINISH.architecture(FLOOR, FINISH.Detail.TREAD)
	block(tower, Vector3(39, -0.20, 5.35), Vector3(8.0, 0.45, 2.65), tread, true)
	for rung in range(19):
		var at_z := -8.04 + 0.87 * rung
		block(ramp, Vector3(0, 0.198, at_z), Vector3(5.92, 0.016, 0.036), FRAME)
	for side in [-1.0, 1.0]:
		var rail_offset := Vector3(side * 3.43, 0.94, 0)
		KIT.rod(tower, low + rail_offset, high + rail_offset, 0.045, STEEL)
		for n in range(6):
			var foot := low.lerp(high, n / 5.0) + Vector3(side * 3.43, 0, 0)
			KIT.rod(tower, foot, foot + Vector3.UP * 0.94, 0.033, FRAME)
		for n in range(12):
			block(ramp, Vector3(side * 3.33, 0.20, -7.95 + 1.42 * n), Vector3(0.34, 0.028, 0.17), accent)
	block(tower, Vector3(39, UPPER_HEIGHT - 0.20, -14.5), Vector3(8.0, 0.4, 5.2), tread, true)
	COLONY.vault(tower, Vector3(39, 9.50, -5.08), 4.22, 24.2, 2.2, WHITE)
	for z in [2.9, -4.5, -13.7]:
		ceiling_light(tower, Vector3(39, 9.43, z), accent)
	placard(tower, "ÉTAGE 01   ↑", Vector3(42.50, 2.85, 4.2), Color("c9ebff"), -PI / 2)


func build_west_gallery(base: Node3D, index: int, accent: Material) -> void:
	var hall := Node3D.new()
	hall.name = "GalerieOuest"
	base.add_child(hall)
	block(hall, Vector3(-39.6, -0.15, 0), Vector3(9.2, 0.34, 38.2), FLOOR, true)
	COLONY.vault(hall, Vector3(-39.6, 4.50, 0), 4.73, 38.6, 1.75, WHITE)
	var glass := preload("res://missions/lunar_escape/pressure_glass.gd").material()
	var start := -19.225
	for z in [-12.0,0.0,12.0]:
		panel_wall(hall,Vector3(-44.2,0,(start+z-2.4)*0.5),z-2.4-start,-PI/2)
		for band in [Vector2(0.56,1.12),Vector2(3.65,1.8)]: block(hall,Vector3(-44.2,band.x,z),Vector3(0.48,band.y,4.8),WHITE,true)
		var window := block(hall,Vector3(-44.2,1.93,z),Vector3(0.10,1.60,4.8),glass,true)
		window.get_child(0).set_meta("impact_surface","glass")
		start = z+2.4
	panel_wall(hall,Vector3(-44.2,0,(start+19.225)*0.5),19.225-start,-PI/2)
	for z in [-19.0, 19.0]:
		panel_wall(hall, Vector3(-39.6, 0, z), 9.44)
	for z in [-6.33, 6.33]:
		for x in [-42.9, -36.30]:
			panel_wall(hall, Vector3(x, 0, z), 2.64)
		block(hall, Vector3(-39.6, 3.85, z), Vector3(4.10, 1.30, 0.48), FRAME, true)
		var security: bool = z > 0.0
		build_door(hall, ("west_security_%d" if security else "west_partition_%d") % index,
			Vector3(-39.6, 0, z), 4.00, "Cloison de sécurité" if security else "Galerie nord", security)
	for slot in range(3):
		var z := 12.66 - slot * 12.66
		furnishings.gallery_bay(hall, Vector3(-42.83, 0, z), PI / 2, ["ENTRETIEN", "PAUSE ÉQUIPAGE", "DISTRIBUTION"][slot])
		ceiling_light(hall, Vector3(-39.6, 4.36, z - 2), accent)
		ceiling_light(hall, Vector3(-39.6, 4.36, z + 2), accent)
		block(hall, Vector3(-37.42, 0.032, z), Vector3(0.056, 0.02, 10.85), accent)
	placard(hall, "GALERIE OUEST   /   SERVICES", Vector3(-43.93, 3.35, 13.8), Color("d0e4ee"), PI / 2)


func build_upper_gallery(level: Node3D, index: int, accent: Material) -> void:
	var hall := Node3D.new()
	hall.name = "GalerieServices"
	level.add_child(hall)
	for z in [-14.7, -1.7, 11.0]:
		var size := 13.4 if z == -1.7 else (4.6 if z < 0.0 else 4.0)
		panel_wall(hall, Vector3(-15, 0, z), size, PI / 2)
	for slot in range(2):
		var z := -10.4 if slot == 0 else 7.0
		block(hall, Vector3(-15, 3.85, z), Vector3(0.48, 1.3, 4.0), FRAME, true)
		build_door(hall, "upper_service_%d_%d" % [index, slot], Vector3(-15, 0, z), 3.88, "Couloir technique", false, PI / 2)
	panel_wall(hall, Vector3(-29, 0, -2), 30.45, PI / 2)
	for z in [-17.0, 13.0]:
		panel_wall(hall, Vector3(-22, 0, z), 14.20)
	COLONY.vault(hall, Vector3(-22, 4.50, -2), 7.16, 30.4, 2.4, WHITE)
	for z in [-11.0, -2.0, 7.0]:
		ceiling_light(hall, Vector3(-22, 4.36, z), accent)
		furnishings.gallery_bay(hall, Vector3(-27.25, 0, z), PI / 2, "MAINTENANCE   /   ÉTAGE 01")
		block(hall, Vector3(-19.4, 0.023, z), Vector3(0.063, 0.018, 7.5), accent)
	furnishings.service_cart(hall, Vector3(-16.30, 0, -1.0), -PI / 2)


func side_opening(parent: Node3D, x: float, y: float, start: float, end: float, center: float, width: float) -> void:
	var before := center - width * 0.5
	var after := center + width * 0.5
	panel_wall(parent, Vector3(x, y, (start + before) * 0.5), before - start, PI / 2)
	panel_wall(parent, Vector3(x, y, (end + after) * 0.5), end - after, PI / 2)
	block(parent, Vector3(x, y + 3.84, center), Vector3(0.48, 1.32, width), FRAME, true)


func build_door(parent: Node3D, key: String, point: Vector3, width: float, title: String, secured: bool, yaw := 0.0) -> void:
	var door := DOOR.new()
	door.name = key
	door.position = point
	door.rotation.y = yaw
	parent.add_child(door)
	door.build(width, title, secured)
	for side in [-1.0, 1.0]:
		block(door, Vector3(side * (width * 0.5 + 0.14), 1.60, 0), Vector3(0.32, 3.23, 0.49), FRAME, true)
	doors[key] = door


func open_door(key: String) -> void:
	var door: Node3D = doors[key]
	door.unlock()
	door.open()


func ceiling_light(parent: Node3D, point: Vector3, accent: Material) -> void:
	block(parent, point, Vector3(1.68, 0.08, 0.20), accent)
	var light := SpotLight3D.new()
	light.position = point - Vector3.UP * 0.16
	light.rotation_degrees.x = -90.0
	light.spot_range = 12.0
	light.spot_angle = 72.0
	light.spot_angle_attenuation = 0.45
	light.light_color = Color("d3e6ff") if accent == CYAN else (Color("ffe2bb") if accent == AMBER else Color("ffd3da"))
	light.light_energy = 1.65
	light.light_specular = 0.65
	parent.add_child(light)


func storage(parent: Node3D, point: Vector3, angle: float) -> void:
	var cover := (COVER if point.x > 0 else STORAGE).instantiate() as Node3D
	cover.position = point + Vector3.UP * 0.02
	cover.rotation.y = angle
	cover.scale = Vector3.ONE * 0.79
	parent.add_child(cover)
	KIT.model_collision(cover)


func build_vehicles() -> void:
	bike = Node3D.new()
	bike.name = "Moto"
	bike.set_meta("motorcycle", true)
	bike.position = Vector3(-5, 0, -29.3)
	add_child(bike)
	var bike_wheels: Array[Node3D] = []
	for z in [-1.0, 0.96]:
		bike_wheels.append(make_wheel(bike, Vector3(0, 0.4, z), 0.40, 0.26))
	set_vehicle(bike, [
		[Vector3(0, 0.76, -0.04), Vector3(0.56, 0.68, 1.63)],
		[Vector3(0, 0.40, -1.0), Vector3(0.30, 0.78, 0.80)],
		[Vector3(0, 0.40, 0.96), Vector3(0.30, 0.78, 0.80)],
		[Vector3(0, 1.17, -0.69), Vector3(0.86, 0.14, 0.23)],
	], Vector3(0, 1.67, 0), 23.0, 10.7, 1.16, 0.40, bike_wheels)
	KIT.bevel(bike, Vector3(0, 0.72, 0.03), Vector3(0.48, 0.48, 1.53), 0.17, FRAME)
	KIT.bevel(bike, Vector3(0, 0.94, -0.32), Vector3(0.53, 0.34, 0.75), 0.15, WHITE).rotation.x = -0.13
	KIT.bevel(bike, Vector3(0, 1.11, -0.25), Vector3(0.19, 0.034, 0.26), 0.015, CYAN)
	KIT.bevel(bike, Vector3(0, 0.98, 0.42), Vector3(0.41, 0.13, 0.74), 0.057, GRIP)
	for x in [-0.16, 0.16]:
		KIT.rod(bike, Vector3(x, 0.42, -1.0), Vector3(x, 1.19, -0.69), 0.057, STEEL)
	KIT.rod(bike, Vector3(-0.43, 1.20, -0.69), Vector3(0.43, 1.20, -0.69), 0.046, GRIP)
	block(bike, Vector3(0, 1.00, -1.05), Vector3(0.34, 0.16, 0.08), WHITE)
	block(bike, Vector3(0, 0.77, 1.08), Vector3(0.26, 0.11, 0.06), RED)
	bike.set_meta("display_name", "Moto")
	bike.set_meta("cannon_muzzle", Vector3(0.27, 1.0, -1.6))
	KIT.rod(bike, Vector3(0.27, 1.0, -0.65), Vector3(0.27, 1.0, -1.6), 0.075, STEEL)
	scout = build_tank("Eclaireur", "Éclaireur S-01", Vector3(6.2, 0, -29.0), CYAN, 23.0)
	transport = build_tank("Blinde", "Blindé T-06", at(1, 0, 0, -31), AMBER, 24.0)
	for ride in [bike,scout,transport]:
		var suspension:=preload("res://missions/lunar_escape/vehicle_motion.gd").new()
		ride.add_child(suspension);suspension.setup(ride,self)


func build_tank(id: String, title: String, point: Vector3, accent: Material, speed: float) -> Node3D:
	var tank := Node3D.new()
	tank.name = id
	tank.position = point
	add_child(tank)
	var armor := FINISH.architecture(ARMOR, FINISH.Detail.POWDER_COAT)
	var cannon:=preload("res://missions/lunar_escape/tank_cannon.gd").new()
	cannon.name="Canon";cannon.position=Vector3(0,2.25,-1.85);tank.add_child(cannon)
	KIT.bevel(tank, Vector3(0, 0.93, 0), Vector3(3.25, 1.28, 5.2), 0.24, armor)
	KIT.bevel(tank, Vector3(0, 1.76, -0.58), Vector3(2.8, 1.08, 2.8), 0.22, FRAME)
	KIT.bevel(tank, Vector3(0, 1.94, -1.95), Vector3(2.4, 0.43, 0.13), 0.062, INSET).rotation.x = -0.20
	KIT.bevel(tank, Vector3(0, 1.7, 2.55), Vector3(1.56, 1.02, 0.16), 0.075, STEEL)
	KIT.bevel(tank, Vector3(0, 1.09, -2.55), Vector3(2.73, 0.72, 0.30), 0.12, armor).rotation.x = -0.34
	KIT.bevel(tank, Vector3(0.74, 2.00, 1.06), Vector3(0.75, 0.39, 0.72), 0.13, FRAME)
	KIT.rod(tank, Vector3(0.74, 2.05, 1.08), Vector3(0.74, 2.43, 1.08), 0.16, STEEL)
	KIT.bevel(tank, Vector3(0.74, 2.44, 1.08), Vector3(0.66, 0.26, 0.51), 0.11, armor)
	KIT.bevel(tank, Vector3(0.74, 2.44, 0.81), Vector3(0.38, 0.098, 0.036), 0.02, accent)
	var truck_wheels: Array[Node3D] = []
	var hatches: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var x: float = side * 1.50
		for z in [-1.9, -0.96, 0.0, 0.96, 1.9]:
			truck_wheels.append(make_wheel(tank, Vector3(x + side * 0.18, 0.52, z), 0.48, 0.57))
		build_track(tank, side * 1.68)
		KIT.bevel(tank, Vector3(x * 0.82, 1.15, -2.72), Vector3(0.36, 0.17, 0.11), 0.044, accent)
		KIT.bevel(tank, Vector3(side * 1.69, 1.22, 0.0), Vector3(0.72, 0.26, 4.96), 0.099, armor)
		KIT.bevel(tank, Vector3(x * 1.08, 1.53, 0.73), Vector3(0.15, 0.22, 2.5), 0.049, STEEL)
		for z in [-0.21, 0.08, 0.37, 0.66, 0.95, 1.24]:
			KIT.bevel(tank, Vector3(x * 1.10, 1.58, z), Vector3(0.13, 0.27, 0.086), 0.032, FRAME)
		var hatch := Node3D.new()
		hatch.position = Vector3(x * 0.963, 1.77, -0.89)
		tank.add_child(hatch)
		KIT.bevel(hatch, Vector3.ZERO, Vector3(0.15, 0.89, 1.19), 0.059, STEEL)
		KIT.bevel(hatch, Vector3(signf(x) * 0.082, 0.16, -0.12), Vector3(0.034, 0.29, 0.62), 0.014, INSET)
		KIT.bevel(hatch, Vector3(signf(x) * 0.084, -0.22, 0.30), Vector3(0.048, 0.078, 0.21), 0.016, accent)
		hatches.append(hatch)
	KIT.rod(tank, Vector3(-1.16, 2.18, 0.69), Vector3(-1.16, 3.01, 0.69), 0.027, STEEL)
	set_vehicle(tank, [
		[Vector3(0, 0.93, 0), Vector3(3.25, 1.28, 5.20)],
		[Vector3(0, 1.76, -0.58), Vector3(2.8, 1.08, 2.8)],
		[Vector3(0, 0.53, 0), Vector3(4.11, 1.05, 4.87)],
	], Vector3(0, 2.67, -1.52), speed, 8.1, 0.96, 0.48, truck_wheels)
	tank.set_meta("display_name", title)
	tank.set_meta("cannon_muzzle", Vector3(0, 2.25, -3.51))
	tank.set_meta("sealed", true)
	tank.set_meta("hatches", hatches)
	placard(tank, title.to_upper(), Vector3(0, 1.87, 2.64), Color("ffde9d"))
	return tank


func build_track(tank: Node3D, x: float) -> void:
	var motion:=preload("res://missions/lunar_escape/vehicle_motion.gd")
	var links: Array=tank.get_meta("track_links",[])
	for i in range(48):
		var link:=KIT.bevel(tank,Vector3.ZERO,Vector3(.70,.085,.202),.022,GRIP)
		var phase: float=i*motion.TRACK_LENGTH/48.0
		motion.track_pose(link,phase,x);links.append({"node":link,"phase":phase,"x":x})
	tank.set_meta("track_links",links)


func animate_hatch(ride: Node3D, side: int, opened: bool) -> void:
	var hatch: Node3D = ride.get_meta("hatches")[side]
	create_tween().tween_property(hatch, "position:z", 0.04 if opened else -0.89, 0.33).set_trans(Tween.TRANS_SINE)


func set_vehicle(ride: Node3D, body_parts: Array, eye: Vector3, speed: float, acceleration: float,
		turn: float, wheel_radius: float, wheels: Array[Node3D]) -> void:
	var body := VEHICLE_COLLISION.new()
	body.name = "ParkedCollision"
	ride.add_child(body)
	body.build(body_parts)
	ride.set_meta("eye_position", eye)
	ride.set_meta("top_speed", speed)
	ride.set_meta("acceleration", acceleration)
	ride.set_meta("turn_rate", turn)
	ride.set_meta("wheel_radius", wheel_radius)
	ride.set_meta("wheels", wheels)


func make_wheel(parent: Node3D, point: Vector3, radius: float, width: float) -> Node3D:
	var wheel := Node3D.new()
	wheel.position = point
	parent.add_child(wheel)
	cylinder(wheel, Vector3.ZERO, radius * 0.96, radius * 0.96, width, GRIP, Vector3(0, 0, PI / 2))
	cylinder(wheel, Vector3.ZERO, radius * 0.61, radius * 0.61, width + 0.025, STEEL, Vector3(0, 0, PI / 2))
	cylinder(wheel, Vector3.ZERO, radius * 0.31, radius * 0.31, width + 0.058, FRAME, Vector3(0, 0, PI / 2))
	for tread in range(12):
		var angle := TAU * tread / 12
		var block_position := Vector3(0, cos(angle), sin(angle)) * radius * 0.96
		KIT.bevel(wheel, block_position, Vector3(width * 0.90, radius * 0.09, radius * 0.20), 0.013, GRIP).rotation.x = angle
	return wheel


func build_launch_pad() -> void:
	build_roof_access()
	var area := Node3D.new()
	area.name = "LaunchPad"
	area.position = PAD_ORIGIN
	add_child(area)
	# The roof is the arena floor; this inset is raised to avoid coplanar surfaces.
	block(area, Vector3(0, 0.015, -241), Vector3(25, 0.03, 35), FLOOR)
	for x in [-10.4, 10.4]:
		block(area, Vector3(x, 0.04, -242), Vector3(0.21, 0.055, 22), AMBER)
	for x in [-7.0, 7.0]:
		for z in [-222.0, -236.0, -251.0]:
			KIT.bevel(area, Vector3(x, 0.4, z), Vector3(2.2, 0.8, 1.4), 0.12, FRAME, true)
			KIT.bevel(area, Vector3(x, 0.81, z), Vector3(1.95, 0.055, 1.12), 0.02, AMBER)
	rocket = Node3D.new()
	rocket.name = "Fusee"
	rocket.position = Vector3(0, 0, -249)
	area.add_child(rocket)
	var ceramic := FINISH.architecture(FINISH.create(Color("d9dcd5"), 0.15, 0.72, 0.22), FINISH.Detail.WALL)
	var metal := FINISH.architecture(STEEL, FINISH.Detail.DOOR)
	var paint := FINISH.create(Color("9e4035"), 0.18, 0.65, 0.30)
	cylinder(rocket, Vector3(0, 6.5, 0), 2.03, 2.03, 9, ceramic)
	cylinder(rocket, Vector3(0, 12.8, 0), 0.18, 2.03, 3.6, ceramic)
	cylinder(rocket, Vector3(0, 3.2, 0), 2.09, 2.09, 1.5, paint)
	for height in [4.2, 6.1, 8.0, 10.5]:
		cylinder(rocket, Vector3(0, height, 0), 2.047, 2.047, 0.06, metal)
	for i in range(16):
		var angle := TAU * i / 16.0
		var side := Vector3(sin(angle), 0, cos(angle))
		KIT.rod(rocket, side * 2.037 + Vector3.UP * 4.3, side * 2.037 + Vector3.UP * 10.4, 0.012, FRAME, 6)
		for height in [4.29, 6.19, 8.09, 10.41]:
			ball(rocket, side * 2.05 + Vector3.UP * height, Vector3.ONE * 0.055, metal)
	cylinder(rocket, Vector3(0, 1.1, 0), 1.03, 1.51, 2.2, FRAME)
	cylinder(rocket, Vector3(0, 9.2, 0), 2.09, 2.09, 0.35, FRAME)
	block(rocket, Vector3(0, 3.73, 2.06), Vector3(1.02, 1.74, 0.15), FRAME)
	block(rocket, Vector3(0, 4.04, 2.16), Vector3(0.61, 0.51, 0.08), CYAN)
	placard(rocket, "HELIX", Vector3(0, 7.6, 2.06), Color("151e32")).font_size = 72
	for x in [-3.1, 3.1]:
		block(rocket, Vector3(x, 1.4, -0.15), Vector3(0.32, 3.0, 0.66), FRAME).rotation.z = signf(x) * 0.39
		block(rocket, Vector3(x * 1.13, 0.15, -0.15), Vector3(1.1, 0.30, 0.83), FRAME)
	rocket_flame = Node3D.new()
	rocket.add_child(rocket_flame)
	for inner in [false,true]:
		var exhaust := ShaderMaterial.new()
		exhaust.shader = preload("res://missions/lunar_escape/rocket_plume.gdshader")
		exhaust.set_shader_parameter("inner",inner)
		var jet := MeshInstance3D.new()
		var plume := CylinderMesh.new()
		plume.top_radius = 0.34 if inner else 0.64
		plume.bottom_radius = 0.78 if inner else 1.8
		plume.height = 7.0 if inner else 10.0
		exhaust.set_shader_parameter("plume_length",plume.height)
		plume.cap_top = false; plume.cap_bottom = false
		plume.radial_segments = 48; plume.rings = 16
		jet.mesh = plume
		jet.material_override = exhaust
		jet.position.y = -plume.height*0.5-0.1
		jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rocket_flame.add_child(jet)
	var engine_light := OmniLight3D.new()
	engine_light.light_color = Color("ffac63")
	engine_light.light_energy = 3.0
	engine_light.omni_range = 14.0
	rocket_flame.add_child(engine_light)
	rocket_flame.hide()
	preload("res://missions/lunar_escape/rocket_collision.gd").build(rocket)
	for step in range(6):
		block(area, Vector3(0, 0.13 + step * 0.25, -243.8 - step * 0.39), Vector3(1.8, 0.26 + step * 0.50, 0.42), FRAME, true)
	var field := StandardMaterial3D.new()
	field.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	field.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	field.albedo_color = Color(1.0, 0.17, 0.37, 0.17)
	for z in [-240.0, -258.0]:
		pad_barriers.append(block(area, Vector3(0, 2.0, z), Vector3(24, 4, 0.10), field, true))
	for x in [-12.0, 12.0]:
		pad_barriers.append(block(area, Vector3(x, 2.0, -249), Vector3(0.10, 4, 18), field, true))
	for panel in pad_barriers:
		block(panel, Vector3(0, 1.96, 0), (panel.mesh as BoxMesh).size * Vector3(1, 0.014, 1), RED)
	set_pad_lock(false)

func build_roof_access() -> void:
	var roof := Node3D.new()
	roof.name = "ToitCopernic"
	add_child(roof)
	roof.position.z = COPERNIC_Z
	var roof_material := FINISH.create(Color("424a50"),0.2,0.84,0.22)
	# Split the deck around the stair opening on its north-east edge.
	for slab in [Vector4(-44,19,-35,35),Vector4(25,44,-35,35),Vector4(19,25,-18,35)]:
		block(roof,Vector3((slab.x+slab.y)*0.5,ROOF_HEIGHT-0.2,(slab.z+slab.w)*0.5),Vector3(slab.y-slab.x,0.4,slab.w-slab.z),roof_material,true)
	for x in [-44.0,44.0]:
		block(roof,Vector3(x,ROOF_HEIGHT+0.55,0),Vector3(0.18,1.1,70),FRAME,true)
	for z in [-35.0,35.0]:
		for span in ([Vector2(-44,19),Vector2(25,44)] if z<0 else [Vector2(-44,44)]):
			block(roof,Vector3((span.x+span.y)*0.5,ROOF_HEIGHT+0.55,z),Vector3(span.y-span.x,1.1,0.18),FRAME,true)
	for x in [-40.0,40.0]:
		for z in [-32.0,32.0]:
			var ground: float = surface_profile.elevation(x,COPERNIC_Z+z)-0.4
			block(roof,Vector3(x,(ROOF_HEIGHT+ground)*0.5,z),Vector3(0.6,ROOF_HEIGHT-ground,0.6),FRAME,true)
	var a := ROOF_STAIRS_BOTTOM
	var b := ROOF_STAIRS_TOP
	var ramp := block(self,(a+b)*0.5-Vector3.UP*0.12,Vector3(4.4,0.24,a.distance_to(b)),STEEL,true)
	ramp.rotation.x = -atan2(ROOF_HEIGHT,32)
	for i in range(55):
		var p := a.lerp(b,(i+0.5)/55.0)
		block(self,p-Vector3.UP*0.08,Vector3(4.3,0.16,32.0/55.0),FLOOR)
	for side in [-2.3,2.3]:
		var rail_start := a.lerp(b,0.10)
		var rail := block(self,(rail_start+b)*0.5+Vector3(side,0.55,0),Vector3(0.12,1.1,rail_start.distance_to(b)),FRAME,true)
		rail.rotation.x = ramp.rotation.x
		KIT.rod(self,rail_start+Vector3(side,1.1,0),b+Vector3(side,1.1,0),0.045,CYAN)
	# Sealed stair tower: its only ground access is the interior north door.
	var lining := FINISH.architecture(WHITE,FINISH.Detail.USER_WALL_PHOTO)
	for side in [-2.55,2.55]:
		for segment in range(16):
			var bottom := 3.6 if side<0 and segment==0 else -0.5
			pressure_panel(Vector3(a.x+side,bottom,a.z+(segment+0.5)*2),Vector3(0.42,22.5-bottom,2.02),lining)
	block(self,at(2,22,22.5,-34),Vector3(5.6,0.35,32.4),lining,true)
	pressure_panel(at(2,22,12,-50),Vector3(5.5,10.5,0.4),lining)
	pressure_panel(at(2,22,ROOF_HEIGHT+3.6,-18),Vector3(5.5,2.4,0.4),lining)
	# Corridor north from the building, then east to the foot of the enclosed stair.
	block(self,at(2,0,-0.12,-33),Vector3(6,0.24,28),FLOOR,true)
	block(self,at(2,11,-0.12,-50),Vector3(28,0.24,6),FLOOR,true)
	pressure_panel(at(2,-3,-0.5,-36),Vector3(0.42,12.5,34),lining)
	pressure_panel(at(2,3,-0.5,-33),Vector3(0.42,12.5,28),lining)
	pressure_panel(at(2,11,-0.5,-53),Vector3(28,12.5,0.42),lining)
	pressure_panel(at(2,11,-0.5,-47),Vector3(16,12.5,0.42),lining)
	pressure_panel(at(2,25,-0.5,-50),Vector3(0.42,12.5,6),lining)
	block(self,at(2,0,12,-33),Vector3(6.5,0.3,28),lining,true)
	block(self,at(2,8,12,-50),Vector3(22.5,0.3,6.5),lining,true)
	block(self,at(2,22,12,-51.5),Vector3(6.5,0.3,3.3),lining,true)
	block(self,at(2,22,ROOF_HEIGHT+3.6,-18.8),Vector3(5.4,0.3,3.0),lining,true)
	for z in [-24,-34,-44]: ceiling_light(self,at(2,0,3.3,z),CYAN)
	for t in [0.2,0.5,0.8]: ceiling_light(self,a.lerp(b,t)+Vector3.UP*3.0,CYAN)
	placard(self,"FUSÉE · TOUR INTÉRIEURE →",at(2,0,2.2,-48),Color("b7e7f2"))
	placard(self,"ACCÈS AU TOIT · SAS EVA",at(2,22,ROOF_HEIGHT+2.5,-18.1),Color("b7e7f2"),PI)

func pressure_panel(bottom: Vector3, size: Vector3, material: Material) -> void:
	var wall := block(self,bottom+Vector3.UP*size.y*.5,size,material,true)
	wall.add_to_group("pressure_tower_walls")
	var along_x := size.x>size.z
	var width := size.x if along_x else size.z
	# Flush ribs and seals are visual details, never a climbable ladder of colliders.
	for sign in [-1,1]:
		for column in range(ceili(width/2.5)+1):
			var offset := -width*.5+minf(width,column*2.5)
			var p := Vector3(offset,0,sign*(size.z*.5+.014)) if along_x else Vector3(sign*(size.x*.5+.014),0,offset)
			KIT.bevel(wall,p,Vector3(.055,size.y,.028) if along_x else Vector3(.028,size.y,.055),.008,FRAME)
		for row in range(1,ceili(size.y/3)):
			var p := Vector3(0,-size.y*.5+row*3,sign*(size.z*.5+.01)) if along_x else Vector3(sign*(size.x*.5+.01),-size.y*.5+row*3,0)
			KIT.bevel(wall,p,Vector3(width,.028,.018) if along_x else Vector3(.018,.028,width),.006,FRAME)


func set_pad_lock(active: bool) -> void:
	for panel in pad_barriers:
		panel.visible = active
		panel.get_child(0).set_deferred("collision_layer", 1 if active else 0)


static func gun(parent: Node3D, key: String, first_person := false) -> Node3D:
	var model := ARMORY.new()
	parent.add_child(model)
	model.build(key, first_person)
	return model


static func block(parent: Node3D, point: Vector3, size: Vector3, material: Material, solid := false) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var instance := mesh_node(parent, point, box, material)
	if solid:
		var body := StaticBody3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		instance.add_child(body)
	return instance


static func cylinder(parent: Node3D, point: Vector3, top: float, bottom: float, height: float,
		material: Material, angles := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 24
	var instance := mesh_node(parent, point, mesh, material)
	instance.rotation = angles
	return instance


static func ball(parent: Node3D, point: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var instance := mesh_node(parent, point, mesh, material)
	instance.scale = size
	return instance


static func mesh_node(parent: Node3D, point: Vector3, mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = FINISH.material(material)
	instance.position = point
	parent.add_child(instance)
	return instance


static func placard(parent: Node3D, title: String, point: Vector3, color: Color, yaw := 0.0) -> Label3D:
	var label := Label3D.new()
	# Navigation and interactions belong in the HUD; no free-floating signs in rooms.
	label.visible = false
	label.set_meta("decorative_sign", true)
	label.text = title
	label.position = point
	label.rotation.y = yaw
	label.font = preload("res://assets/fonts/DejaVuSans.ttf")
	label.font_size = 48
	label.pixel_size = 0.0058
	label.modulate = color
	label.outline_size = 4
	parent.add_child(label)
	return label

