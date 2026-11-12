extends "res://scripts/main.gd"
## Une mission séquentielle, sans modifier les commandes ou les tirs du prototype.

@export var boss_trial: bool = false
@export var alpha_trial: bool = false
var layout: Dictionary = {}
var stage: int = 0
var elapsed: float = 0.0
var extraction_progress: float = 0.0
var mission_complete: bool = false
var toast_remaining: float = 0.0
var can_interact: bool = false
@onready var director: Node3D = $Drones
@onready var gates: Array = $Arena/Gates.get_children()
@onready var relays: Array = $Arena/Relays.get_children()
@onready var hud: Control = $Interface/MissionHUD
@onready var boss: CharacterBody3D = $BossEncounter/Cerbere
@onready var alpha: CharacterBody3D = $AlphaEncounter/Fenrir
@onready var lift: Node3D = $Elevator
@onready var upper_director: Node3D = $UpperDrones
@onready var upper_gates: Array = $UpperArena/Gates.get_children()
@onready var upper_relays: Array = $UpperArena/Relays.get_children()
var upper_layout: Dictionary = {}


func _ready() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://missions/relay_run/layout.json"))
	upper_layout = JSON.parse_string(FileAccess.get_file_as_string("res://missions/relay_run/upper_layout.json"))
	# La cabine traverse l'ancien plafond : ce volume devient une vraie cage haute.
	$Arena/Plafonds/Extraction.hide()
	for gate in upper_gates:
		gate.opened.connect(func(): upper_director.navigation_ready = false)
	lift.arrived.connect(_on_lift_arrived)
	alpha.destroyed.connect(_on_alpha_destroyed)
	alpha.phase_changed.connect(func(_phase: int): toast("FENRIR entre en rage ! Ses rafales deviennent plus longues."))
	for guard in upper_director.get_children():
		guard.destroyed.connect(_on_drone_destroyed)
	for gate in gates:
		gate.opened.connect(func(): director.navigation_ready = false)
	super._ready()
	boss.destroyed.connect(_on_boss_destroyed)
	boss.phase_changed.connect(func(_phase: int): toast("CERBÈRE surchauffe ! Les rafales s'accélèrent. Restez mobile."))
	for connection in reset_button.pressed.get_connections():
		reset_button.pressed.disconnect(connection.callable)
	reset_button.pressed.connect(_on_secondary)
	update_relays()
	update_hud()


func apply_difficulty() -> void:
	super.apply_difficulty()
	boss.configure_difficulty(Difficulty.PROFILES[active_difficulty])
	alpha.configure_difficulty(Difficulty.PROFILES[active_difficulty])
	for guard in upper_director.get_children(): guard.configure_difficulty(Difficulty.PROFILES[active_difficulty])
	upper_director.projectile_damage = Difficulty.PROFILES[active_difficulty].damage
	upper_director.projectile_speed = Difficulty.PROFILES[active_difficulty].bolt_speed


func _unhandled_input(event: InputEvent) -> void:
	if mission_complete and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func is_run_finished() -> bool:
	return game_over or mission_complete


