extends Node3D
## Edited return sequence. Interplanetary travel is explicitly elided, never flown across the level.
## Earth shots use kilometres for the planet/trajectory, with a close-up model for readable framing.
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const LAYER := 1 << 19
const EARTH_RADIUS := 6371.0
var game: Node3D
var earth: MeshInstance3D
var atmosphere: MeshInstance3D
var ship: Node3D
var capsule: Node3D
var service: Node3D
var canopy: Node3D
var ocean: MeshInstance3D
var plasma: ShaderMaterial
var heat_light: OmniLight3D
var cabin_environment: Environment
var phase := "transfer"
var entry_altitude := 120.0

func setup(campaign: Node3D) -> void:
	game = campaign
	name = "RetourTerre"
	cabin_environment = Environment.new()
	cabin_environment.background_mode = Environment.BG_COLOR
	cabin_environment.background_color = Color("02040a")
	cabin_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	cabin_environment.ambient_light_color = Color("aec4e3")
	cabin_environment.ambient_light_energy = 0.3
	cabin_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	game.film.environment = cabin_environment
	game.film.cull_mask = LAYER
	game.film.far = 30000.0
	game.film.fov = 54
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-25,0)
	sun.light_energy = 1.4; sun.light_cull_mask = LAYER
	add_child(sun)
	var surface := StandardMaterial3D.new()
	surface.albedo_texture = WORLD.EARTH_TEXTURE
	surface.roughness = 0.95
	earth = sphere(EARTH_RADIUS,surface)
	earth.position = Vector3(0,-EARTH_RADIUS,0)
	earth.rotation = Vector3(1.15,1.1,-0.23)
	var air := ShaderMaterial.new()
	air.shader = preload("res://missions/lunar_escape/return_atmosphere.gdshader")
	atmosphere = sphere(EARTH_RADIUS+18,air)
	atmosphere.position = earth.position
	ship = Node3D.new(); add_child(ship)
	capsule = Node3D.new(); ship.add_child(capsule)
	var ceramic := WORLD.FINISH.create(Color("d9dedb"),0.12,0.76,0.15)
	var carbon := WORLD.FINISH.create(Color("222326"),0.0,0.96,0.2)
	var metal := WORLD.FINISH.create(Color("758592"),0.7,0.48,0.1)
	WORLD.cylinder(capsule,Vector3(0,0.1,0),0.55,1.4,2.0,ceramic)
	WORLD.cylinder(capsule,Vector3(0,1.16,0),0.45,0.55,0.16,metal)
	WORLD.cylinder(capsule,Vector3(0,-0.99,0),1.42,1.3,0.21,carbon)
	for i in range(12):
		var angle := TAU*i/12.0
		var direction := Vector3(cos(angle),0,sin(angle))
		KIT.rod(capsule,direction*1.39+Vector3.DOWN*0.88,direction*0.6+Vector3.UP*1.0,0.008,metal)
		KIT.rod(capsule,direction*0.13+Vector3.DOWN*1.1,direction*1.26+Vector3.DOWN*1.1,0.012,metal)
	var glass := WORLD.FINISH.create(Color("142333"),0.45,0.18,0.02)
	for x in [-0.36,0.36]:
		KIT.bevel(capsule,Vector3(x,0.50,0.76),Vector3(0.32,0.32,0.08),0.055,metal).rotation.x = 0.38
		KIT.bevel(capsule,Vector3(x,0.50,0.81),Vector3(0.25,0.25,0.04),0.04,glass).rotation.x = 0.38
	service = Node3D.new(); ship.add_child(service)
	WORLD.cylinder(service,Vector3(0,-2.35,0),1.3,1.3,2.4,metal)
	WORLD.cylinder(service,Vector3(0,-3.75,0),0.35,0.64,0.55,carbon)
	for side in [-1,1]:
		KIT.rod(service,Vector3(side*1.1,-2.25,0),Vector3(side*3.3,-2.25,0),0.05,metal)
		for cell in range(3):
			KIT.bevel(service,Vector3(side*(2.0+cell*0.82),-2.25,0),Vector3(0.78,0.045,2.2),0.02,glass)
	plasma = ShaderMaterial.new(); plasma.shader = preload("res://missions/lunar_escape/reentry_plasma.gdshader")
	# Bow shock around the heat shield, with the wake streaming aft (+local Y).
	var shock := WORLD.ball(capsule,Vector3(0,-0.97,0),Vector3(3.05,0.65,3.05),plasma)
	shock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wake_mesh := CylinderMesh.new()
	wake_mesh.top_radius = 1.8; wake_mesh.bottom_radius = 1.53; wake_mesh.height = 4.8
	wake_mesh.cap_bottom = false; wake_mesh.cap_top = false; wake_mesh.radial_segments = 64
	var wake := WORLD.mesh_node(capsule,Vector3(0,1.35,0),wake_mesh,plasma)
	wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	heat_light = OmniLight3D.new(); capsule.add_child(heat_light)
	heat_light.position.y = -1.6; heat_light.light_color = Color("ff8a45")
	heat_light.omni_range = 6; heat_light.light_cull_mask = LAYER
	heat_light.light_energy = 0
	build_parachute()
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("194e68"); water.roughness = 0.27; water.metallic = 0.35
	var water_mesh := PlaneMesh.new(); water_mesh.size = Vector2(16000,16000)
	ocean = WORLD.mesh_node(self,Vector3.ZERO,water_mesh,water); ocean.hide()
	for visual in find_children("*","GeometryInstance3D",true,false):
		visual.layers = LAYER
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	transfer(0)

