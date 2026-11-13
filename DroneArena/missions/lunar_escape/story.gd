extends Node3D
## Campaign objectives, contextual radio, and the cooperative launch sequence.
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const ROUTES := preload("res://missions/lunar_escape/lunar_routes.gd")
const TEXT := {
	"crew":"KAREN · CHAMBRE DE MAËL\n06:14. Les portes se sont fermées pendant le petit déjeuner. Noor a conduit les familles vers l'infirmerie. Les drones répondaient à une fréquence absente de notre réseau.\n\nRetrouvez le registre médical dans les quartiers nord.",
	"medical":"KAREN · REGISTRE MÉDICAL\n06:21. Équipage évacué vers les abris. Aucun ordre local ne permet d'arrêter les machines. Le dernier signal reçu vient de l'orbite.\n\nLina répond encore depuis Tycho. Rétablissez le courant de Karen et rejoignez-la.",
	"coordinates":"COPERNIC · ANALYSE DU SIGNAL\nLa commande des robots provient du quadrupède extraterrestre qui garde le toit. HELIX relayait ses ordres sans contrôle humain.\n\nTrajectoire de retour copiée. Quatre places disponibles. Il reste à alimenter le circuit de lancement au poste de contrôle.",
	"wreck":"COURRIER 04 · BOÎTE NOIRE\nNous transportions les échantillons de Karen. Une impulsion venue du ciel a coupé le pilotage. L'équipage a rejoint le poste de secours à pied.\n\nQuelques cartouches et une bouteille d'oxygène sont encore utilisables.",
	"aid":"POSTE DE SECOURS · DERNIER DÉPART\nLes rescapés ont quitté cet abri pour le bunker de Tycho. Lina nous a envoyé un blindé avant que son atelier ne se verrouille.\n\nLes réserves médicales restantes sont à vous.",
	"survivors":"SURVIVANTS DE KAREN · MAËL ET NOOR\nVous nous avez retrouvés ! Nous avons conduit les familles dans les abris souterrains. Lina nous a apporté des réserves avant de rester coincée dans son atelier.\n\nNotre balise est réparée. Les familles restent dans les abris. Nous partons avec vous et Lina pour rapporter le journal sur Terre. Nous sommes armés, mais vous devez nous protéger : si l’un de nous meurt, la mission échoue."
}
var game: Node3D
var flags := {"crew":false,"medical":false,"power":false,"coordinates":false,"fuel":false,"wreck":false,"aid":false,"survivors":false,"access":false}
var stations: Dictionary = {}
var companion: Node3D
var link: StaticBody3D
var preparation := 0.0
var boss_defeated := false
var last_step := -1
var arrival_ship: Node3D
var arrival_flame: Node3D