func show_pause() -> void:
	super.show_pause()
	if hud != null:
		hud.hide()
	var controls: Label = $Interface/Overlay/Card/Content/Controls
	controls.text = "ZQSD / WASD    Se déplacer\nMAJ / CTRL          Courir / S'accroupir (maintenir)\nSOURIS                Regarder\nCLIC G. / R           Tirer / Recharger\nCLIC DROIT          Visée précise (maintenir)\nESPACE               Sauter\nE                         Relais / Console / Ascenseur\nÉCHAP                 Pause / Reprendre"
	$Interface/Overlay/Card/Content/Kicker.text = "CAMPAGNE  /  LES DEUX GARDIENS"
	title.text = "Les deux gardiens." if not has_started else "Mission en pause."
	subtitle.text = "Activez les relais, abattez CERBÈRE, puis montez affronter FENRIR au deuxième étage." if not has_started else "Progression conservée. Reprenez quand vous voulez."
	$Interface/Overlay/Card/Content/Note.text = "Suivez les repères et la carte.\nRelais, consoles et arrivée à l’étage restaurent votre santé."
	resume_button.text = "Commencer la mission  →" if not has_started else "Reprendre la mission"
	reset_button.visible = true
	reset_button.text = "Terrain d'entraînement" if not has_started else "Recommencer la mission"
	if game_over:
		title.text = "Signal perdu."
		subtitle.text = "Repartez du quai. Utilisez les caisses pour vous protéger."
		resume_button.text = "Recommencer la mission  →"
		reset_button.hide()
		$Interface/Overlay/Card/Content/Note.text = "Relais : %d / 3  ·  Hostiles : %d / %d\nLes relais restaurent votre santé." % [mini(stage,3), drones_destroyed, hostile_total()]
	if mission_complete:
		title.text = "Mission accomplie."
		subtitle.text = "Les deux gardiens sont vaincus. L’extraction orbitale est sécurisée."
		controls.hide()
		resume_button.text = "Rejouer la mission  →"
		reset_button.text = "Terrain d'entraînement"
		$Interface/Overlay/Card/Content/Note.text = "%s · Gardiens neutralisés · %d / %d hostiles\nTemps : %s  ·  Santé : %d / 100" % [Difficulty.PROFILES[active_difficulty].name, drones_destroyed, hostile_total(), time_text(), player.health]
	if boss_trial and not has_started:
		title.text = "CERBÈRE."
		subtitle.text = "Affrontez directement le gardien du cœur HELIX, puis rejoignez l'extraction."
		resume_button.text = "Affronter le boss  →"
		$Interface/Overlay/Card/Content/Note.text = "Deux lasers rouges annoncent la rafale : esquivez.\nÀ mi-vie, CERBÈRE devient plus agressif."
	if alpha_trial and not has_started:
		title.text = "FENRIR."
		subtitle.text = "Affrontez directement l’alpha des chiens robots au deuxième étage."
		resume_button.text = "Affronter FENRIR  →"
		$Interface/Overlay/Card/Content/Note.text = "Deux canons laser, quatre pattes et une carapace lourde.\nÀ mi-vie, ses rafales passent de quatre à six impulsions."
	if mission_complete and (boss_trial or alpha_trial):
		subtitle.text = "Gardien neutralisé. Vous avez rejoint l’extraction."
	update_difficulty_picker()
	resume_button.grab_focus()


func start_exploration() -> void:
	if game_over or mission_complete:
		restart_exploration()
		return
	var first := not has_started
	super.start_exploration()
	hud.show()
	if first:
		toast("Quai sécurisé : essayez les cibles, puis suivez la ligne cyan.")
	if boss_trial and stage==0:
		start_boss_trial()
	if alpha_trial and stage==0:
		start_alpha_trial()
	update_hud()


func start_boss_trial() -> void:
	stage = 3
	for i in range(2): gates[i].unlock()
	player.global_position = Vector3(-15,.05,-56)
	player.velocity = Vector3.ZERO
	player.look_at(Vector3(boss.position.x,player.position.y,boss.position.z))
	player.head.look_at(boss.global_position)
	player.reset_physics_interpolation()
	update_relays()
	boss.activate()
	toast("CERBÈRE actif. Bougez dès que les lasers rouges apparaissent !")


func start_alpha_trial() -> void:
	# Raccourci de test explicite ; la campagne utilise toujours la cabine physique.
	stage = 7
	player.global_position = Vector3(0,14.05,-185)
	player.velocity = Vector3.ZERO
	player.look_at(Vector3(alpha.position.x,player.position.y,alpha.position.z))
	player.head.rotation = Vector3.ZERO
	player.reset_physics_interpolation()
	for gate in upper_gates.slice(0,2): gate.unlock()
	alpha.activate()
	toast("FENRIR actif. Quittez le point annoncé par la visée rouge !")