func sphere(radius: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new(); mesh.radius = radius; mesh.height = radius*2
	mesh.radial_segments = 256; mesh.rings = 128
	return WORLD.mesh_node(self,Vector3.ZERO,mesh,material)

func build_parachute() -> void:
	canopy = Node3D.new(); capsule.add_child(canopy); canopy.hide()
	var cloth := ShaderMaterial.new()
	cloth.shader = preload("res://missions/lunar_escape/parachute_fabric.gdshader")
	var dome := SphereMesh.new(); dome.radius = 3.9; dome.height = 3.9
	dome.is_hemisphere = true; dome.radial_segments = 48; dome.rings = 24
	WORLD.mesh_node(canopy,Vector3(0,9.5,0),dome,cloth)
	for i in range(16):
		var direction := Vector3(cos(TAU*i/16.0),0,sin(TAU*i/16.0))
		KIT.rod(canopy,direction*0.7+Vector3.UP*0.4,direction*3.86+Vector3.UP*9.5,0.012,WORLD.WHITE)

func play() -> void:
	game.speak("TROIS JOURS PLUS TARD · APPROCHE DE LA TERRE",5.0)
	var coast := create_tween()
	coast.tween_method(transfer,0.0,1.0,5.0)
	await coast.finished
	game.speak("ORDINATEUR · Module de service séparé. Bouclier thermique orienté. Rentrée atmosphérique.",8.0)
	phase = "reentry"
	var entry := create_tween()
	entry.tween_method(reentry,0.0,1.0,9.0)
	await entry.finished
	phase = "descent"
	game.speak("TERRE · Parachutes ouverts. Équipe de récupération en approche. Bienvenue à la maison.",6.0)
	var landing := create_tween()
	landing.tween_method(descent,0.0,1.0,6.0)
	await landing.finished
	phase = "landed"

func transfer(t: float) -> void:
	ship.position = Vector3(t*12,18000-t*300,0)
	ship.rotation = Vector3(0.7,0.45,-0.7)
	game.frame_camera(ship.position+Vector3(3,28,5),ship.position+Vector3(2,-6,4))

func reentry(t: float) -> void:
	# A shallow arc about Earth's centre; no straight flight through the globe.
	entry_altitude = lerpf(120,28,t)
	var angle := t*0.11
	ship.position = earth.position+Vector3(0,cos(angle),-sin(angle))*(EARTH_RADIUS+entry_altitude)
	var aft := Vector3(0,0.16,0.987).normalized()
	ship.quaternion = Quaternion(Vector3.UP,aft)
	service.visible = t<0.25
	service.position = Vector3(t*12,-t*25,t*2)
	var heat := smoothstep(0.03,0.28,t)*(1.0-smoothstep(0.72,1.0,t))
	plasma.set_shader_parameter("heat",heat)
	heat_light.light_energy = heat*2.8
	game.frame_camera(ship.position+Vector3(10,5,17),ship.position+Vector3(0,-2,-2))

func descent(t: float) -> void:
	earth.hide(); atmosphere.hide(); service.hide(); ocean.show(); canopy.show()
	plasma.set_shader_parameter("heat",0.0); heat_light.light_energy = 0
	cabin_environment.background_color = Color("89aec9")
	cabin_environment.ambient_light_energy = 0.7
	ship.position = Vector3(0,lerpf(12,1.1,t),0)
	ship.rotation = Vector3(sin(t*8)*0.025,0.2,sin(t*11)*0.04)
	canopy.scale = Vector3.ONE*lerpf(0.65,1.0,smoothstep(0,0.15,t))
	game.frame_camera(Vector3(17,10,28),Vector3(0,ship.position.y+3.8,0))
