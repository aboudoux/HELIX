extends Node3D
## Authored combat cover and inhabited rooms; shared photographic materials remain intact.
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const ROUTES := preload("res://missions/lunar_escape/lunar_routes.gd")
var game: Node3D
var hit_label: Label
var hit_left := 0.0
var discoveries: Array[Dictionary] = []

func setup(campaign: Node3D) -> void:
	game = campaign
	name = "CampaignPolish"
	for index in range(3): decorate_base(index)
	dress_karen_corridor()
	for leg in range(2): build_supply_stop(leg)
	hit_label = game.hud.label(game.hud.content,"",15,Color("ffcb7d"))
	game.hud.pin(hit_label,Control.PRESET_CENTER,Vector2(-120,27),Vector2(240,27))
	hit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.pilot.weapon.fired.connect(on_shot)

func cover(parent: Node3D, at: Vector3, label_text: String, accent: Material) -> void:
	var crate := KIT.bevel(parent,at+Vector3.UP*.58,Vector3(2.2,1.16,.9),.12,WORLD.FRAME,true)
	crate.name = "CouvertureTactique"
	for side in [-1.0,1.0]:
		KIT.bevel(crate,Vector3(0,0,side*.46),Vector3(1.91,.86,.07),.05,WORLD.WHITE)
		KIT.bevel(crate,Vector3(0,.34,side*.51),Vector3(1.65,.04,.025),.008,accent)
		for x in [-.8,.8]: KIT.rod(crate,Vector3(x,-.32,side*.51),Vector3(x,.3,side*.51),.025,WORLD.STEEL)
	WORLD.placard(crate,label_text,Vector3(0,.05,.515),Color("d4d7d7")).pixel_size = .0017

func decorate_base(index: int) -> void:
	var base: Node3D = game.world.get_node(["Selene","Tycho","Copernic"][index])
	var accent: Material = [WORLD.CYAN,WORLD.AMBER,WORLD.RED][index]
	# Keep a >4 m clear central route and every existing door reachable.
	cover(base,Vector3(-6,0,12),["KAREN · EAU / VIVRES","TYCHO · OUTILLAGE","COPERNIC · MUNITIONS"][index],accent)
	cover(base,Vector3(5,0,10),"HELIX · MATÉRIEL",accent)
	var room: Node3D = base.get_node("Chambre1")
	var details := Node3D.new(); details.name = "IdentiteBase"; room.add_child(details)
	game.world.furnishings.table(details,Vector3(3,0,2.2),Vector2(2.3,.95),.84)
	if index==0:
		# Ceramic cup with open rim, handle and dark liquid; personal objects at eye level.
		for x in [2.5,3.5]:
			WORLD.cylinder(details,Vector3(x,.99,2.2),.075,.063,.22,WORLD.WHITE)
			WORLD.cylinder(details,Vector3(x,1.104,2.2),.060,.060,.004,WORLD.FRAME)
			var torus := TorusMesh.new(); torus.inner_radius=.04; torus.outer_radius=.065
			var handle := WORLD.mesh_node(details,Vector3(x+.09,1.0,2.2),torus,WORLD.WHITE)
			handle.rotation.x = PI/2
		WORLD.cylinder(details,Vector3(3.75,1.00,2.3),.17,.12,.22,WORLD.WHITE)
		WORLD.cylinder(details,Vector3(3.75,1.112,2.3),.15,.15,.012,WORLD.FRAME)
		game.world.furnishings.plant(details,Vector3(3.75,1.12,2.3))
		for i in range(3): KIT.bevel(details,Vector3(2.9,.91+i*.035,2.1),Vector3(.34,.03,.48),.012,WORLD.WHITE if i%2==0 else WORLD.FRAME)
		WORLD.placard(details,"KAREN · QUARTIERS DE VIE\nMAËL — RETOUR PRÉVU À 06:30",Vector3(0,2.55,-5.4),Color("e2d6b7")).pixel_size = .003
	elif index==1:
		for i in range(4):
			var x := 2.2+i*.48
			KIT.rod(details,Vector3(x,.91,2.0),Vector3(x+.25,.91,2.35),.026,WORLD.STEEL)
			KIT.bevel(details,Vector3(x+.27,.91,2.38),Vector3(.14,.065,.14),.022,WORLD.FRAME)
		game.world.furnishings.gear_shelf(details,Vector3(7,0,2))
		WORLD.placard(details,"TYCHO · MAINTENANCE\nCIRCUIT HYDRAULIQUE / CONSIGNÉ",Vector3(0,2.55,-5.4),Color("efc27c")).pixel_size = .003
	else:
		for x in [2.5,3.5]:
			var case := Node3D.new(); details.add_child(case); case.position=Vector3(x,1.25,2.2)
			game.world.furnishings.ammunition_case(case,true)
		WORLD.placard(details,"COPERNIC · DÉFENSE ORBITALE\nÉVACUATION — POSTE ABANDONNÉ",Vector3(0,2.55,-5.4),Color("f1a5a0")).pixel_size = .003
	preload("res://missions/lunar_escape/room_services.gd").dress(details,index)