func restart_exploration() -> void:
	stage = 0
	elapsed = 0.0
	extraction_progress = 0.0
	mission_complete = false
	can_interact = false
	boss.deactivate()
	alpha.deactivate()
	lift.reset_lift()
	upper_director.reset_encounter()
	for gate in upper_gates: gate.reset_gate()
	for relay in upper_relays:
		relay.get_node("Label").text = "VERROU SECURITE"
		for sound in ["ActivationSound","DeniedSound"]: relay.get_node(sound).stop()
	for gate in gates:
		gate.reset_gate()
	for kit in $Arena/Medical.get_children()+$UpperArena/Medical.get_children():
		kit.get_node("PickupSound").stop()
		kit.show()
	for relay in relays:
		relay.get_node("ActivationSound").stop()
		relay.get_node("DeniedSound").stop()
	update_relays()
	super.restart_exploration()
	toast("Nouvelle mission. Rejoignez le relais cargo.")
	update_hud()


func _on_secondary() -> void:
	if mission_complete or not has_started:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	else:
		restart_exploration()


func _process(delta: float) -> void:
	super._process(delta)
	if get_tree().paused or mission_complete or not has_started:
		return
	elapsed += delta
	toast_remaining = maxf(0.0, toast_remaining - delta)
	hud.get_node("Toast").visible = toast_remaining > 0.0
	update_hud()


func _physics_process(delta: float) -> void:
	if get_tree().paused or game_over or mission_complete or not has_started:
		return
	for kit in $Arena/Medical.get_children()+$UpperArena/Medical.get_children():
		if kit.visible and player.health < player.max_health and player.global_position.distance_to(kit.global_position) < 1.3:
			kit.hide()
			kit.get_node("PickupSound").play()
			player.health = mini(player.health + 40, player.max_health)
			player.health_changed.emit(player.health, player.max_health)
			toast("Kit de réparation : intégrité +40.")
	if stage < 3:
		if director.current_sector != stage and player.global_position.z < float(layout.engage_z[stage]):
			director.engage_sector(stage)
			toast("Secteur actif : drones aériens et LIMIER K-9 au sol. Neutralisez les hostiles.")
		can_interact = relay_accessible()
		if Input.is_action_just_pressed("interact"):
			activate_relay()
	elif stage == 4 and not boss_trial:
		can_interact = lift.state=="boarding" and lift.contains_player(player)
		if Input.is_action_just_pressed("interact"): lift.request_ride(player)
	elif stage in [5,6]:
		var sector := stage-5
		if player.global_position.y>13 and player.global_position.z<(-104 if sector==0 else -144):
			upper_director.engage_sector(sector)
		can_interact = upper_relay_accessible()
		if Input.is_action_just_pressed("interact"): activate_upper_relay()
	elif stage == 8 or (stage == 4 and boss_trial):
		var exit: Array = layout.extraction if boss_trial else upper_layout.extraction
		var distance := Vector2(player.position.x-exit[0],player.position.z-exit[1]).length()
		extraction_progress = extraction_progress + delta if distance < 3.0 and player.is_on_floor() and absf(player.position.y-(0.0 if boss_trial else 14.0))<.3 else 0.0
		if extraction_progress >= 2.0:
			mission_complete = true
			show_pause()


func relay_accessible() -> bool:
	if stage >= 3 or director.current_sector != stage or director.remaining(stage) > 0:
		return false
	var relay: Node3D = relays[stage]
	if player.global_position.distance_to(relay.global_position) > 2.6:
		return false
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, relay.get_node("Interaction").global_position, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == relay.get_node("Body")


func activate_relay() -> bool:
	if get_tree().paused or game_over or mission_complete or not has_started:
		return false
	if not relay_accessible():
		if stage < 3 and player.global_position.distance_to(relays[stage].global_position) < 2.6:
			var denied: AudioStreamPlayer3D = relays[stage].get_node("DeniedSound")
			if not denied.playing: denied.play()
		return false
	relays[stage].get_node("ActivationSound").play()
	if stage < 2:
		gates[stage].unlock()
	stage += 1
	can_interact = false
	player.restore_health()
	for bolt in $Projectiles.get_children():
		bolt.queue_free()
	update_relays()
	if stage == 3:
		boss.activate()
		toast("ALERTE : CERBÈRE s'éveille au cœur HELIX. Détruisez le gardien pour débloquer l’ascenseur !")
	else:
		toast("Relais rétabli. Santé restaurée. Rejoignez le secteur suivant.")
	update_hud()
	return true


