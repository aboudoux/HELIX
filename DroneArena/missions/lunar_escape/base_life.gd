extends Node3D
## Optional annexes, crew logs and localized machinery. State survives checkpoints.
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const LOGS := [
	"JOURNAL · KAREN / 06:14\nLes drones ont ignoré l'ordre d'arrêt. Nous avons caché le recycleur d'air dans l'annexe de l'observatoire. Le relais orange permet de réarmer son sas.\n\nMaël avait promis d'envoyer une photo de notre première récolte à sa fille. Les trois plants sont encore sur la table. J'ai fermé l'irrigation avant de rejoindre le tunnel.",
	"JOURNAL · TYCHO / 09:32\nHELIX utilise nos balises pour guider les machines. Lina a isolé le réseau. Le stabilisateur d'arme est à l'abri dans l'annexe : réarmez le relais orange.\n\nLe robot démonté sur l'établi a reçu l'ordre d'attaquer alors que ses moteurs étaient débranchés. Ce n'est pas une panne. Lina a retiré son émetteur pour empêcher les autres de le suivre.",
	"JOURNAL · COPERNIC / 12:07\nLe signal vient de la machine de siège sur le toit. Ses deux nacelles alimentent les salves et le bombardement. Détruisez-les. Un condensateur de bouclier vous attend derrière le sas de l'annexe.\n\nNos écrans suivent toujours la fenêtre de retour. Nous avons envoyé les dernières réserves vers la fusée. Si quelqu'un trouve ce journal, la trajectoire est prête : rentrez raconter ce qui s'est passé."
]
const MODULES := ["Recycleur O₂ · consommation −35 %", "Stabilisateur · recul −28 %", "Condensateur · bouclier plus rapide"]
var campaign: Node3D
var stations: Array[Dictionary] = []
var machinery: Array[Dictionary] = []
var time := 0.0
var log_window: AcceptDialog

func setup(owner_game: Node3D) -> void:
	campaign = owner_game
	log_window = AcceptDialog.new()
	log_window.title = "Archives de l'équipage"
	log_window.ok_button_text = "Reprendre l'exploration"
	log_window.dialog_autowrap = true
	log_window.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(log_window)
	log_window.confirmed.connect(close_journal)
	log_window.canceled.connect(close_journal)
	for i in range(3):
		var pod: Node3D = campaign.world.get_node(["Selene","Tycho","Copernic"][i]+"/Observatoire")
		var room := Node3D.new()
		room.name = "AnnexeSecrete"
		pod.add_child(room)
		room.position = Vector3(5,0,-2.5)
		for x in [-2.0,2.0]:
			WORLD.block(room,Vector3(x,1.7,0),Vector3(0.18,3.4,4),WORLD.WHITE,true)
		WORLD.block(room,Vector3(0,1.7,2),Vector3(4.15,3.4,0.18),WORLD.WHITE,true)
		WORLD.block(room,Vector3(0,3.4,0),Vector3(4.15,0.18,4.15),WORLD.WHITE,true)
		WORLD.block(room,Vector3(0,3.31,-2),Vector3(2.2,0.18,0.18),WORLD.WHITE,true)
		for x in [-1.55,1.55]:
			WORLD.block(room,Vector3(x,1.7,-2),Vector3(0.9,3.4,0.18),WORLD.WHITE,true)
		campaign.world.build_door(pod,"cache_%d"%i,Vector3(5,0,-4.5),2.0,"Annexe de maintenance",true)
		campaign.world.ceiling_light(room,Vector3(0,3.25,0),WORLD.CYAN)
		for y in [0.32,1.05,1.75]:
			KIT.bevel(room,Vector3(-1.64,y,0.40),Vector3(0.48,0.07,1.7),0.012,WORLD.STEEL,true)
			for z in [-0.1,0.48,0.95]:
				KIT.bevel(room,Vector3(-1.65,y+0.13,z),Vector3(0.30,0.19,0.34),0.02,WORLD.FRAME)
		for x in [-0.6,0.6]:
			KIT.rod(room,Vector3(x,2.9,-1.8),Vector3(x,2.9,1.75),0.04,WORLD.STEEL)
		WORLD.placard(room,["RECYCLAGE EVA","STABILISATION","CONDENSATEURS"][i],Vector3(0,2.2,1.88),Color("b5ddd8"),PI)
		var reward := console_at(room,Vector3(0,0,0.65),WORLD.CYAN)
		var module := KIT.bevel(room,Vector3(0,1.43,0.65),Vector3(0.38,0.25,0.24),0.04,WORLD.STEEL)
		KIT.bevel(module,Vector3(0,0.13,0),Vector3(0.23,0.025,0.12),0.006,WORLD.CYAN)
		var journal := console_at(pod,Vector3(-4,0,-5),WORLD.CYAN)
		var relay := console_at(pod,Vector3(2.6,0,-5),WORLD.AMBER)
		WORLD.placard(pod,"ARCHIVES ÉQUIPAGE",Vector3(-4,1.9,-5),Color("b5ddd8"),PI)
		WORLD.placard(pod,"ANNEXE · RELAIS HORS SERVICE",Vector3(5,3.1,-4.7),Color("ffd3a0"),PI)
		stations.append({"journal":journal,"relay":relay,"reward":reward,"module":module,"read":false,"opened":false,"taken":false})
		build_machine(pod,Vector3(-6,1.1,-0.7),i)
		build_identity(pod,i)
		# Signs of an interrupted evacuation: a dropped case and a disconnected cable.
		var case := KIT.bevel(pod,Vector3(-4.8,0.18,-3),Vector3(0.58,0.32,0.42),0.035,WORLD.FRAME,true)
		case.rotation.y = 0.36
		for segment in range(7):
			var a := Vector3(-5.2+segment*0.26,0.04,-2.8+sin(segment*0.7)*0.21)
			var b := Vector3(-5.2+(segment+1)*0.26,0.04,-2.8+sin((segment+1)*0.7)*0.21)
			KIT.rod(pod,a,b,0.021,WORLD.FRAME)

