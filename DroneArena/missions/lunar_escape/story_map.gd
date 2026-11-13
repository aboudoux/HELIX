extends RefCounted
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const ROUTES := preload("res://missions/lunar_escape/lunar_routes.gd")

static func build(world: Node3D) -> void:
	living_quarters(world)
	hangar(world)
	science_outpost(world)
	wreck_site(world)
	for i in range(3):
		var base: Node3D = world.get_node(["Selene","Tycho","Copernic"][i])
		for slot in range(3):
			var room: Node3D = base.get_node("Chambre%d"%(slot+1))
			WORLD.placard(room,["MAËL · BOTANISTE","NOOR · COMMUNICATIONS","ÉQUIPE MÉDICALE"][slot] if i==0 else "QUARTIERS · ÉQUIPE %d"%(slot+1),Vector3(6,2.4,-2.0),Color("ccddda"))
		WORLD.placard(base,["HABITAT → SERRE / QUARTIERS ←","ATELIERS → / LINA ← / HANGAR ↑","LABORATOIRE À L’ÉTAGE / LANCEMENT ↑"][i],Vector3(0,3.5,6),Color("f1d6aa"))

static func living_quarters(world: Node3D) -> void:
	var room: Node3D = world.get_node("Selene/Chambre3")
	var clinic := Node3D.new()
	clinic.name = "Infirmerie"
	room.add_child(clinic)
	clinic.position = Vector3(4.2,0,-1.0)
	world.furnishings.bed(clinic,Vector3.ZERO)
	world.furnishings.screen(clinic,Vector3(1.55,1.8,0.4),0.85,"TRIAGE\nÉVACUATION 06:21")
	KIT.rod(clinic,Vector3(1.25,0.1,-0.8),Vector3(1.25,2.3,-0.8),0.025,WORLD.STEEL)
	KIT.bevel(clinic,Vector3(1.25,1.9,-0.8),Vector3(0.18,0.35,0.09),0.03,WORLD.CYAN)
	WORLD.placard(clinic,"INFIRMERIE · ÉVACUÉE",Vector3(0,2.6,-1.3),Color("b2eddb"))
	# The decorative picture cards had no mounting surface; omit them entirely.

static func hangar(world: Node3D) -> void:
	var hall := Node3D.new()
	hall.name = "HangarTycho"
	world.add_child(hall)
	hall.position = WORLD.at(1,0,0,-30)
	WORLD.block(hall,Vector3(0,-0.10,0),Vector3(20,0.2,19),WORLD.FLOOR,true)
	WORLD.block(hall,Vector3(0,6.0,0),Vector3(20,0.25,19),WORLD.FRAME,true)
	for x in [-9.8,9.8]:
		WORLD.block(hall,Vector3(x,2.9,0),Vector3(0.35,5.8,19),WORLD.FINISH.architecture(WORLD.WHITE,WORLD.FINISH.Detail.USER_WALL_PHOTO),true)
		for z in [-8.0,0.0,8.0]:
			KIT.bevel(hall,Vector3(x*0.96,3,z),Vector3(0.45,6,0.55),0.07,WORLD.STEEL)
	for z in [-8.8,8.8]:
		WORLD.block(hall,Vector3(0,5.0,z),Vector3(19.5,1.8,0.4),WORLD.STEEL,true)
		WORLD.placard(hall,"TYCHO · HANGAR T-06",Vector3(0,5.05,z+0.25),Color("f5d29a")).billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	# A side catwalk and ramp make a loop around the garage floor.
	WORLD.block(hall,Vector3(7.2,2.8,-2.8),Vector3(2.6,0.2,10),WORLD.STEEL,true)
	var a := Vector3(7.2,0.0,8.4)
	var b := Vector3(7.2,2.8,2.2)
	var ramp := WORLD.block(hall,(a+b)*0.5-Vector3.UP*0.12,Vector3(2.6,0.22,a.distance_to(b)),WORLD.STEEL,true)
	ramp.rotation.x = atan2(2.8,6.2)
	for x in [5.86,8.54]:
		KIT.rod(hall,Vector3(x,3.85,-7.7),Vector3(x,3.85,2.1),0.035,WORLD.STEEL)
		WORLD.block(hall,Vector3(x,3.35,-2.8),Vector3(0.07,0.95,10),WORLD.FRAME,true)
	for z in [-5,3]: world.ceiling_light(hall,Vector3(0,5.7,z),WORLD.AMBER)
	for x in [-6.5,-4.6]:
		WORLD.cylinder(hall,Vector3(x,1.0,-5.4),0.65,0.65,2,WORLD.STEEL)
		KIT.bevel(hall,Vector3(x,2.1,-5.4),Vector3(1.0,0.12,1.0),0.04,WORLD.AMBER)
	WORLD.placard(hall,"PRÉPARATION DU BLINDÉ · LINA",Vector3(-6.3,2.6,-5.4),Color("ffe0ae"))