func _on_boss_destroyed(_boss: CharacterBody3D) -> void:
	if stage != 3:
		return
	stage = 4
	drones_destroyed += 1
	gates[2].unlock()
	lift.unlock()
	for bolt in $Projectiles.get_children():
		bolt.queue_free()
	toast("CERBÈRE neutralisé ! Rejoignez la zone cyan pour terminer l’essai." if boss_trial else "CERBÈRE neutralisé ! Entrez dans l’ascenseur, puis appuyez sur E pour monter.")
	update_hud()


func update_relays() -> void:
	for i in range(relays.size()):
		relays[i].get_node("Label").text = ("EN LIGNE" if i < stage else layout.relay_names[i])
		relays[i].get_node("Label").modulate = Color(.3,.95,.83) if i < stage else Color(1,.6,.3)


func _on_drone_destroyed(_drone: CharacterBody3D) -> void:
	drones_destroyed += 1
	if stage < 3 and director.remaining(stage) == 0:
		toast("Secteur sécurisé. Rejoignez le relais et appuyez sur E.")
	if stage in [5,6] and upper_director.remaining(stage-5)==0:
		toast("Secteur sécurisé. Activez la console avec E pour poursuivre.")
	update_hud()


func toast(message: String) -> void:
	if hud == null:
		return
	hud.get_node("Toast").text = message
	toast_remaining = 5.0
	hud.get_node("Toast").show()


func time_text() -> String:
	return "%02d:%02d" % [int(elapsed / 60.0), int(elapsed) % 60]


func hostile_total() -> int:
	return 1 if boss_trial or alpha_trial else director.get_child_count()+upper_director.get_child_count()+2


func _on_lift_arrived() -> void:
	if stage!=4 or boss_trial: return
	stage = 5
	can_interact = false
	player.restore_health()
	toast("Étage 02 : le chenil. Sécurisez les deux secteurs pour ouvrir l’antre de FENRIR.")
	update_hud()