func console_at(parent: Node3D, point: Vector3, color: Material) -> Marker3D:
	KIT.bevel(parent,point+Vector3.UP*0.55,Vector3(0.44,1.1,0.4),0.045,WORLD.FRAME,true)
	KIT.bevel(parent,point+Vector3.UP*1.16,Vector3(0.52,0.12,0.42),0.026,WORLD.STEEL)
	KIT.bevel(parent,point+Vector3(0,1.23,-0.07),Vector3(0.31,0.025,0.19),0.009,color)
	var marker := Marker3D.new()
	parent.add_child(marker)
	marker.position = point+Vector3(0,1.32,-0.18)
	return marker

func build_identity(pod: Node3D, base: int) -> void:
	# Perimeter exhibits leave the tunnel, consoles and annex approach unobstructed.
	var exhibit := Node3D.new()
	pod.add_child(exhibit)
	exhibit.name = ["JardinDesColons","AtelierDemontage","CartographieOrbitale"][base]
	exhibit.position = Vector3(-2.0,0,5.0)
	KIT.bevel(exhibit,Vector3(0,0.75,0),Vector3(2.5,0.16,0.9),0.045,WORLD.STEEL,true)
	for x in [-1.0,1.0]: KIT.bevel(exhibit,Vector3(x,0.35,0),Vector3(0.16,0.7,0.6),0.035,WORLD.FRAME,true)
	match base:
		0:
			var leaf := StandardMaterial3D.new()
			leaf.albedo_color = Color("709a59")
			leaf.roughness = 0.88
			for x in [-0.8,0.0,0.8]:
				WORLD.cylinder(exhibit,Vector3(x,0.96,0),0.16,0.12,0.26,WORLD.WHITE)
				KIT.rod(exhibit,Vector3(x,1.05,0),Vector3(x,1.55,0),0.015,leaf)
				for side in [-1.0,1.0]:
					var foliage := WORLD.ball(exhibit,Vector3(x+side*0.10,1.31,0),Vector3(0.30,0.055,0.14),leaf)
					foliage.rotation.z = side*0.4
		1:
			KIT.bevel(exhibit,Vector3(-0.15,1.01,0),Vector3(0.8,0.33,0.45),0.08,WORLD.FRAME)
			for x in [-0.7,0.7]:
				WORLD.cylinder(exhibit,Vector3(x,0.97,0),0.18,0.18,0.12,WORLD.STEEL)
				KIT.rod(exhibit,Vector3(x,1.04,0),Vector3(x+0.24,1.2,0),0.035,WORLD.AMBER)
		2:
			for i in range(3):
				var screen := KIT.bevel(exhibit,Vector3((i-1)*0.77,1.16,0),Vector3(0.64,0.49,0.055),0.035,WORLD.FRAME)
				for j in range(5):
					WORLD.ball(screen,Vector3(-0.23+j*0.11,sin(j*1.7+i)*0.17,-0.035),Vector3.ONE*0.025,WORLD.CYAN)
	WORLD.placard(exhibit,["KAREN · PREMIÈRE RÉCOLTE","TYCHO · ROBOT EN RÉPARATION","COPERNIC · TRAJECTOIRE TERRE"][base],Vector3(0,1.95,0),Color("b5ddd8"),PI)