func setup(campaign: Node3D) -> void:
	game = campaign
	preload("res://missions/lunar_escape/story_map.gd").build(game.world)
	terminal("crew",game.world.get_node("Selene/Chambre1"),Vector3(-7.5,0,1.2),"JOURNAL DE BORD · KAREN",0)
	terminal("medical",game.world.get_node("Selene/Chambre3"),Vector3(-7.5,0,1.2),"REGISTRE · SURVIVANTS",0)
	terminal("power",game.world.get_node("Tycho"),Vector3(-10.4,0,-4.0),"ALIMENTATION · ATELIER LINA",1)
	terminal("survivors",game.world.get_node("Tycho/Chambre3"),Vector3(-7.5,0,1.2),"ABRI · SURVIVANTS DE KAREN",1)
	# A small maintenance tablet tucked beside the bed, rather than a marked console.
	var room: Node3D = game.world.get_node("Tycho/Chambre2")
	# The code tablet rests on a bedside cabinet, rather than floating in the room.
	game.world.furnishings.cabinet(room,Vector3(-7.3,0,-1.8),.72,.9275,.68)
	var tablet := Marker3D.new()
	tablet.name="TabletteCodeCopernic"
	room.add_child(tablet); tablet.position = Vector3(-7.3,0.95,-1.8)
	KIT.bevel(tablet,Vector3.ZERO,Vector3(0.32,0.045,0.44),0.018,WORLD.FRAME)
	KIT.bevel(tablet,Vector3(0,0.026,0),Vector3(0.27,0.012,0.35),0.006,WORLD.CYAN)
	stations["access"] = {"marker":tablet,"base":1,"title":"TABLETTE DE MAINTENANCE"}
	for i in range(2):
		game.squad.create_member("MAËL" if i==0 else "NOOR",game.world.get_node("Tycho/Chambre3"),Vector3(2.5+i*2.5,0,1.1),i)
	terminal("coordinates",game.world.get_node("Copernic/Etage01"),Vector3(-3,0,3.0),"TRAJECTOIRE · TERRE",2)
	terminal("fuel",game.world.get_node("Copernic/Controle"),Vector3(0,0,0.6),"ALIMENTATION · FUSÉE",2)
	terminal("wreck",game.world.get_node("EpaveCourrier"),Vector3(0,0,1.3),"BOÎTE NOIRE · COURRIER 04",-1)
	terminal("aid",game.world,ROUTES.service_point()+Vector3(1.5,0,-2.3),"SECOURS · RÉSERVES MÉDICALES",-1)
	companion = game.squad.create_member("LINA",game.world,game.mechanic.global_position,2)
	# The visible mechanic and the recruited companion are now the same physical actor.
	companion.avatar.hide(); companion.avatar.queue_free()
	game.mechanic.reparent(companion,true)
	companion.avatar = game.mechanic
	link = preload("res://missions/lunar_escape/launch_link.gd").new()
	game.world.add_child(link)
	link.position = WORLD.pad(-3,0,-226)
	arrival_ship = game.world.rocket.duplicate()
	arrival_ship.name = "FuseeArriveeKaren"
	game.world.add_child(arrival_ship)
	arrival_ship.scale = Vector3.ONE*0.65
	arrival_ship.position = Vector3(0,0,46)
	arrival_flame = arrival_ship.get_child(game.world.rocket_flame.get_index())
	WORLD.block(game.world,Vector3(0,-0.14,46),Vector3(15,0.3,13),WORLD.STEEL,true)

func terminal(id: String, parent: Node3D, point: Vector3, title: String, base: int) -> void:
	var marker: Marker3D = game.base_life.console_at(parent,point,WORLD.AMBER)
	var label := WORLD.placard(parent,title,point+Vector3(0,2.1,0),Color("ffddac"),PI)
	if base<0: label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	stations[id] = {"marker":marker,"base":base,"title":title}

func nearest() -> String:
	if game.pilot.vehicle!=null: return ""
	for id in stations:
		var station: Dictionary = stations[id]
		if station.base>=0 and station.base!=game.active_base() and not (id=="access" and game.step==game.Step.TRANSPORT): continue
		if flags[id]: continue
		if game.task_in_reach(station.marker.global_position,2.1): return "story:"+id
	if game.step in [game.Step.BATTLE,game.Step.BOARD] and link.health<100 and game.task_in_reach(link.global_position+Vector3(0,1.4,0.7),2.4): return "story:repair"
	return ""

func hint(id: String) -> String:
	match id:
		"access": return "E   Lire la tablette de maintenance"
		"survivors": return "E   Retrouver Maël et Noor · Former l'escouade"
		"power": return "E   Rétablir le courant de l'atelier"
		"coordinates": return "E   Analyser le signal et copier la trajectoire"
		"fuel": return "E   Alimenter la fusée"
		"repair": return "E   Réparer la liaison de lancement"
		"aid": return "E   Lire le registre et prendre les soins"
	return "E   Lire · "+str(stations.get(id,{}).get("title","Archives"))