func upper_relay_accessible() -> bool:
	if stage not in [5,6] or player.position.y<13: return false
	var index := stage-5
	if upper_director.current_sector!=index or upper_director.remaining(index)>0: return false
	var relay: Node3D = upper_relays[index]
	if player.global_position.distance_to(relay.global_position)>2.6: return false
	var query := PhysicsRayQueryParameters3D.create(player.get_node("Head/Camera3D").global_position,relay.get_node("Interaction").global_position,1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider==relay.get_node("Body")


func activate_upper_relay() -> bool:
	if get_tree().paused or game_over or mission_complete or not has_started: return false
	if not upper_relay_accessible():
		if stage in [5,6] and player.global_position.distance_to(upper_relays[stage-5].global_position)<2.6:
			upper_relays[stage-5].get_node("DeniedSound").play()
		return false
	var index := stage-5
	upper_relays[index].get_node("ActivationSound").play()
	upper_relays[index].get_node("Label").text = "VERROU LEVE"
	upper_gates[index].unlock()
	stage += 1
	can_interact = false
	player.restore_health()
	for bolt in $Projectiles.get_children(): bolt.queue_free()
	if stage==7:
		alpha.activate()
		toast("FENRIR est libre ! Esquivez la visée rouge et visez entre ses rafales.")
	else: toast("Premier verrou levé. Santé restaurée. Rejoignez l’usine des limiers.")
	update_hud()
	return true


func _on_alpha_destroyed(_enemy: CharacterBody3D) -> void:
	if stage!=7: return
	stage = 8
	can_interact = false
	drones_destroyed += 1
	upper_gates[2].unlock()
	for bolt in $Projectiles.get_children(): bolt.queue_free()
	toast("FENRIR neutralisé ! Rejoignez l’extraction orbitale, au fond de son antre.")
	update_hud()


func update_hud() -> void:
	if layout.is_empty(): return
	var upstairs := player.position.y>10
	var active_layout: Dictionary = upper_layout if upstairs else layout
	$Interface/Header/Mode.text = "COMBAT BOSS / FENRIR" if alpha_trial else ("COMBAT BOSS / CERBÈRE" if boss_trial else "CAMPAGNE / LES DEUX GARDIENS")
	$Interface/Header/DroneCount.text = "HOSTILES   %02d / %02d" % [drones_destroyed,hostile_total()]
	for i in range(active_layout.floors.size()):
		var r: Array = active_layout.floors[i]
		if Rect2(r[0],r[1],r[2],r[3]).has_point(Vector2(player.position.x,player.position.z)):
			$Interface/Header/Sector.text = ("02 / " if upstairs else "01 / ")+active_layout.floor_names[i]
			if not upstairs and i==3 and not boss_trial: $Interface/Header/Sector.text = "01 / ASCENSEUR"
	var destination: Array
	if stage<3: destination = layout.relays[stage]
	elif stage==3: destination = [boss.position.x,boss.position.z]
	elif stage==4: destination = layout.extraction
	elif stage<7: destination = upper_layout.relays[stage-5]
	elif stage==7: destination = [alpha.position.x,alpha.position.z]
	else: destination = upper_layout.extraction
	var distance := Vector2(player.position.x-destination[0],player.position.z-destination[1]).length()
	hud.get_node("Objective/Content/Kicker").text = "OBJECTIF %02d / %02d  ·  %d m" % [stage+1,5 if boss_trial else 9,roundi(distance)]
	var titles := ["Rétablir le relais cargo","Rétablir le refroidissement","Rétablir le cœur HELIX","Détruire CERBÈRE","Prendre l’ascenseur","Sécuriser le chenil","Lever le second verrou","Détruire FENRIR","Extraction orbitale"]
	hud.get_node("Objective/Content/Title").text = "Rejoindre l’extraction" if boss_trial and stage==4 else titles[stage]
	var instruction := "Suivez la ligne cyan pour rejoindre le secteur."
	if stage<3 and director.current_sector==stage:
		var guards: int = director.remaining(stage)
		instruction = "%d hostile(s) restant(s)." % guards if guards else "Approchez du relais et appuyez sur E."
	elif stage==3 or stage==7: instruction = "Esquivez la visée rouge. Tirez entre les rafales."
	elif stage==4:
		instruction = "Entrez dans la cabine et appuyez sur E."
		if lift.state in ["closing","rising","opening"]: instruction = "Montée vers l’étage 02… Restez dans la cabine."
	elif stage in [5,6]:
		var guards: int = upper_director.remaining(stage-5)
		instruction = "%d hostile(s) restant(s)." % guards if guards else "Rejoignez la console. E : lever le verrou."
		if upper_director.current_sector!=stage-5: instruction = "Entrez dans le secteur, puis sécurisez sa console."
	if stage==8 or (boss_trial and stage==4): instruction = "Restez deux secondes au centre de la zone cyan."
	hud.get_node("Objective/Content/Task").text = instruction
	hud.get_node("Objective/Content/Progress").text = "ETAGE %02d / 02  ·  TEMPS %s" % [2 if upstairs else 1,time_text()]
	hud.get_node("MapPanel/Title").text = "CARTE / ETAGE %02d / N ↑" % (2 if upstairs else 1)
	var active_boss: CharacterBody3D = alpha if stage>=7 else boss
	var panel: Control = hud.get_node("Boss")
	panel.visible = stage in [3,7] and active_boss.alive
	hud.get_node("Boss/Content/Health").max_value = active_boss.max_health
	hud.get_node("Boss/Content/Health").value = active_boss.health
	hud.get_node("Boss/Content/Name").text = ("FENRIR / HELIX ALPHA" if stage>=7 else "CERBÈRE / HELIX M-90")+"  ·  %d %%" % ceili(float(active_boss.health)/active_boss.max_health*100)
	hud.get_node("Boss/Content/Phase").text = ("PHASE 2 / RAGE" if stage>=7 else "PHASE 2 / SURCHAUFFE") if active_boss.phase==2 else "PHASE 1 / DOUBLE CANON"
	var hint: Label = hud.get_node("Interaction")
	hint.text = ("E / MONTER A L’ETAGE 02" if stage==4 else "E / ACTIVER LA CONSOLE") if can_interact else ""
	if (stage==8 or (boss_trial and stage==4)) and extraction_progress>0:
		hint.text = "EXTRACTION %d %%" % mini(int(extraction_progress/2*100),100)