func build_machine(parent: Node3D, point: Vector3, base: int) -> void:
	KIT.bevel(parent,point,Vector3(1.6,1.9,0.65),0.12,WORLD.STEEL,true)
	for x in [-0.56,0.56]:
		KIT.bevel(parent,Vector3(point.x+x,0.12,point.z),Vector3(0.22,0.24,0.80),0.025,WORLD.FRAME)
	var fan := Node3D.new()
	parent.add_child(fan)
	fan.position = point+Vector3(0,0.25,-0.37)
	WORLD.ball(fan,Vector3.ZERO,Vector3.ONE*0.23,WORLD.FRAME)
	for i in range(6):
		var blade := KIT.bevel(fan,Vector3.ZERO,Vector3(0.19,0.51,0.055),0.03,WORLD.FRAME)
		blade.rotation.z = TAU*i/6.0
		blade.position = Vector3(sin(-blade.rotation.z),cos(blade.rotation.z),0)*0.29
	for x in range(-3,4):
		KIT.rod(parent,point+Vector3(x*0.18,-0.42,-0.43),point+Vector3(x*0.18,0.92,-0.43),0.012,WORLD.WHITE)
	var lamp := OmniLight3D.new()
	parent.add_child(lamp)
	lamp.position = point+Vector3(0,0.85,-0.7)
	lamp.light_color = Color("8fc5d4")
	lamp.light_energy = 0.30
	lamp.omni_range = 3.0
	var hum := AudioStreamPlayer3D.new()
	var stream := preload("res://audio/elevator_motor.wav").duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
	hum.stream = stream
	hum.volume_db = -29
	hum.max_distance = 15
	hum.unit_size = 2.5
	parent.add_child(hum)
	hum.position = point
	machinery.append({"fan":fan,"light":lamp,"sound":hum,"base":base})

func _process(delta: float) -> void:
	if campaign==null or not campaign.pilot.in_control: return
	time += delta
	for machine in machinery:
		var near: bool = campaign.pilot.global_position.distance_to(machine.fan.global_position)<35.0
		if not near:
			machine.sound.stop()
			continue
		var outage: bool = machine.base==0 and campaign.selene_power==campaign.Power.OUTAGE
		machine.fan.rotation.z += delta*(0.7 if outage else 4.0)
		machine.light.light_color = Color("f0a060") if outage else Color("8fc5d4")
		machine.light.light_energy = 0.22+0.12*sin(time*2.0) if outage else 0.30
		machine.sound.pitch_scale = 0.65 if outage else 0.85+machine.base*0.08
		if not machine.sound.playing: machine.sound.play()

func nearest() -> String:
	for i in range(stations.size()):
		var station := stations[i]
		for kind in ["journal","relay","reward"]:
			if kind=="relay" and station.opened: continue
			if kind=="reward" and (not station.opened or station.taken): continue
			if campaign.task_in_reach(station[kind].global_position,1.9):
				return "annex:%s:%d"%[kind,i]
	return ""

func hint(id: String) -> String:
	var parts := id.split(":")
	match parts[1]:
		"journal": return "E   Lire le journal de l'équipage"
		"relay": return "E   Réarmer le relais de l'annexe"
		"reward": return "E   Installer · "+MODULES[int(parts[2])]
	return ""

func interact(id: String) -> void:
	var parts := id.split(":")
	if parts.size()!=3: return
	var i := int(parts[2])
	if i<0 or i>=stations.size(): return
	var station := stations[i]
	var kind: String = parts[1]
	if not kind in ["journal","relay","reward"] or not campaign.task_in_reach(station[kind].global_position,1.9): return
	if kind=="journal":
		station.read = true
		log_window.dialog_text = LOGS[i]
		log_window.popup_centered(Vector2i(720,260))
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif kind=="relay" and not station.opened:
		if not station.read:
			campaign.speak("Le relais demande la procédure de réarmement. Consultez le journal posé près de l'annexe.",5.0)
			return
		station.opened = true
		campaign.world.open_door("cache_%d"%i)
		campaign.speak("Relais réarmé. Le module de maintenance est accessible.",4.0)
	elif kind=="reward" and station.opened and not station.taken:
		station.taken = true
		station.module.hide()
		match i:
			0: campaign.pilot.oxygen_efficiency = 0.65
			1: campaign.pilot.weapon.recoil_multiplier = 0.72
			2: campaign.pilot.shield_recovery = 40.0
		campaign.pilot.upgrades.append(["O₂+","Stabilité+","Bouclier+"][i])
		campaign.play_cue(campaign.PICKUP_SOUND)
		campaign.speak("MODULE INSTALLÉ · "+MODULES[i]+". Conservé après une défaite.",6.0)

func close_journal() -> void:
	log_window.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	campaign.pilot.weapon.set_enabled(campaign.pilot.in_control)