func interact(id: String) -> void:
	if nearest()!="story:"+id: return
	if id=="repair":
		link.repair()
		game.speak("LINA · Liaison rétablie. Je reprends la préparation !",4)
		return
	if id=="fuel" and not flags.coordinates:
		game.speak("ORDINATEUR · Copiez d'abord la trajectoire dans le laboratoire à l'étage.",4)
		return
	flags[id] = true
	if id=="access":
		game.base_life.log_window.dialog_text = "MAINTENANCE TYCHO · LIAISON COPERNIC\n\nCode du sas de la troisième base : "+game.access_codes.copernic+"\n\nCode mémorisé. Il sera disponible sur le clavier de Copernic."
		game.base_life.log_window.popup_centered(Vector2i(740,310))
		get_tree().paused = true; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if TEXT.has(id):
		game.base_life.log_window.dialog_text = TEXT[id]
		game.base_life.log_window.popup_centered(Vector2i(740,310))
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	match id:
		"survivors":
			game.squad.recruit(0)
			game.squad.recruit(1)
		"crew": game.speak(game.VOICE.LINES.log,7)
		"medical": game.speak(game.VOICE.LINES.survivors,8)
		"power":
			refresh_workshop_door()
			game.speak("LINA · Le courant revient ! Neutralisez l'éclaireur et ouvrez le sas de l'atelier, par les quartiers ouest.",6)
		"fuel": game.speak("LINA · Les pompes tournent. Restons groupés. Prenez votre armure, puis allons protéger le départ !",6)
		"wreck":
			game.pilot.add_ammo("pistol",24)
			game.pilot.oxygen = minf(100,game.pilot.oxygen+40)
		"aid":
			game.pilot.restore_health()
			game.pilot.oxygen = 100
			game.pilot.add_ammo("shotgun",12)
	for base in range(3): game.update_clearance(base)
	if game.active_base()>=0: game.refresh_base_objective(game.active_base())
	place_companion()

func exit_ready(base: int) -> bool:
	match base:
		0: return flags.crew and flags.medical
		1: return flags.power and game.mechanic_rescued and flags.survivors and flags.access
		2: return flags.coordinates and flags.fuel
	return true

func objective(base: int) -> String:
	match base:
		0:
			if not flags.crew: return "Mission Karen : récupérez le journal de bord dans les quartiers sud-ouest."
			if not flags.medical: return "Retrouvez les survivants : consultez le registre de l'infirmerie au nord-ouest."
		1:
			if not flags.power: return "Rétablissez le courant de l'atelier depuis le boîtier au rez-de-chaussée."
			if not game.mechanic_rescued: return "Neutralisez l'éclaireur, puis secourez Lina dans l'atelier au bout du tunnel ouest."
			if not flags.survivors: return "Retrouvez Maël et Noor dans l'abri des quartiers nord-ouest de Tycho."
			if not flags.access: return "Fouillez la deuxième chambre de Tycho : une tablette cache le code de Copernic."
		2:
			if not flags.coordinates: return "Montez au laboratoire : identifiez le signal et copiez la trajectoire vers la Terre."
			if not flags.fuel: return "Alimentez la fusée depuis le poste de contrôle au nord-est."
	return ""

func marker(base: int) -> Array:
	if base==0:
		return room_marker(0,0,"crew") if not flags.crew else room_marker(0,2,"medical")
	if base==1:
		if flags.survivors and not flags.access: return [game.world.doors.room_1_0_1.global_position+Vector3.UP*2,"Fouiller la deuxième chambre"]
		if not flags.power: return [stations.power.marker.global_position,"Alimentation atelier"]
		if game.mechanic_rescued: return room_marker(1,2,"survivors")
		if game.pilot.position.x>-14: return game.door_marker("room_1_0_0")
		if game.pilot.position.z<WORLD.BASE_Z[1]+19: return game.door_marker("dome_1_-1")
		return [game.mechanic.global_position+Vector3.UP*1.3,"Lina"]
	if base==2 and not flags.coordinates:
		if not game.on_upper_floor:
			if game.pilot.position.x>34.9: return game.door_marker("stair_up_2")
			return game.door_marker("room_2_1_1" if game.pilot.position.x<14 else "stair_down_2")
		if not game.world.doors.upper_2.is_open: return game.door_marker("upper_2")
		return [stations.coordinates.marker.global_position,"Trajectoire Terre"]
	if game.on_upper_floor: return game.door_marker("stair_up_2")
	if game.pilot.position.x>34.9: return game.door_marker("stair_down_2")
	if not game.world.doors.north_2.is_open and game.pilot.position.z>WORLD.BASE_Z[2]-8: return game.door_marker("north_2")
	if game.pilot.position.x<14: return game.door_marker("room_2_1_2")
	return [stations.fuel.marker.global_position,"Alimentation fusée"]