static func science_outpost(world: Node3D) -> void:
	var lab := Node3D.new()
	lab.name = "LaboratoireSignal"
	world.get_node("Copernic/Etage01").add_child(lab)
	lab.position = Vector3(1.0,0,5.0)
	for x in [-2.6,2.6]:
		world.furnishings.table(lab,Vector3(x,0,0),Vector2(2.2,1.8),0.95)
		WORLD.ball(lab,Vector3(x,1.35,0),Vector3(0.65,0.4,0.7),WORLD.FRAME)
		for j in range(4): KIT.rod(lab,Vector3(x,1.5,0),Vector3(x+cos(j*PI/2)*0.85,1.1,sin(j*PI/2)*0.6),0.04,WORLD.STEEL)
		world.furnishings.screen(lab,Vector3(x,1.7,0.65),1.5,"SIGNAL EXTERNE\nCOMMANDE HOSTILE")
	WORLD.placard(lab,"COPERNIC · ANALYSE DU SIGNAL",Vector3(0,3.0,0.8),Color("c1dbf1"))
	var ring := Node3D.new()
	ring.name = "BalconDuCratere"
	world.add_child(ring)
	ring.position = WORLD.at(2,78,6.5,-26)
	for i in range(32):
		var a := TAU*i/32.0
		var b := TAU*(i+1)/32.0
		var p := Vector3(cos(a),0,sin(a))*18
		var q := Vector3(cos(b),0,sin(b))*18
		var deck := WORLD.block(ring,(p+q)*0.5,Vector3(2.8,0.20,p.distance_to(q)+0.13),WORLD.STEEL,true)
		deck.look_at(ring.to_global(q))
		for radius in [16.65,19.35]:
			# The western break gives access from the ramp.
			if radius>18 and i in [15,16]: continue
			var edge_a: Vector3 = p/18*radius+Vector3.UP*1.0
			var edge_b: Vector3 = q/18*radius+Vector3.UP*1.0
			KIT.rod(ring,edge_a,edge_b,0.045,WORLD.STEEL)
			var rail := WORLD.block(ring,(edge_a+edge_b)*0.5-Vector3.UP*0.45,Vector3(0.08,1,edge_a.distance_to(edge_b)+0.10),WORLD.FRAME,true)
			rail.look_at(ring.to_global(edge_b-Vector3.UP*0.45))
		if i%4==0:
			var foot: Vector3 = ring.to_global(p)
			foot.y = world.surface_profile.elevation(foot.x,foot.z)-0.4
			KIT.rod(ring,ring.to_local(foot),p,0.22,WORLD.STEEL)
			WORLD.ball(ring,p+Vector3.UP*0.20,Vector3(0.3,0.12,0.3),WORLD.CYAN)
	var start := WORLD.at(2,36,0,-26)
	var end := WORLD.at(2,58.4,6.6,-26)
	var ramp := WORLD.block(world,(start+end)*0.5-Vector3.UP*0.11,Vector3(start.distance_to(end),0.22,3.5),WORLD.STEEL,true)
	ramp.rotation.z = atan2(6.6,22.4)
	# A flush landing bridges the inclined ramp to the level ring deck.
	WORLD.block(world,WORLD.at(2,59.3,6.5,-26),Vector3(2.0,0.2,3.5),WORLD.STEEL,true)
	WORLD.placard(world,"COPERNIC · CRATÈRE D'IMPACT →",start+Vector3.UP*2.4,Color("b7def2"))
	# Large antenna silhouettes identify Copernic from the approach road.
	for x in [65,95]:
		KIT.rod(world,WORLD.at(2,x,0,0),WORLD.at(2,x,13,0),0.22,WORLD.STEEL)
		WORLD.ball(world,WORLD.at(2,x,13,0),Vector3(7,0.7,7),WORLD.WHITE)
		KIT.rod(world,WORLD.at(2,x,13,0),WORLD.at(2,x,16,0),0.075,WORLD.CYAN)

static func wreck_site(world: Node3D) -> void:
	var site := Node3D.new()
	site.name = "EpaveCourrier"
	world.add_child(site)
	site.position = ROUTES.wreck_point()
	WORLD.block(site,Vector3(0,-0.18,0),Vector3(11,0.36,9),WORLD.FRAME,true)
	# Open broken hull: enter at either end and walk between the cargo racks.
	for x in [-3.4,3.4]:
		WORLD.block(site,Vector3(x,1.3,0),Vector3(0.25,2.6,7),WORLD.STEEL,true).rotation.z = -signf(x)*0.12
		for z in [-2.4,2.4]:
			KIT.bevel(site,Vector3(x*0.75,0.55,z),Vector3(1.0,1.1,1.0),0.12,WORLD.FRAME,true)
	WORLD.block(site,Vector3(0,2.8,1.3),Vector3(6.8,0.2,3),WORLD.WHITE,true).rotation.x = -0.15
	WORLD.placard(site,"COURRIER 04 · BALISE DE DÉTRESSE",Vector3(0,3.2,2.4),Color("ffcd9b")).billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	for i in range(1,5):
		var p := ROUTES.wreck_turnoff().lerp(ROUTES.wreck_point(),i/4.0)
		WORLD.cylinder(world,p+Vector3(0,0.45,3.6),0.10,0.16,0.9,WORLD.AMBER)