func dress_karen_corridor() -> void:
	var corridor := Node3D.new()
	corridor.name = "PosteEvacuationKaren"
	game.world.get_node("Selene").add_child(corridor)
	# An overturned stool and a console sit against the dormitory wall.
	game.world.furnishings.table(corridor, Vector3(-3.52,0,9.48), Vector2(.74,1.0), .95)
	game.world.furnishings.screen(corridor, Vector3(-3.52,1.46,9.45), .74,
		"ÉVACUATION · 06:14\nJOURNAL → CH. 01\nREPLI · INFIRMERIE", 1.005)
	var stool := Node3D.new()
	corridor.add_child(stool)
	stool.position = Vector3(-3.51,.239,11.52)
	stool.rotation.x = PI*.5
	KIT.bevel(stool, Vector3(0,.37,0), Vector3(.43,.09,.44), .035, WORLD.FRAME)
	for x in [-.15,.15]:
		for z in [-.14,.14]:
			KIT.rod(stool, Vector3(x,.05,z), Vector3(x,.35,z), .026, WORLD.STEEL)
	# A buckled service hatch stays attached to the wall by its upper edge.
	KIT.bevel(corridor, Vector3(-3.89,1.46,10.88), Vector3(.12,.78,.63), .035, WORLD.FRAME)
	var hatch := KIT.bevel(corridor, Vector3(-3.79,1.50,10.88), Vector3(.08,.72,.56), .03, WORLD.STEEL)
	hatch.rotation.z = -.19
	for index in 5:
		KIT.bevel(hatch, Vector3(.044,.23-index*.085,0), Vector3(.009,.023,.36), .004, WORLD.FRAME)
	var scuff := StandardMaterial3D.new()
	scuff.albedo_color = Color("5f615f")
	scuff.roughness = .97
	for index in 11:
		var x := -2.35-index*.09
		var z := 13.25-index*.17
		var mark := WORLD.block(corridor, Vector3(x,.030,z), Vector3(.13+index%3*.04,.002,.025), scuff)
		mark.rotation.y = .32+index*.16

func build_supply_stop(leg: int) -> void:
	var point := ROUTES.air_stop(leg,1)+Vector3(2.5,0,1.5)
	point.y = game.world.surface_profile.elevation(point.x,point.z)
	var stop := Node3D.new(); stop.name="ConvoiAbandonne%d"%leg
	game.world.add_child(stop); stop.position=point
	# A small broken cargo sled beside the existing oxygen stop; never across the road.
	for x in [-1.0,1.0]: KIT.rod(stop,Vector3(x,.28,-1.6),Vector3(x,.28,1.5),.10,WORLD.STEEL)
	KIT.bevel(stop,Vector3(0,.5,0),Vector3(2.2,.2,3.1),.08,WORLD.FRAME,true)
	cover(stop,Vector3(0,.6,0),"SECOURS · CAISSE DE SURVIE",WORLD.AMBER)
	WORLD.placard(stop,"CONVOI ABANDONNÉ\nRÉSERVES DE SECOURS",Vector3(0,2.25,0),Color("ffd49a")).billboard=BaseMaterial3D.BILLBOARD_ENABLED
	discoveries.append({"node":stop,"claimed":false,"leg":leg})

func on_shot(_point: Vector3, accepted: bool) -> void:
	if not accepted: return
	var target: Object = game.pilot.weapon.last_hit.get("collider")
	if not is_instance_valid(target): return
	hit_label.text = "POINT FAIBLE ×%d"%int(target.get_meta("weak_multiplier",2)) if target.get_meta("last_weak_hit",false) else ("NEUTRALISÉ" if target.get("health")==0 else "TOUCHÉ")
	if target.get_meta("last_armor_hit",false): hit_label.text = "BLINDAGE · VISEZ L'ORANGE"
	hit_left = .42

func claim(entry: Dictionary) -> void:
	if entry.claimed: return
	entry.claimed=true
	game.pilot.add_ammo("pistol",24)
	if game.pilot.inventory.has("shotgun"): game.pilot.add_ammo("shotgun",6)
	game.pilot.health=mini(game.pilot.max_health,game.pilot.health+25)
	game.pilot.health_changed.emit(game.pilot.health,game.pilot.max_health)
	game.speak("CONVOI · Réserves récupérées : munitions et soins. La balise confirme la route vers "+("Tycho." if entry.leg==0 else "Copernic."),5)

func _physics_process(delta: float) -> void:
	hit_left=maxf(0,hit_left-delta)
	hit_label.visible=hit_left>0 and game.pilot.in_control and not game.hud.title_card.visible
	if not game.pilot.in_control or game.pilot.vehicle!=null: return
	for entry in discoveries:
		if entry.claimed or game.pilot.global_position.distance_to(entry.node.global_position)>3.0: continue
		if game.task_in_reach(entry.node.global_position+Vector3.UP,3.0):
			hit_label.text="G · Ouvrir la caisse de secours"; hit_label.visible=true
			if Input.is_physical_key_pressed(KEY_G) and game.squad.commands.rescue==null: claim(entry)