func room_marker(base: int, slot: int, id: String) -> Array:
	var point: Vector3 = game.pilot.position-WORLD.at(base,0,0,0)
	var room: Node3D = game.world.get_node(["Selene","Tycho","Copernic"][base]+"/Chambre%d"%(slot+1))
	if point.x<-35: return game.door_marker("west_room_%d_%d"%[base,slot])
	if point.x<-14 and absf(point.z-room.position.z)>5.8:
		var current := 0 if point.z>WORLD.ROOM_DIVIDERS[base][2] else (2 if point.z<WORLD.ROOM_DIVIDERS[base][1] else 1)
		return game.door_marker("room_%d_0_%d"%[base,current])
	if point.x>=-14:
		var north: Node3D = game.world.doors["north_%d"%base]
		if slot==2 and game.pilot.position.z>north.global_position.z and not north.is_open: return game.door_marker("north_%d"%base)
		return game.door_marker("room_%d_0_%d"%[base,slot])
	return [stations[id].marker.global_position,stations[id].title]

func refresh_workshop_door() -> void:
	if flags.power and not game.rescue_guard.alive: game.world.doors["dome_1_-1"].unlock()

func rescue() -> void:
	if not flags.power or game.rescue_guard.alive: return
	game.mechanic_rescued = true
	place_companion()
	game.update_clearance(1)
	game.refresh_base_objective(1)
	game.speak(game.VOICE.LINES.together,8)

func place_companion() -> void:
	game.squad.restore_members()

func begin_defense() -> void:
	preparation = 0
	boss_defeated = false
	link.repair()
	game.mothership.launch_target = link
	game.speak("LINA · Je prépare les quatre sièges. Protégez la liaison au pied de l'antenne ; si elle tombe, réparez-la avec E !",7)

func _physics_process(delta: float) -> void:
	if game==null or not game.pilot.in_control: return
	if game.step!=last_step:
		last_step = game.step
		place_companion()
	if game.step not in [game.Step.BATTLE,game.Step.BOARD]: return
	if link.health>0: preparation = minf(35,preparation+delta)
	if preparation>=35 and boss_defeated:
		game.world.set_pad_lock(false)
		game.set_objective("DÉPART POUR LA TERRE","Embarquez avec toute l’équipe. Quatre sièges vous attendent.")
	else:
		game.set_objective("PROTÉGER LE DÉPART","Lina prépare la fusée · %d %% · %s"%[roundi(preparation/35*100),"E : réparer la liaison" if link.health==0 else "Liaison %d %%"%link.health])

func ready_to_launch() -> bool:
	return boss_defeated and preparation>=35

func snapshot() -> Dictionary:
	return {"flags":flags.duplicate(),"preparation":preparation,"boss_defeated":boss_defeated}

func restore(data: Dictionary, stage: int) -> void:
	if data.is_empty():
		# Old saves keep their reached chapter, without inventing a new blocker behind them.
		flags.crew = stage>=game.Step.BIKE
		flags.medical = flags.crew
		flags.power = stage>=game.Step.TRANSPORT or game.mechanic_rescued
		flags.survivors = stage>=game.Step.TRANSPORT
		if stage>=game.Step.TRANSPORT: game.mechanic_rescued = true
		flags.coordinates = stage>=game.Step.BATTLE
		flags.fuel = flags.coordinates
	else:
		for key in flags: flags[key] = bool(data.get("flags",{}).get(key,false))
		if not data.get("flags",{}).has("survivors"):
			flags.survivors = stage>=game.Step.TRANSPORT
	preparation = clampf(float(data.get("preparation",35 if stage==game.Step.BOARD else 0)),0,35)
	boss_defeated = stage==game.Step.BOARD
	if not data.get("flags",{}).has("access") and stage>=game.Step.TRANSPORT: flags.access = true
	if boss_defeated: preparation = 35
	refresh_workshop_door()
	place_companion()
