extends Node3D

enum Step { BRIEFING, INTRO, TUTORIAL, HABITAT, BIKE, WORKSHOP, TRANSPORT, CONTROL, REVEAL, BATTLE, BOARD, ASCENT, COMPLETE }

const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const ROUTES := preload("res://missions/lunar_escape/lunar_routes.gd")
const HUD := preload("res://missions/lunar_escape/campaign_hud.gd")
const DIRECTOR := preload("res://scripts/drone_director.gd")
const DRONE := preload("res://scenes/drone.tscn")
const HOUND := preload("res://scenes/hound.tscn")
const SPIDER := preload("res://missions/lunar_escape/spider.gd")
const MOTHERSHIP := preload("res://missions/lunar_escape/mothership.gd")
const PICKUP_SOUND := preload("res://audio/repair_pickup.wav")
const DOOR_SOUND := preload("res://audio/door_open.wav")
const MOTOR_SOUND := preload("res://audio/elevator_motor.wav")
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const SUPPORT_DRONE := preload("res://missions/lunar_escape/support_drone.gd")
const BASE_LIFE := preload("res://missions/lunar_escape/base_life.gd")
const VOICE := preload("res://missions/lunar_escape/briefing_voice.gd")
const THREAT := [
	{"drone_hp": 3, "hound_hp": 4, "spider_hp": 5, "drone_speed": 3.0, "hound_speed": 3.4, "spider_speed": 3.2,
		"damage": 8, "spider_damage": 8, "bolt_speed": 16.0, "interval": 1.0},
	{"drone_hp": 5, "hound_hp": 7, "spider_hp": 7, "drone_speed": 3.8, "hound_speed": 4.55, "spider_speed": 4.1,
		"damage": 14, "spider_damage": 11, "bolt_speed": 20.0, "interval": 0.83},
	{"drone_hp": 8, "hound_hp": 9, "spider_hp": 10, "drone_speed": 4.85, "hound_speed": 5.35, "spider_speed": 5.2,
		"damage": 18, "spider_damage": 15, "bolt_speed": 24.0, "interval": 0.69},
]

@onready var pilot = $Player
@onready var world = $Terrain
@onready var film: Camera3D = $FilmCamera
@onready var camera: Camera3D = $Player/Head/Camera3D

var step := Step.BRIEFING
var hud: CanvasLayer
var directors: Array[Node3D] = []
var upper_directors: Array[Node3D] = []
var trials: Dictionary = {}
var resident_spiders: Array[Node3D] = []
var standby_guards: Array[Node3D] = []
var equipment_room: Node3D
var clearance: Array[bool] = [false, false, false]
enum Power { ONLINE, OUTAGE, RESTORED }
var selene_power := Power.ONLINE
var selene_lighting := preload("res://missions/lunar_escape/base_power_lighting.gd").new()
var breaker: Marker3D
var garage_alarm := false
var transition := false
var on_upper_floor := false
var tutorial_drone: CharacterBody3D
var mothership: AnimatableBody3D
var supplies: Dictionary = {}
var searchable_furniture: Dictionary = {}
var road_guards: Array[Node3D] = []
var mechanic: Node3D
var rescue_guard: CharacterBody3D
var mechanic_rescued := false
var patrol_warning_given := false
var service_used := false
var lookout: Marker3D
var message_heard := false
var code_station: Marker3D
var armor_stand: Node3D
var armor_taken := false
var armor_worn := false
var code_window: ConfirmationDialog
var code_entry: LineEdit
var code_instructions: Label
var code_context := "tycho"
var access_codes := preload("res://missions/lunar_escape/access_codes.gd").new()
var checkpoint := Vector3(-9.52, 0.045, 16.4)
var checkpoint_heading := -PI / 2.0
var dialogue_until := 0.0
var game_time := 0.0
var defeated := false
var interaction := ""
var audio: AudioStreamPlayer
var base_life: Node3D
var story: Node3D
var squad: Node3D
var exploration: CanvasLayer
var voice: AudioStreamPlayer
var arrival_tutorial_hint := false
var saver := preload("res://missions/lunar_escape/campaign_save.gd").new()
var soundscape: Node
var save_clock := 0.0
var saved_stage := -1


func _ready() -> void:
	hud = HUD.new()
	add_child(hud)
	hud.damage_feedback.camera = camera
	pilot.health_changed.connect(hud.set_health)
	pilot.directional_hit.connect(hud.damage_feedback.receive_hit)
	hud.set_health(pilot.health,pilot.max_health)
	hud.start_pressed.connect(on_primary)
	hud.continue_pressed.connect(continue_saved_game)
	hud.menu_pressed.connect(toggle_pause)
	hud.restart_pressed.connect(restart)
	pilot.died.connect(on_death)
	camera.far = 4200.0
	film.far = camera.far
	audio = AudioStreamPlayer.new()
	audio.volume_db = -16.0
	add_child(audio)
	create_encounters()
	create_supplies()
	stock_rations()
	create_road_guards()
	create_exit_tasks()
	create_optional_encounters()
	base_life = BASE_LIFE.new()
	add_child(base_life)
	base_life.setup(self)
	story = preload("res://missions/lunar_escape/story.gd").new()
	add_child(story)
	squad = preload("res://missions/lunar_escape/escort_squad.gd").new()
	squad.name = "EscortSquad"
	add_child(squad)
	squad.setup(self)
	story.setup(self)
	exploration = preload("res://missions/lunar_escape/exploration_map.gd").new()
	add_child(exploration); exploration.setup(self)
	voice = VOICE.new()
	add_child(voice)
	soundscape = preload("res://missions/lunar_escape/soundscape.gd").new()
	add_child(soundscape)
	soundscape.setup(self)
	pilot.loadout = preload("res://missions/lunar_escape/dual_loadout.gd").new()
	add_child(pilot.loadout);pilot.loadout.setup(self)
	equipment_room = preload("res://missions/lunar_escape/equipment_room.gd").new()
	world.add_child(equipment_room);equipment_room.setup(self)
	var polish := preload("res://missions/lunar_escape/campaign_polish.gd").new()
	add_child(polish); polish.setup(self)
	var bunkers := preload("res://missions/lunar_escape/secret_bunkers.gd").new()
	add_child(bunkers);bunkers.setup(self)
	var construction := preload("res://missions/lunar_escape/construction.gd").new()
	add_child(construction);construction.setup(self)
	var cabinet_loot:=preload("res://missions/lunar_escape/cabinet_loot.gd").new()
	add_child(cabinet_loot);cabinet_loot.setup(self)
	prepare_final_encounter()
	for door in world.doors.values():
		door.opened.connect(rebuild_navigation.bind(door.global_position))
	frame_camera(Vector3(18,12,58),Vector3(0,5,40))
	film.make_current()
	hud.set_film(true)
	hud.save_available = not saver.read_save().is_empty()
	hud.show_menu("intro")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func create_encounters() -> void:
	for index in range(3):
		directors.append(create_director(index, false))
		upper_directors.append(create_director(index, true))
		trials["upper_%d" % index] = {"base": index, "upper": true, "started": false, "left": 0}
		if index > 0:
			trials["ground_%d" % index] = {"base": index, "upper": false, "started": false, "left": 0}
	tutorial_drone = add_enemy(0, Vector3(0.7, 2.4, 11.9), "DRONE DE SÉCURITÉ")
	tutorial_drone.patrol_points = PackedVector3Array([
		Vector3(-1.4, 2.3, 13.0), Vector3(-.9, 2.3, 15.1),
		Vector3(1.4, 2.3, 14.6), Vector3(.7, 2.3, 11.9),
	])
	tutorial_drone.initial_delay = 0.0
	tutorial_drone.cooldown = 0.0
	tutorial_drone.destroyed.connect(on_tutorial_drone_destroyed)
	add_enemy(0, Vector3(6.5, 2.4, 2), "SENTINELLE")
	add_enemy(0, Vector3(-7.5, 2.4, -2.0), "SENTINELLE")
	add_enemy(0, Vector3(8.8, 2.4, -12.6), "SENTINELLE")
	add_enemy(1, Vector3(-5, 2.4, 11.2), "SENTINELLE TYCHO")
	add_enemy(1, Vector3(-7, 0.04, 2), "LIMIER TYCHO", true)
	add_enemy(1, Vector3(7.5, 2.4, -2.3), "SENTINELLE TYCHO")
	add_enemy(1, Vector3(8.0, 0.04, -13.5), "LIMIER TYCHO", true)
	add_enemy(2, Vector3(4, 2.4, 10.5), "SENTINELLE COPERNIC")
	add_enemy(2, Vector3(-5, 2.4, -12.8), "SENTINELLE COPERNIC")
	for key in trials: prepare_trial(key)
	# Residents are visible before any doorway trigger; population is fixed per level.
	for base in range(3):
		for point in [Vector3(24,2.4,-2),Vector3(-38,2.4,-8),Vector3(24,2.4,12)]:
			add_enemy(base,point,"PATROUILLE INTÉRIEURE")
	for i in range(3):
		var spider := add_spider(2,[18.1,5.8,-15.85][i],[12.0,1.2,28.8][i])
		if i!=1: spider.arm_ambush()
		spider.process_mode = Node.PROCESS_MODE_DISABLED
		resident_spiders.append(spider)
	for point in [Vector3(20.2,0.045,-12.35),Vector3(18.2,0.045,-12.35)]:
		var guard := add_enemy(1,point,"LIMIER DE GARDE",true)
		guard.process_mode = Node.PROCESS_MODE_DISABLED
		standby_guards.append(guard)


func create_director(base: int, upstairs: bool) -> Node3D:
	var director := DIRECTOR.new()
	director.name = "Hostiles_%d_%d" % [base, int(upstairs)]
	var z := int(WORLD.BASE_Z[base])
	director.navigation_region = Rect2i(11, z - 17, 25, 31) if upstairs else Rect2i(-35, z - 19, 71, 39)
	director.floor_height = WORLD.UPPER_HEIGHT if upstairs else 0.0
	director.flight_height = director.floor_height + 2.4
	director.ground_radius = 0.8
	director.projectile_damage = THREAT[base].damage
	director.projectile_speed = THREAT[base].bolt_speed
	director.hound_damage_scale = 0.75
	director.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(director)
	return director


func add_enemy(base: int, point: Vector3, title: String, hound := false, upstairs := false, support_role := -1) -> CharacterBody3D:
	var enemy := (HOUND if hound else DRONE).instantiate() as CharacterBody3D
	if support_role >= 0:
		enemy.set_script(SUPPORT_DRONE)
		enemy.role = support_role
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	enemy.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	enemy.campaign_combat = true
	var director := upper_directors[base] if upstairs else directors[base]
	enemy.position = point + Vector3(0, director.floor_height, WORLD.BASE_Z[base])
	enemy.drone_name = title
	var tier: Dictionary = THREAT[base]
	enemy.max_health = tier.hound_hp if hound else tier.drone_hp
	enemy.move_speed = tier.hound_speed if hound else tier.drone_speed
	enemy.fire_interval = (1.52 if hound else 2.3) * tier.interval
	enemy.charge_duration = (0.61 if hound else 0.66) * tier.interval
	enemy.initial_delay *= tier.interval
	enemy.orbit_direction = -1.0 if director.get_child_count() % 2 == 0 else 1.0
	director.add_child(enemy)
	for mesh in enemy.find_children("*","MeshInstance3D",true,false):
		if mesh.material_override!=null: mesh.material_override = WORLD.FINISH.material(mesh.material_override)
		elif mesh.mesh!=null:
			for surface in range(mesh.mesh.get_surface_count()):
				var source: Material = mesh.get_active_material(surface)
				if source!=null: mesh.set_surface_override_material(surface,WORLD.FINISH.material(source))
	preload("res://missions/lunar_escape/enemy_roles.gd").install(enemy,hound,base)
	return enemy


func create_optional_encounters() -> void:
	world.doors["dome_1_-1"].lock()
	world.doors["dome_1_-1"].title = "Atelier isolé"
	rescue_guard = add_enemy(1, Vector3(-19.5, 2.4, 12.4), "DRONE ÉCLAIREUR", false, false, SUPPORT_DRONE.Role.SCOUT)
	rescue_guard.destroyed.connect(func(_guard):
		story.refresh_workshop_door()
		if step == Step.WORKSHOP:
			speak("LINA · Le drone est neutralisé. Rétablissez le courant si le sas reste verrouillé, puis venez me chercher.", 5.0)
	)
	var rescue_backup: Array[Node3D] = []
	for point in [Vector3(-9.5,2.4,14.1),Vector3(-11.8,2.4,10.9)]:
		var guard := add_enemy(1,point,"RENFORT · TYCHO")
		guard.process_mode = Node.PROCESS_MODE_DISABLED
		rescue_backup.append(guard)
	rescue_guard.reinforcements_called.connect(func():
		for guard in rescue_backup:
			if is_instance_valid(guard): guard.process_mode = Node.PROCESS_MODE_INHERIT
		speak("LINA · L’éclaireur a transmis votre position. Deux drones arrivent !", 4.0)
	)
	var workshop := world.get_node("Tycho/Observatoire")
	mechanic = preload("res://missions/lunar_escape/escort_suit.gd").new()
	workshop.add_child(mechanic)
	mechanic.position = Vector3(-3.5, 0, 2.9)
	mechanic.identity = "LINA"
	mechanic.accent = Color("bda071")
	mechanic.build()
	mechanic.gun.hide()
	world.placard(workshop, "ATELIER DE SECOURS", Vector3(0, 2.85, 2.2), Color("ffe2ab"), PI)
	var observatory := world.get_node("Copernic/Observatoire")
	lookout = Marker3D.new()
	observatory.add_child(lookout)
	lookout.position = Vector3(0, 1.32, 2.17)
	KIT.bevel(observatory, Vector3(0, 1.16, 2.56), Vector3(0.64, 0.28, 0.36), 0.045, WORLD.STEEL)
	KIT.bevel(observatory, Vector3(0, 1.31, 2.49), Vector3(0.18, 0.045, 0.13), 0.018, WORLD.CYAN)
	add_enemy(2, Vector3(-8.4, 2.4, -11.2), "DRONE DE MAINTENANCE", false, false, SUPPORT_DRONE.Role.REPAIR)


func rebuild_navigation(position_of_door: Vector3) -> void:
	for base in range(WORLD.BASE_Z.size()):
		if absf(position_of_door.z - WORLD.BASE_Z[base]) <= 21.0:
			var director := upper_directors[base] if position_of_door.y >= WORLD.UPPER_HEIGHT - 0.2 else directors[base]
			director.navigation_ready = false
			return


func begin_trial(key: String) -> void:
	var trial: Dictionary = trials[key]
	if trial.started: return
	trial.started = true
	if trial.upper:
		checkpoint = WORLD.at(trial.base,31.8,WORLD.UPPER_HEIGHT+0.04,-13.7)
		checkpoint_heading = PI/2
		upper_directors[trial.base].process_mode = Node.PROCESS_MODE_INHERIT
	for enemy in trial.enemies:
		if is_instance_valid(enemy): enemy.process_mode = Node.PROCESS_MODE_INHERIT
	if trial.left==0: world.doors[key].unlock()
	speak("SÉCURITÉ · Neutralisez les hostiles pour déverrouiller le sas.",3.6)
	refresh_base_objective(trial.base)

func prepare_trial(key: String) -> void:
	var trial: Dictionary = trials[key]
	var base: int = trial.base
	var upstairs: bool = trial.upper
	var enemies: Array[Node3D] = []
	if upstairs:
		enemies.append(add_enemy(base, Vector3(25, 2.4, -10.5), "GARDE DES TRANSMISSIONS", false, true))
		if base == 2:
			enemies.append(add_spider(base, -1.4, 2.4, true))
			enemies.append(add_spider(base, -10.7, 15.0, true))
		else:
			enemies.append(add_enemy(base, Vector3(30, 0.04 if base == 1 else 2.4, -4.3),
				"LIMIER DE GARDE" if base == 1 else "SENTINELLE DE GARDE", base == 1, true))
			enemies.append(add_enemy(base, Vector3(16, 2.4, 4.7), "SENTINELLE DE GARDE", false, true))
	else:
		enemies.append(add_enemy(base, Vector3(5.8, 2.4, 13.4), "DRONE D’INTERVENTION"))
		if base == 1:
			enemies.append(add_enemy(base, Vector3(-8.4, 0.04, 15.8), "LIMIER D’INTERVENTION", true))
		else:
			enemies.append(add_enemy(base, Vector3(-8.2, 2.4, 14.7), "SENTINELLE D’INTERVENTION"))
	for enemy in enemies:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.destroyed.connect(on_trial_enemy_destroyed.bind(key), CONNECT_ONE_SHOT)
	trial.left = enemies.size()
	trial.enemies = enemies


func on_trial_enemy_destroyed(_enemy: Node3D, key: String) -> void:
	var trial: Dictionary = trials[key]
	trial.left = maxi(0,trial.left-1)
	if trial.left == 0:
		world.doors[key].unlock()
		speak("SÉCURITÉ · Zone sécurisée. Le sas peut être ouvert.", 3.1)
	refresh_base_objective(trial.base)


func add_spider(base: int, lane: float, offset: float, upstairs := false) -> CharacterBody3D:
	var spider := SPIDER.new()
	spider.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	spider.pilot = pilot
	spider.lane = WORLD.BASE_Z[base] + lane
	spider.offset = offset
	var tier: Dictionary = THREAT[base]
	spider.health = tier.spider_hp
	spider.move_speed = tier.spider_speed
	spider.projectile_damage = tier.spider_damage
	spider.projectile_speed = tier.bolt_speed + 2.0
	spider.fire_interval *= tier.interval
	spider.charge_duration *= tier.interval
	if upstairs:
		spider.floor_level = WORLD.UPPER_HEIGHT
		spider.left_wall = 12.17
		spider.right_wall = 34.32
	add_child(spider)
	return spider


func create_supplies() -> void:
	add_supply("pistol", "Pistolet", Vector3(-8.30, 1.20, 13.90), "pistol")
	add_supply("ammo_dorm", "Munitions de pistolet", Vector3(4.0, 0.50, 14.5), "ammo")
	add_supply("ammo_store", "Munitions de pistolet", Vector3(9.2, 0.48, 1.6), "ammo")
	add_supply("ammo_exit", "Munitions de pistolet", Vector3(4.8, 0.48, -15.7), "ammo")
	add_supply("ammo_workshop", "Munitions de pistolet", WORLD.at(1, -5.4, 0.48, 11.5), "ammo")
	add_supply("ammo_maintenance", "Munitions de pistolet", WORLD.at(1, -9, 0.48, -0.8), "ammo")
	add_supply("shotgun", "Fusil à pompe", WORLD.at(1, 7.6, 0.90, -13.5), "shotgun")
	add_supply("smg", "Fusil automatique", WORLD.at(2, -7, 0.90, 3.3), "smg")
	add_supply("shield", "Bouclier", WORLD.at(2, 8.2, 0.90, -14.2), "shield")
	add_supply("ammo_pad", "Munitions pour les trois armes", WORLD.pad(-4.8, 0.48, -223), "ammo_all")
	for index in range(world.room_racks.size()):
		var kind := "shotgun" if index >= 6 else "pistol"
		add_supply("rack_%d" % index, pilot.WEAPONS[kind].name, world.room_racks[index].global_position, kind, true)
	for base in range(3):
		add_supply("upper_ammo_%d" % base, "Munitions de la réserve", WORLD.at(base, 31.4, WORLD.UPPER_HEIGHT + 0.49, 6.9), "ammo_all" if base == 2 else "ammo")


func add_supply(id: String, title: String, point: Vector3, kind: String, on_rack := false) -> void:
	var prop := Node3D.new()
	prop.name = id
	prop.position = point
	world.add_child(prop)
	if kind in ["pistol", "shotgun", "smg"]:
		var gun := WORLD.gun(prop, kind)
		gun.rotation_degrees = Vector3(0, 90, 0) if on_rack else Vector3(0, 29, 90)
		if on_rack:
			gun.scale = Vector3.ONE * 1.65
		elif kind != "pistol":
			KIT.bevel(prop, Vector3(0, -0.47, 0), Vector3(1.15, 0.85, 0.84), 0.11, WORLD.FRAME, true)
			KIT.bevel(prop, Vector3(0, -0.06, 0), Vector3(1.22, 0.08, 0.91), 0.029, WORLD.CYAN)
	elif kind == "shield":
		WORLD.block(prop, Vector3(0, -0.40, 0), Vector3(0.95, 1.0, 0.8), WORLD.FRAME, true)
		WORLD.block(prop, Vector3(0, 0.32, 0), Vector3(0.70, 0.81, 0.13), WORLD.FRAME)
		WORLD.block(prop, Vector3(0, 0.32, 0.07), Vector3(0.61, 0.71, 0.06), WORLD.CYAN)
	else:
		world.furnishings.ammunition_case(prop, kind == "ammo_all")
	if kind in ["shotgun", "smg", "shield"] and not on_rack:
		var caption := WORLD.placard(prop, title.to_upper(), Vector3(0, 0.75, 0), Color("d5f3ff"))
		caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		caption.pixel_size = 0.0045
	supplies[id] = {"node": prop, "title": title, "kind": kind, "on_rack": on_rack}


func create_exit_tasks() -> void:
	var observatory := world.get_node("Selene/Observatoire")
	breaker = Marker3D.new()
	observatory.add_child(breaker)
	breaker.position = Vector3(0, 1.21, 2.18)
	KIT.bevel(observatory, Vector3(0, 1.13, 2.58), Vector3(0.72, 0.24, 0.39), 0.045, WORLD.FRAME)
	KIT.bevel(observatory, Vector3(0, 1.25, 2.49), Vector3(0.21, 0.045, 0.15), 0.018, WORLD.AMBER)
	world.placard(observatory, "ALIMENTATION DU SAS NORD", Vector3(0, 2.6, 3.4), Color("c8f4ed"), PI)
	code_station = Marker3D.new()
	world.get_node("Tycho/Controle").add_child(code_station)
	code_station.position = Vector3(-4.5, 1.5, -3.5)
	world.furnishings.screen(code_station, Vector3(0, 0.5, -0.3), 1.5, "SAS NORD\nACCÈS CHIFFRÉ")
	armor_stand = Node3D.new()
	world.add_child(armor_stand)
	armor_stand.position = WORLD.at(2, 27.5, WORLD.UPPER_HEIGHT, 10.5)
	KIT.bevel(armor_stand, Vector3(0, 0.18, 0), Vector3(1.8, 0.36, 1.4), 0.08, WORLD.FRAME, true)
	var suit := preload("res://missions/lunar_escape/astronaut.gd").new()
	armor_stand.add_child(suit)
	suit.position.y = 0.37
	suit.rotation.y = PI
	suit.build()
	suit.set_reinforced(true)
	world.placard(armor_stand, "ARMURERIE · ARMURE EVA", Vector3(0, 2.7, 0), Color("a5e9ed"))
	world.doors["reserve_2"].title = "Armurerie EVA"
	code_window = ConfirmationDialog.new()
	code_window.title = "Tycho · Déchiffrement du sas"
	code_window.dialog_text = access_codes.tycho_hint()
	code_window.process_mode = Node.PROCESS_MODE_ALWAYS
	code_window.dialog_hide_on_ok = false
	code_window.ok_button_text = "Déchiffrer"
	code_window.cancel_button_text = "Annuler"
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 18)
	code_window.add_child(form)
	var instructions := Label.new()
	code_instructions = instructions
	instructions.text = code_window.dialog_text
	instructions.add_theme_color_override("font_color", Color("cce8f2"))
	form.add_child(instructions)
	code_window.dialog_text = ""
	code_entry = LineEdit.new()
	code_entry.placeholder_text = "Code à quatre chiffres"
	code_entry.max_length = 4
	code_entry.custom_minimum_size.y = 40
	form.add_child(code_entry)
	code_window.register_text_enter(code_entry)
	add_child(code_window)
	code_window.confirmed.connect(submit_code)
	code_window.canceled.connect(close_code)


func close_code() -> void:
	code_window.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func submit_code() -> void:
	if not code_window.visible:
		return
	var expected: String = access_codes.copernic if code_context=="copernic" else access_codes.tycho
	if code_entry.text != expected or (code_context=="copernic" and not story.flags.access):
		code_entry.clear()
		code_entry.placeholder_text = "Code incorrect · Réessayez"
		return
	close_code()
	if code_context=="copernic":
		access_codes.copernic_unlocked = true
		enter_control()
		return
	clearance[1] = true
	garage_alarm = true
	for guard in standby_guards:
		if is_instance_valid(guard): guard.process_mode = Node.PROCESS_MODE_INHERIT
	var startup := AudioStreamPlayer3D.new()
	startup.stream = preload("res://audio/hound_charge.wav")
	startup.unit_size = 10.0
	startup.max_distance = 45.0
	add_child(startup)
	startup.global_position = WORLD.at(1, 19.2, 1.0, -12.35)
	startup.finished.connect(startup.queue_free)
	startup.play()
	world.open_door("room_1_1_2")
	update_clearance(1)
	refresh_base_objective(1)

func show_access_code(context: String) -> void:
	code_context = context
	code_window.title = "Copernic · Code d'entrée" if context=="copernic" else "Tycho · Déchiffrement du sas"
	code_instructions.text = ("Code relevé à Tycho : "+access_codes.copernic+"\nSaisissez-le pour déverrouiller le sas.") if context=="copernic" and story.flags.access else access_codes.tycho_hint()
	code_entry.clear(); code_entry.placeholder_text = "Code à quatre chiffres"
	code_window.popup_centered(Vector2i(560,330))
	code_entry.grab_focus()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	speak("ALARME · Code accepté. Limiers réveillés au dépôt. Refermez son sas avec E pour les retenir.", 6.0)


func create_road_guards() -> void:
	for leg in range(2):
		for group in range(ROUTES.PATROLS_PER_LEG):
			var fraction := (group+.5)/ROUTES.PATROLS_PER_LEG
			var point := ROUTES.point(leg, lerpf(ROUTES.start(leg), ROUTES.finish(leg), fraction))
			var director := DIRECTOR.new()
			director.name="PatrouilleRoute_%d_%d"%[leg,group]
			director.navigation_region = Rect2i(int(point.x) - 18, int(point.z) - 18, 37, 37)
			director.flight_height = 3.7
			director.ground_radius = 0.8
			director.projectile_damage=10+leg*3
			director.projectile_speed=18+leg*4
			director.process_mode = Node.PROCESS_MODE_DISABLED
			director.set_meta("leg", leg)
			director.set_meta("site", point)
			add_child(director)
			road_guards.append(director)
			var ground_units := [false,false,true,true] if leg==0 else [false,false,true,true,false]
			for slot in range(ground_units.size()):
				var ground: bool = ground_units[slot]
				var enemy := (HOUND if ground else DRONE).instantiate()
				enemy.campaign_combat = true
				enemy.disable_mode=CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
				var z := point.z+(slot/2-1)*4.0
				enemy.position = ROUTES.point(leg,z)+Vector3(-3.5 if slot%2==0 else 3.5,.05 if ground else 3.7,0)
				enemy.max_health = 5 + leg*3
				enemy.move_speed *= 1.0+leg*.18
				enemy.fire_interval *= 1.0-leg*.15
				enemy.drone_name = "INTERCEPTEUR" if leg == 0 else "PATROUILLE DE SURFACE"
				director.add_child(enemy)
				WORLD.FINISH.apply_tree(enemy)


func stock_rations() -> void:
	for base_z in WORLD.BASE_Z:
		var containers: Array[Node3D] = []
		for handle in get_tree().get_nodes_in_group("ration_furniture"):
			if world.is_ancestor_of(handle) and absf(handle.global_position.z - base_z) < 23.0:
				containers.append(handle)
		if containers.is_empty():
			continue
		var stocked := randi_range(0, containers.size() - 1)
		for i in range(containers.size()):
			var handle := containers[i]
			searchable_furniture[str(handle.get_instance_id())] = {"handle": handle, "ration": i == stocked, "searched": false}


func _physics_process(delta: float) -> void:
	game_time += delta
	if dialogue_until > 0 and game_time >= dialogue_until:
		hud.dialogue.text = ""
		dialogue_until = 0
	if not pilot.in_control:
		return
	if step==Step.TUTORIAL and not arrival_tutorial_hint and pilot.position.z<18.0 and not voice.playing:
		arrival_tutorial_hint = true
		speak(VOICE.LINES.drone,7)
	save_clock += delta
	if saver.enabled and (save_clock>=30.0 or saved_stage!=step):
		if saver.write_save(self):
			saved_stage = step
			save_clock = 0
	var bypassing := using_shortcut()
	for patrol in road_guards:
		var leg: int = patrol.get_meta("leg")
		var distance: float = pilot.position.distance_to(patrol.get_meta("site"))
		var enabled: bool = step >= Step.BIKE and not defeated and distance < 70.0
		if leg == 0 and bypassing:
			enabled = false
		if step == Step.TRANSPORT and leg == 1 and mechanic_rescued and not patrol_warning_given and distance < 92.0:
			patrol_warning_given = true
			speak("LINA · Patrouille devant nous. Préparez le canon et surveillez les deux côtés de la piste.", 7.0)
		patrol.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	var in_cabin: bool = pilot.vehicle != null and pilot.vehicle.get_meta("sealed", false)
	var breathable: bool = in_cabin or world.air_at(pilot.global_position)
	pilot.update_air(delta, breathable)
	hud.set_air(pilot.oxygen, breathable, in_cabin)
	if defeated:
		return
	var upstairs: bool = pilot.position.y >= WORLD.UPPER_HEIGHT - 0.45
	if upstairs != on_upper_floor:
		on_upper_floor = upstairs
		var base := active_base()
		if base >= 0:
			refresh_base_objective(base)
	check_trial_entry()
	if step == Step.HABITAT and selene_power == Power.ONLINE and pilot.position.z > 21.2 and absf(pilot.position.x - 24.5) < 2.35:
		selene_power = Power.OUTAGE
		set_selene_lighting(true)
		play_cue(preload("res://audio/hound_charge.wav"), 0.7)
		speak("SECOURS · Alimentation coupée. Redémarrez le réseau depuis l’observatoire.", 5.5)
		refresh_base_objective(0)
	if step == Step.HABITAT and pilot.position.z < -25.75 and absf(pilot.position.x) < 3.0 and pilot.position.y < 2:
		enter_surface()
	if step == Step.CONTROL and world.doors["launch_exit"].is_open and world.doors["roof_inner_outer"].is_open and pilot.position.y >= WORLD.ROOF_HEIGHT-0.3 and pilot.global_position.distance_to(WORLD.at(2,22,WORLD.ROOF_HEIGHT,-9))<2.5:
		ship_reveal()
		return
	update_interface()
	if Input.is_action_just_pressed("interact") and not interaction.is_empty():
		interact(interaction)


func check_trial_entry() -> void:
	var base := active_base()
	if base < 0 or pilot.vehicle != null:
		return
	var point: Vector3 = pilot.global_position
	var plan := Vector2(point.x, point.z - WORLD.BASE_Z[base])
	var key := ""
	if absf(point.y - WORLD.UPPER_HEIGHT) < 0.75:
		if Rect2(12.25, -16.25, 22.15, 18.0).has_point(plan) and (base == 0 or world.doors["ground_%d" % base].is_open):
			key = "upper_%d" % base
	elif base > 0 and absf(point.y) < 0.85:
		if Rect2(-13.35, 8.15, 26.7, 9.40).has_point(plan):
			key = "ground_%d" % base
	if not key.is_empty() and not trials[key].started:
		begin_trial(key)


func _unhandled_key_input(event: InputEvent) -> void:
	if not pilot.in_control or pilot.building or pilot.vehicle != null or not event.is_pressed() or event.is_echo():
		return
	var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	match key:
		KEY_1, KEY_KP_1: pilot.equip("pistol")
		KEY_2, KEY_KP_2: pilot.equip("shotgun")
		KEY_3, KEY_KP_3: pilot.equip("smg")


func update_interface() -> void:
	var gun: Dictionary = pilot.WEAPONS[pilot.equipped]
	var reload_state := ""
	if pilot.weapon.is_reloading:
		reload_state = "  ·  Rechargement %d %%" % roundi((1.0 - pilot.weapon.reload_remaining / pilot.weapon.reload_duration) * 100)
	elif pilot.weapon.reserve_ammo == 0:
		reload_state = "  ·  Réserve vide"
	elif pilot.weapon.ammo == 0:
		reload_state = "  ·  R pour recharger"
	var gun_name: String=gun.name+(" Mk II · dégâts ×2" if pilot.weapon.damage_per_hit>1 else "")
	hud.inventory.text = "%s     %02d / %02d%s" % [gun_name, pilot.weapon.ammo, pilot.weapon.reserve_ammo, reload_state]
	if pilot.loadout.active and pilot.loadout.right in ["sabre","lance"]:
		hud.inventory.text=pilot.loadout.NAMES[pilot.loadout.right]+" · Corps à corps"
	hud.reticle.visible = true
	if pilot.vehicle != null:
		hud.inventory.text = "%s     %02d km/h" % [String(pilot.vehicle.get_meta("display_name")).to_upper(), roundi(absf(pilot.vehicle_speed) * 3.6)]
		if pilot.vehicle == world.bike:
			hud.inventory.text += "   ·   Boost %d %% [Maj]" % roundi(pilot.bike_boost * 100.0)
	var shield_equipped: bool = pilot.shield_unlocked and (not pilot.loadout.active or pilot.loadout.left=="shield")
	var shield := "     ·     Bouclier %d %% [F]" % roundi(pilot.shield_charge) if shield_equipped else ""
	hud.status.text = shield.strip_edges().trim_prefix("·").strip_edges() if shield_equipped else ""
	hud.status.visible = shield_equipped
	hud.modules.text = "Tab · Carte"
	if pilot.loadout.unlocked: hud.modules.text += "   |   I · Inventaire / deux mains"
	if not pilot.upgrades.is_empty(): hud.modules.text += "   |   "+" · ".join(pilot.upgrades)
	if story.flags.crew: hud.modules.text += "   |   Journal Karen ✓"
	hud.modules.text += "   |   J · Construire"
	hud.modules.text += "   |   Y · Rations %d   |   Blocs %d"%[get_node("CabinetLoot").food,get_node("Construction").stock]
	hud.optional_objective.text = optional_objective()
	var objective_marker := marker_target()
	hud.set_marker(camera, objective_marker[0], objective_marker[1], pilot.position.distance_to(objective_marker[0]))
	interaction = nearest_interaction()
	hud.hint.text = interaction_text(interaction)
	if step == Step.BATTLE:
		hud.set_boss_health(mothership.health, mothership.max_health)
		hud.boss_label.text = mothership.tactical_status()


func marker_target() -> Array:
	match step:
		Step.TUTORIAL:
			return [tutorial_drone.global_position + Vector3.UP * 1.45, "Drone du couloir"]
		Step.HABITAT:
			return base_marker(0)
		Step.BIKE:
			if pilot.vehicle == null and pilot.position.distance_to(world.bike.position) < 20.0:
				return [world.bike.position + Vector3.UP * 1.65, "Moto / éclaireur S-01"]
			return route_marker(0, "Atelier Tycho")
		Step.WORKSHOP:
			return base_marker(1)
		Step.TRANSPORT:
			if pilot.vehicle == null and pilot.position.distance_to(world.transport.position) < 18.0:
				return [world.transport.position + Vector3.UP * 2.7, "Blindé"]
			return route_marker(1, "Copernic")
		Step.CONTROL:
			if world.doors.launch_exit.is_open:
				return [WORLD.at(2,22,WORLD.ROOF_HEIGHT,-10) if pilot.position.y>WORLD.ROOF_HEIGHT-1 else (WORLD.ROOF_STAIRS_BOTTOM if pilot.position.z<WORLD.COPERNIC_Z-45 else WORLD.at(2,0,0,-46)),"Tour intérieure · Sas vers la fusée"]
			return base_marker(2)
		Step.BATTLE:
			if story.link.health==0: return [story.link.global_position+Vector3.UP*2.2,"Réparer la liaison · E"]
			if mothership.core.visible:
				return [mothership.core.global_position, "Réacteur"]
			return [mothership.global_position + Vector3.UP * 2.1, "Vaisseau"]
		Step.BOARD:
			if not story.ready_to_launch(): return [story.link.global_position+Vector3.UP*2.2,"Liaison de lancement"]
			return [WORLD.pad(0, 4.7, -246.3), "Fusée"]
	return [Vector3.ZERO, ""]


func route_marker(leg: int, destination: String) -> Array:
	var z: float = pilot.global_position.z
	if leg == 0 and using_shortcut():
		var start := ROUTES.shortcut_start()
		var finish := ROUTES.shortcut_end()
		var ahead := maxf(finish.z, z - 13.0)
		return [start.lerp(finish, inverse_lerp(start.z, finish.z, ahead)) + Vector3.UP * 1.5, "Passage moto · Tycho"]
	if z <= ROUTES.finish(leg) + 23.0:
		return [WORLD.at(leg + 1, 0, 3.5, 19.4), destination]
	var next_z := clampf(z - 18.0, ROUTES.finish(leg), ROUTES.start(leg))
	if absf(pilot.global_position.x - ROUTES.x_at(leg, z)) > 14.0:
		next_z = clampf(z - 8.0, ROUTES.finish(leg), ROUTES.start(leg))
	return [ROUTES.point(leg, next_z) + Vector3.UP * 2.0, "Piste · " + destination]


func using_shortcut() -> bool:
	var point: Vector3 = pilot.global_position
	return step == Step.BIKE and pilot.vehicle == world.bike and ROUTES.shortcut_distance(Vector2(point.x, point.z)) < 4.2 and ROUTES.distance_from_road(0, point.x, point.z) > 9.0


func optional_objective() -> String:
	match step:
		Step.BIKE:
			if not story.flags.wreck and pilot.position.distance_to(ROUTES.wreck_turnoff())<65: return "Détour · Balises orange : épave du Courrier 04."
			if pilot.vehicle == world.bike and pilot.position.z > ROUTES.shortcut_end().z:
				return "Raccourci à moto · Repérez les balises vertes."
		Step.WORKSHOP:
			if mechanic_rescued: return "Restez groupés : escortez les survivants jusqu'au hangar nord."
		Step.TRANSPORT:
			if not service_used and pilot.position.distance_to(ROUTES.service_turnoff()) < 55.0:
				return "Facultatif · Ravitaillement sur la gauche. Arrêtez le blindé sur la dalle."
		Step.CONTROL:
			if clearance[2] and not message_heard:
				return "Facultatif · Écouter le dernier message à l’observatoire, au sud de l’aile ouest."
	return ""


func base_marker(base: int) -> Array:
	if not story.exit_ready(base) and (base==0 or world.doors["ground_%d"%base].is_open): return story.marker(base)
	if base == 0 and clearance[0] and pilot.position.z > 8.0 and pilot.position.x < -14.0:
		return door_marker("dome_0_-1" if pilot.position.z > 19.0 else "room_0_0_0")
	if base == 0 and not clearance[0]:
		var east := selene_power == Power.ONLINE
		var point: Vector3 = pilot.global_position
		if point.z > 19.0:
			if east or point.x < -14.0:
				return [breaker.global_position, "Commande de secours"] if not east else [Vector3(24.5, 1.5, 32), "Serre"]
			return door_marker("dome_0_1")
		if point.z < 8.0 and absf(point.x) < 14.0:
			return door_marker("tutorial")
		if point.x > 14.0:
			return door_marker("dome_0_1" if east else "room_0_1_0")
		if point.x < -14.0:
			return door_marker("room_0_0_0" if east else "dome_0_-1")
		return door_marker("room_0_1_0" if east else "room_0_0_0")
	var gate := "ground_%d" % base
	if base > 0 and not world.doors[gate].is_open:
		return door_marker(gate)
	if not clearance[base] and base == 1:
		if on_upper_floor or pilot.position.x > 34.9:
			return door_marker("stair_down_1" if pilot.position.x > 34.9 else "stair_up_1")
		if not world.doors["room_1_1_0"].is_open:
			return door_marker("room_1_1_0")
		return [code_station.global_position, "Ordinateur · Déchiffrer le sas"]
	if not clearance[base] and base == 2 and on_upper_floor:
		return [armor_stand.global_position + Vector3.UP * 1.8, "Enfiler l’armure EVA" if armor_taken else "Armurerie EVA"] if world.doors["reserve_2"].is_open else door_marker("reserve_2")
	var upstairs := "upper_%d" % base
	if not clearance[base]:
		if pilot.position.x > 34.9:
			return door_marker("stair_up_%d" % base)
		if on_upper_floor:
			return [world.relays[base].global_position + Vector3.UP * 1.4, "Console du sas nord"] if world.doors[upstairs].is_open else door_marker(upstairs)
		if pilot.position.x < 13.7:
			return door_marker("room_%d_1_1" % base)
		return door_marker("stair_down_%d" % base)
	if pilot.position.x > 34.9:
		return door_marker("stair_down_%d" % base)
	if on_upper_floor:
		if pilot.position.x < 11.0:
			return door_marker(upstairs)
		return door_marker("stair_up_%d" % base)
	if pilot.position.x > 14.5 and absf(pilot.position.z - WORLD.BASE_Z[base]) < 6.2:
		return door_marker("room_%d_1_1" % base)
	var north := "north_%d" % base
	var behind_divider: bool = not world.doors[north].is_open and pilot.position.z > world.doors[north].global_position.z + 0.5
	for id in required_equipment(base):
		if supplies.has(id):
			if behind_divider and supplies[id].node.global_position.z < world.doors[north].global_position.z:
				return door_marker(north)
			return [supplies[id].node.global_position + Vector3.UP * 1.3, supplies[id].title]
	if behind_divider:
		return door_marker(north)
	if base == 1 and world.doors["garage"].is_open:
		return [world.transport.global_position + Vector3.UP * 2.7, "Blindé"]
	return door_marker(exit_key(base))


func door_marker(key: String) -> Array:
	var door: Node3D = world.doors[key]
	return [door.global_position + Vector3.UP * 2.1, door.title]


func active_base() -> int:
	match step:
		Step.HABITAT: return 0
		Step.WORKSHOP: return 1
		Step.CONTROL: return 2
	return -1


func exit_key(base: int) -> String:
	return ["habitat_exit", "garage", "launch_exit"][base]


func required_equipment(base: int) -> Array:
	return [[], ["shotgun"], ["smg", "shield"]][base]


func refresh_base_objective(base: int) -> void:
	if active_base() != base:
		return
	var task := ""
	var ground := "ground_%d" % base
	var upstairs := "upper_%d" % base
	if base > 0 and not world.doors[ground].is_open:
		task = trial_objective(ground, "Ouvrez le sas du rez-de-chaussée.")
	elif not story.exit_ready(base):
		task = story.objective(base)
	elif not clearance[base]:
		var approach := "Entrez dans la salle des transmissions." if on_upper_floor else "Rejoignez l’étage par l’escalier de l’aile est."
		task = trial_objective(upstairs, approach)
		if world.doors[upstairs].is_open:
			task = "Activez la console des transmissions pour déverrouiller le sas nord."
		if base == 0:
			task = "Traversez le tunnel vers la serre pour vérifier l’alimentation du sas." if selene_power == Power.ONLINE else "Rejoignez l’observatoire par les quartiers ouest et rétablissez le courant."
		elif base == 1:
			task = "Déchiffrez le code sur l’ordinateur de la salle de contrôle au rez-de-chaussée."
		elif base == 2:
			task = "Enfilez l’armure EVA avec E." if armor_taken else "Récupérez l’armure dans l’armurerie de l’étage."
	else:
		task = "Redescendez et ouvrez le sas nord."
		for id in required_equipment(base):
			if supplies.has(id):
				task = "Redescendez et récupérez " + ("le bouclier." if id == "shield" else "le " + supplies[id].title.to_lower() + ".")
				break
		if world.doors[exit_key(base)].is_open:
			task = ["Sortez de Karen.", "Rejoignez le blindé.", "Sortez et montez l'escalier extérieur vers la fusée sur le toit."][base]
	set_objective(WORLD.BASE_NAMES[base], task)


func trial_objective(key: String, approach: String) -> String:
	var trial: Dictionary = trials[key]
	if not trial.started:
		return approach
	if trial.left > 0:
		return "Sécurisez la zone · %d hostile(s) restant(s)." % trial.left
	return "Zone sécurisée. Ouvrez le sas avec E."


func update_clearance(base: int) -> void:
	if is_instance_valid(story) and not story.exit_ready(base):
		world.doors[exit_key(base)].lock()
		return
	if not clearance[base]:
		return
	for id in required_equipment(base):
		if supplies.has(id):
			return
	world.doors[exit_key(base)].unlock()


func nearest_interaction() -> String:
	var point: Vector3 = pilot.global_position
	for leg in range(2):
		for index in range(ROUTES.AIR_STOPS.size()):
			if pilot.oxygen<99.5 and point.distance_to(ROUTES.air_stop(leg,index))<4.0:
				return "road_air"
	if step == Step.BIKE and point.distance_to(WORLD.at(1, 0, 0, 26.8)) < 4.0:
		return "workshop_entry"
	if step == Step.TRANSPORT and point.distance_to(WORLD.at(2, 0, 0, 26.6)) < 4.5:
		return "control_entry"
	if step == Step.TRANSPORT and pilot.vehicle == world.transport and not service_used and point.distance_to(ROUTES.service_point()) < 4.1:
		return "service_stop"
	if pilot.vehicle != null:
		return "dismount"
	for lock in world.airlocks:
		if lock.contains(point):
			var selected: Node3D = lock.inner if lock.inner.is_open else (lock.outer if lock.outer.is_open else (lock.inner if lock.pressure>0.95 else lock.outer))
			return "door:"+String(world.doors.find_key(selected))
	if step != Step.TUTORIAL and can_reach_vehicle(world.bike, 2.4):
		return "bike"
	if step >= Step.BIKE and can_reach_vehicle(world.scout, 3.7):
		return "scout"
	if not world.doors["garage"].secured and can_reach_vehicle(world.transport, 3.7):
		return "transport"
	if step == Step.BOARD and point.distance_to(WORLD.pad(0, 0.8, -244.8)) < 3.3:
		return "rocket"
	var base := active_base()
	var story_action: String = story.nearest()
	if equipment_room.in_reach(): return "equipment_room"
	if not story_action.is_empty(): return story_action
	var cupboard: String=get_node("CabinetLoot").nearest()
	if not cupboard.is_empty(): return cupboard
	if base == 1 and story.flags.power and not mechanic_rescued and not rescue_guard.alive and task_in_reach(mechanic.global_position + Vector3.UP * 1.35, 2.3):
		return "rescue_mechanic"
	if base == 2 and not message_heard and task_in_reach(lookout.global_position, 2.1):
		return "lookout"
	if base == 1 and not clearance[1] and task_in_reach(code_station.global_position, 2.3):
		return "code"
	if base == 2 and not armor_worn and (armor_taken or task_in_reach(armor_stand.global_position + Vector3.UP * 1.4, 2.2)):
		return "armor"
	if base == 0 and selene_power == Power.OUTAGE and task_in_reach(breaker.global_position, 2.1):
		return "breaker"
	var annex: String = base_life.nearest()
	if not annex.is_empty(): return annex
	var door_id := nearest_door(point)
	if not door_id.is_empty():
		return "door:" + door_id
	var best_distance := 2.25
	var result := ""
	for id in supplies:
		if id == "pistol":
			continue
		var supply: Dictionary = supplies[id]
		var distance: float = point.distance_to(supply.node.position)
		if distance < best_distance:
			if supply.on_rack:
				var sight := PhysicsRayQueryParameters3D.create(pilot.get_aim_point(), supply.node.global_position, 1)
				if not get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
					continue
			best_distance = distance
			result = id
	return result if not result.is_empty() else reachable_furniture()


func task_in_reach(point: Vector3, reach: float) -> bool:
	if pilot.head.global_position.distance_to(point) > reach:
		return false
	var ray := PhysicsRayQueryParameters3D.create(pilot.head.global_position, point, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func reachable_furniture() -> String:
	var from: Vector3 = pilot.head.global_position
	var space := get_world_3d().direct_space_state
	var best := 1.75
	var result := ""
	for id in searchable_furniture:
		var record: Dictionary = searchable_furniture[id]
		if record.searched and not record.ration:
			continue
		var handle: Node3D = record.handle
		var offset := from - handle.global_position
		var distance := offset.length()
		if distance >= best or offset.dot(handle.global_basis.z) < 0.06:
			continue
		var ray := PhysicsRayQueryParameters3D.create(from, handle.global_position, 1)
		if space.intersect_ray(ray).is_empty():
			best = distance
			result = "furniture:" + id
	return result


func can_reach_vehicle(ride: Node3D, reach: float) -> bool:
	var point: Vector3 = pilot.global_position
	if point.distance_to(ride.global_position) >= reach:
		return false
	var sight := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.9,
		ride.global_position + Vector3.UP * 0.83, 1, [pilot.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(sight)
	return hit.is_empty() or hit.collider == ride.get_node("ParkedCollision")


func nearest_door(point: Vector3) -> String:
	var best := 3.35
	var result := ""
	for key in world.doors:
		var door: Node3D = world.doors[key]
		var local := door.to_local(point)
		if (door.is_open and door.airlock==null and not (garage_alarm and key == "room_1_1_2")) or door.opening or absf(local.y) > 0.9 or absf(local.x) > door.width * 0.5 + 0.35:
			continue
		var distance := Vector2(local.x * 0.25, local.z).length()
		if door.airlock==null and distance>2.35: continue
		if distance < best:
			best = distance
			result = key
	return result


func interaction_text(id: String) -> String:
	if id.begins_with("cabinet:"): return get_node("CabinetLoot").hint(id.substr(8))
	if id=="road_air": return "E   Recharger la combinaison · O₂ 100 %"
	if id=="equipment_room": return "E   Armurerie · Choisir les deux mains et l'armure"
	if id.begins_with("story:"): return story.hint(id.substr(6))
	if id.begins_with("annex:"): return base_life.hint(id)
	if id.begins_with("furniture:"):
		var record: Dictionary = searchable_furniture[id.substr(10)]
		return "E   Manger · Ration" if record.searched else "E   Fouiller · " + String(record.handle.get_meta("description"))
	if id.begins_with("door:"):
		var key := id.substr(5)
		var door: Node3D = world.doors[key]
		if door.airlock!=null: return door.airlock.hint(door)
		if key.begins_with("shortcut_") and door.secured:
			return "E   Déverrouiller le raccourci" if pilot.global_position.z<door.global_position.z-0.5 else "Raccourci · Verrou de l'autre côté"
		if door.is_open:
			return "E   Refermer · Sas du dépôt"
		if trials.has(key) and door.secured:
			var trial: Dictionary = trials[key]
			return "%d hostile(s) restant(s) · Sas verrouillé" % trial.left if trial.started else "L’épreuve commence dans la salle"
		return "Sas verrouillé · " + door.title if door.secured else "E   Ouvrir · " + door.title
	match id:
		"rescue_mechanic":
			return "E   Secourir Lina"
		"service_stop":
			return "E   Ravitaillement · Ralentissez" if absf(pilot.vehicle_speed) > 2.0 else "E   Prendre les réserves"
		"lookout":
			return "E   Regarder et écouter le dernier message"
		"breaker":
			return "E   Rétablir l’alimentation"
		"code":
			return "E   Déchiffrer le code du sas"
		"armor":
			return "E   Enfiler l’armure EVA" if armor_taken else "E   Récupérer l’armure EVA"
		"bike":
			return "E   Monter sur la moto"
		"scout":
			return "E   Embarquer dans l’éclaireur S-01"
		"dismount":
			return "Souris : viser · Clic : canon · Z / W : accélérer · Q / D : tourner · S : freiner · E : descendre"
		"workshop_entry":
			return "E   Ouvrir le sas de Tycho"
		"control_entry":
			return "E   Saisir le code de Copernic" if not access_codes.copernic_unlocked else "E   Ouvrir le sas de Copernic"
		"relay":
			return "E   Autoriser l’ouverture du sas nord"
		"transport":
			return "E   Embarquer dans le blindé"
		"rocket":
			return "E   Monter dans la fusée"
		"":
			return ""
	return "E   Prendre · " + supplies[id].title


func interact(id: String) -> void:
	if id.begins_with("cabinet:"):
		get_node("CabinetLoot").interact(id.substr(8));return
	if id=="road_air":
		if absf(pilot.vehicle_speed)>2:
			speak("Arrêtez-vous près de la borne pour recharger la combinaison.",2.5)
		else:
			pilot.oxygen=100.0
			play_cue(PICKUP_SOUND)
			speak("COMBINAISON · Réserve d'oxygène rechargée.",2.5)
		return
	if id=="equipment_room": equipment_room.open();return
	if id.begins_with("story:"):
		story.interact(id.substr(6))
		return
	if id.begins_with("annex:"):
		base_life.interact(id)
		return
	if id == "rescue_mechanic":
		story.rescue()
		return
	if id == "service_stop":
		if absf(pilot.vehicle_speed) > 2.0:
			speak("Ralentissez pour accéder aux réserves.", 2.0)
			return
		service_used = true
		pilot.restore_health()
		pilot.oxygen = 100.0
		pilot.add_ammo("pistol", 24)
		pilot.add_ammo("shotgun", 12)
		play_cue(PICKUP_SOUND)
		speak("RÉSERVES · Santé et oxygène restaurés. Munitions récupérées.", 4.0)
		return
	if id == "lookout":
		play_last_message()
		return
	if id == "code":
		show_access_code("tycho")
		return
	if id == "armor":
		if not armor_taken:
			armor_taken = true
			for part in armor_stand.get_children().slice(1):
				if part is Node3D:
					part.hide()
			speak("Armure récupérée · Appuyez sur E pour l’enfiler.", 3.0)
		elif not armor_worn:
			armor_worn = true
			pilot.avatar.set_reinforced(true)
			pilot.max_health = 125
			pilot.health = mini(pilot.health + 25, pilot.max_health)
			clearance[2] = true
			update_clearance(2)
			speak("Armure équipée · Santé maximale 125 · Identification EVA validée.", 4.0)
		refresh_base_objective(2)
		return
	if id.begins_with("furniture:"):
		search_furniture(id.substr(10))
		return
	if id.begins_with("door:"):
		use_door(id.substr(5))
		return
	match id:
		"bike":
			board_vehicle(world.bike)
		"scout":
			board_vehicle(world.scout)
		"dismount":
			if absf(pilot.vehicle_speed) > 3.0:
				speak("Ralentissez pour descendre.", 1.8)
			elif not pilot.dismount():
				speak("Aucun passage libre à côté du véhicule.", 2.4)
		"workshop_entry":
			enter_workshop()
		"control_entry":
			enter_control()
		"transport":
			board_vehicle(world.transport)
		"breaker":
			selene_power = Power.RESTORED
			set_selene_lighting(false)
			clearance[0] = true
			update_clearance(0)
			play_cue(PICKUP_SOUND)
			speak("OBSERVATOIRE · Réseau rétabli. Sas nord déverrouillé. La moto vous attend dehors.", 5.5)
			refresh_base_objective(0)
		"rocket":
			launch()
		_:
			take_supply(id)


func search_furniture(id: String) -> void:
	var record: Dictionary = searchable_furniture[id]
	record.searched = true
	if not record.ration:
		speak("Le meuble est vide.", 2.0)
		return
	var recovered: int = pilot.eat_ration()
	if recovered == 0:
		speak("Ration trouvée. Elle reste ici pour quand vous en aurez besoin.", 3.0)
		return
	record.ration = false
	play_cue(PICKUP_SOUND)
	speak("Ration consommée · +%d santé" % recovered, 2.6)


func use_door(key: String) -> void:
	var door: Node3D = world.doors[key]
	if door.airlock!=null:
		if not await door.airlock.operate(door): speak("Dégagez le seuil avant de refermer le sas." if door.is_open and pilot.oxygen>=95 else door.airlock.hint(door),2.5)
		return
	if key.begins_with("shortcut_") and pilot.global_position.z<door.global_position.z-0.5:
		door.unlock()
	if key == "room_1_1_2" and garage_alarm and door.is_open:
		if await door.close():
			door.set_meta("closed_by_player",true)
			rebuild_navigation(door.global_position)
		else:
			speak("SAS · Dégagez le passage pour refermer.", 2.0)
		return
	if key in ["habitat_exit", "garage", "launch_exit"] and pilot.oxygen < 95.0:
		speak("Rechargez la combinaison à l’intérieur avant de sortir · O₂ %d %%" % ceili(pilot.oxygen), 3.0)
		return
	if door.secured:
		speak("SÉCURITÉ · Accès verrouillé.", 2.0)
		return
	door.set_meta("closed_by_player",false)
	if await door.open():
		var base := active_base()
		if base >= 0:
			refresh_base_objective(base)


func take_supply(id: String) -> void:
	var supply: Dictionary = supplies[id]
	supply.node.queue_free()
	supplies.erase(id)
	play_cue(PICKUP_SOUND)
	match supply.kind:
		"ammo":
			pilot.add_ammo("pistol", 24)
			speak("Munitions de pistolet récupérées · +24", 2.4)
		"ammo_all":
			pilot.add_ammo("pistol", 24)
			pilot.add_ammo("shotgun", 18)
			pilot.add_ammo("smg", 112)
			speak("Munitions récupérées", 2.4)
		"shield":
			pilot.shield_unlocked = true
			pilot.shield_charge = 100
			speak("Maintenez F pour absorber une partie des impacts.", 4.0)
		_:
			if supply.on_rack and pilot.inventory.has(supply.kind):
				var rounds := 12 if supply.kind == "shotgun" else 24
				pilot.add_ammo(supply.kind, rounds)
				speak("Réserve récupérée · +%d" % rounds, 2.4)
			else:
				pilot.unlock_weapon(supply.kind)
	if id == "shotgun":
		update_clearance(1)
		refresh_base_objective(1)
	if id in ["smg", "shield"]:
		update_clearance(2)
		refresh_base_objective(2)


func on_primary() -> void:
	if step == Step.BRIEFING:
		intro()
	elif step == Step.COMPLETE:
		restart()
	elif defeated:
		respawn()
	else:
		toggle_pause()


func intro() -> void:
	saver.clear()
	step = Step.INTRO
	hud.has_started = true
	hud.title_card.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	speak(VOICE.LINES.arrival,7)
	# The next briefing must not cut the end of the recorded arrival sentence.
	var landing_duration := maxf(6.6, voice.stream.get_length()+0.25 if voice.stream != null else 6.6)
	story.arrival_ship.position.y = 25
	story.arrival_flame.show()
	var landing := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	landing.tween_property(story.arrival_ship,"position:y",0.0,landing_duration)
	frame_camera(Vector3(18,12,58),Vector3(0,12,46))
	await move_camera(Vector3(11,5,56),Vector3(0,4,42),landing_duration)
	story.arrival_flame.hide()
	take_supply("pistol")
	checkpoint = Vector3(0,0.08,28)
	checkpoint_heading = 0
	place_pilot(checkpoint, checkpoint_heading)
	world.doors["habitat_entry"].unlock()
	directors[0].process_mode = Node.PROCESS_MODE_INHERIT
	step = Step.TUTORIAL
	set_objective("MISSION KAREN / RECHERCHE ET SECOURS", "Entrez dans la base silencieuse. Retrouvez les survivants et le journal de bord.")
	end_film()
	speak(VOICE.LINES.mission,7)


func on_tutorial_drone_destroyed(_enemy: CharacterBody3D) -> void:
	if step != Step.TUTORIAL:
		return
	step = Step.HABITAT
	world.open_door("tutorial")
	checkpoint = Vector3(-2.6, 0.045, 13.2)
	checkpoint_heading = 0
	refresh_base_objective(0)
	speak(VOICE.LINES.search,7)


func set_selene_lighting(emergency: bool) -> void:
	selene_lighting.set_outage(world,emergency)


func enter_surface() -> void:
	step = Step.BIKE
	checkpoint = Vector3(-2.0, 0.045, -28.3)
	checkpoint_heading = 0
	set_objective("SURFACE LUNAIRE", "Suivez les balises bleues. En moto, utilisez le boost [Maj] pour semer les drones.")
	speak("COMBINAISON · Air autonome dehors. Les cabines des blindés rechargent votre réserve.", 5.3)


func enter_workshop() -> void:
	if not await open_entrance("workshop_entry"):
		return
	step = Step.WORKSHOP
	checkpoint = WORLD.at(1, 0, 0.045, 17.2)
	checkpoint_heading = 0
	pilot.spawn_transform = Transform3D(Basis.IDENTITY, checkpoint)
	directors[0].process_mode = Node.PROCESS_MODE_DISABLED
	upper_directors[0].process_mode = Node.PROCESS_MODE_DISABLED
	directors[1].process_mode = Node.PROCESS_MODE_INHERIT
	refresh_base_objective(1)
	speak(VOICE.LINES.lina,8)


func open_entrance(key: String) -> bool:
	if transition:
		return false
	if not pilot.dismount():
		speak("Il faut un passage libre à côté du véhicule pour descendre.", 2.8)
		return false
	transition = true
	var door: Node3D = world.doors[key]
	door.unlock()
	var opened: bool = await door.airlock.operate(door.airlock.outer) if door.airlock!=null else await door.open()
	transition = false
	return opened


func board_vehicle(ride: Node3D) -> void:
	if squad.difficulty_active and not squad.can_board():
		speak("Attendez vos compagnons près du véhicule. Toute l'équipe doit embarquer.",4)
		return
	if ride==world.transport and step==Step.WORKSHOP and not story.exit_ready(1):
		speak("BLINDÉ · Lina doit préparer le véhicule. Rétablissez le courant et secourez-la.",4)
		return
	if transition:
		return
	transition = true
	var armored: bool = ride.get_meta("sealed", false)
	var eye: Vector3 = ride.to_global(ride.get_meta("eye_position"))
	var forward := -ride.global_basis.z
	var side := -1.0 if ride.to_local(pilot.global_position).x < 0.0 else 1.0
	var hatch := 0 if side < 0.0 else 1
	pilot.set_control(false)
	pilot.weapon.hide()
	frame_camera(camera.global_position, camera.global_position - camera.global_basis.z * 4.0)
	film.make_current()
	hud.reticle.hide()
	hud.hint.text = ""
	hud.set_marker(camera, Vector3.ZERO, "", 0.0)
	if armored:
		world.animate_hatch(ride, hatch, true)
		play_cue(DOOR_SOUND, 0.90)
		var sill := ride.to_global(Vector3(side * 2.64, 1.80, -0.89))
		await move_camera(sill, ride.to_global(Vector3(side * 1.48, 1.76, -0.89)), 0.32)
		var handrail := ride.to_global(Vector3(side * 2.03, 2.92, -1.29))
		await move_camera(handrail, handrail + forward * 4.5 - Vector3.UP * 0.62, 0.22)
	else:
		var saddle := ride.to_global(Vector3(side * 0.75, 1.28, 0.30))
		await move_camera(saddle, ride.to_global(Vector3(0, 1.18, -0.69)), 0.29)
	await move_camera(eye, eye + forward * 5.0 - Vector3.UP * 0.35, 0.29 if armored else 0.38)
	if armored:
		world.animate_hatch(ride, hatch, false)
	if defeated:
		camera.make_current()
		transition = false
		return
	pilot.mount(ride)
	camera.make_current()
	pilot.set_control(true)
	transition = false
	if ride == world.transport and step == Step.WORKSHOP:
		start_transport()


func start_transport() -> void:
	step = Step.TRANSPORT
	checkpoint = WORLD.at(1, 2.5, 0.045, -23.8)
	checkpoint_heading = 0
	set_objective("SURFACE LUNAIRE", "Suivez les balises orange. Tournez la tête vers les patrouilles et ripostez au canon du blindé.")
	speak("LINA · Tout le monde est à bord. Copernic dispose d'une capsule à quatre places. On rentrera ensemble.", 5.0)
	directors[1].process_mode = Node.PROCESS_MODE_DISABLED
	upper_directors[1].process_mode = Node.PROCESS_MODE_DISABLED


func enter_control() -> void:
	if not access_codes.copernic_unlocked:
		if not story.flags.access:
			speak("SAS COPERNIC · Code requis. Retrouvez la tablette de maintenance dans la deuxième chambre de Tycho.",6)
			return
		show_access_code("copernic")
		return
	if not await open_entrance("control_entry"):
		return
	checkpoint = WORLD.at(2, 0, 0.045, 17.0)
	checkpoint_heading = 0
	pilot.spawn_transform = Transform3D(Basis.IDENTITY, checkpoint)
	pilot.restore_health()
	directors[2].process_mode = Node.PROCESS_MODE_INHERIT
	for spider in resident_spiders:
		if is_instance_valid(spider): spider.process_mode = Node.PROCESS_MODE_INHERIT
	step = Step.CONTROL
	refresh_base_objective(2)
	speak("RADIO · Regardez les murs et le plafond. Les robots de réparation bougent encore.", 5.1)


func play_last_message() -> void:
	message_heard = true
	transition = true
	begin_film(WORLD.at(2, -25, 24, 8), WORLD.pad(18, 25, -260))
	speak("ÉQUIPAGE · La fusée est prête. Rentrez sur Terre. Dites-leur ce qui s’est passé ici.", 6.0)
	await move_camera(WORLD.at(2, -20, 21, -10), WORLD.pad(16, 24, -260), 6.0)
	play_cue(preload("res://audio/hound_charge.wav"), 0.72)
	speak("ALARME · Signal inconnu à proximité de l’aire de lancement.", 3.5)
	end_film()
	transition = false


func prepare_final_encounter() -> void:
	if is_instance_valid(mothership): return
	mothership=MOTHERSHIP.new();mothership.pilot=pilot
	mothership.position=WORLD.pad(-24,5.2,-232)
	mothership.patrol_center=WORLD.pad(0,5.2,-232)
	mothership.destroyed.connect(on_ship_destroyed)
	mothership.phase_changed.connect(on_ship_phase_changed)
	add_child(mothership)
	mothership.spawn_defenders(6)
	squad.update_enemies()

func ship_reveal() -> void:
	step = Step.REVEAL
	pilot.dismount(false)
	checkpoint = WORLD.pad(0, 0.045, -216)
	checkpoint_heading = 0
	begin_film(WORLD.pad(5,1.5,-215),WORLD.pad(0,10,-249))
	speak("RADIO · Vous voyez la fusée ? Le réservoir est plein. Départ autorisé.", 3.0)
	prepare_final_encounter()
	squad.update_enemies()
	play_cue(preload("res://audio/boss_crash.wav"),0.55)
	await move_camera(WORLD.pad(14,2.8,-222),mothership.global_position,2.2)
	speak("RADIO · Un quadrupède de siège garde la fusée ! Ses drones sont déjà en position !",4.0)
	var approach := create_tween()
	approach.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	approach.tween_property(mothership, "position", WORLD.pad(0, 5.2, -230), 4.8)
	approach.tween_method(func(weight: float):
		frame_camera(WORLD.pad(14,2.8,-222).lerp(WORLD.pad(9,1.65,-214),weight),mothership.position)
		mothership.walker.update_pose(mothership,1.0/60.0)
	, 0.0, 1.0, 4.8)
	await approach.finished
	world.set_pad_lock(true)
	place_pilot(checkpoint, checkpoint_heading)
	pilot.restore_health()
	pilot.oxygen = 100.0
	pilot.asphyxia_timer = 0.0
	step = Step.BATTLE
	hud.boss_label.text = "QUADRUPÈDE DE SIÈGE   /   PHASE 1"
	mothership.activate()
	set_objective("AIRE DE LANCEMENT", "Esquivez les attaques, puis visez le réacteur bleu quand il s’expose.")
	end_film()
	story.begin_defense()


func on_ship_phase_changed(phase: int) -> void:
	var message := "RADIO · Il bombarde le sol. Sortez des cercles orange !" if phase == 1 else \
		"RADIO · Surcharge ! Sautez par-dessus l’onde au sol."
	if mothership.reinforcement_delay >= 0.0:
		message += " Renforts en approche des deux côtés du toit !"
	speak(message, 5.2)


func on_ship_destroyed() -> void:
	if is_instance_valid(mothership):
		mothership.active=false;mothership.hide();mothership.collision_layer=0
		mothership.clear_defenders()
	story.boss_defeated = true
	story.preparation = 35
	story.link.repair()
	step = Step.BOARD
	hud.set_boss_health(0, 1)
	world.set_pad_lock(false)
	set_objective("AIRE DE LANCEMENT", "Montez dans la fusée.")
	speak("LINA · Brouillage coupé ! Barrière désactivée, procédure de secours terminée. Tous à la fusée !",5.3)


func launch() -> void:
	if squad.difficulty_active and not squad.can_board():
		speak("Rassemblez toute l'équipe près de la fusée avant de partir.",4)
		return
	if not story.ready_to_launch():
		speak("LINA · Le départ n'est pas prêt. Gardez la liaison active encore quelques secondes.",4)
		return
	step = Step.ASCENT
	world.rocket.get_node("CoqueSolide").collision_layer=0
	begin_film(WORLD.pad(13, 3.0, -229), WORLD.pad(0, 6.0, -248))
	var boarding := create_tween().set_parallel(true)
	boarding.tween_interval(1.8)
	for actor in squad.members:
		if not actor.recruited: continue
		actor.show()
		actor.position = WORLD.pad(2.8+actor.slot*0.7,0.05,-243+actor.slot*0.5)
		actor.boarding_weight = 0
		boarding.tween_method(actor.board_ship_step.bind(actor.position,WORLD.pad(0,1.8,-245.8)),0.0,1.0,1.8)
	speak("LINA · Je monte. Prenez le siège à côté du mien. On rentre ensemble.",3)
	await boarding.finished
	for actor in squad.members: actor.hide()
	speak("ORDINATEUR DE BORD · Quatre occupants. Trajectoire confirmée. Destination : Terre.", 4.0)
	world.rocket_flame.show()
	world.rocket_flame.scale = Vector3(0.35, 0.12, 0.35)
	var ignition := create_tween()
	ignition.tween_property(world.rocket_flame, "scale", Vector3.ONE, 1.5).set_trans(Tween.TRANS_CUBIC)
	play_cue(MOTOR_SOUND, 0.63)
	await ignition.finished
	var ascent := create_tween()
	ascent.tween_method(animate_ascent,0.0,10.0,10.0)
	await ascent.finished
	var return_trip := preload("res://missions/lunar_escape/return_flight.gd").new()
	add_child(return_trip)
	return_trip.setup(self)
	await return_trip.play()
	step = Step.COMPLETE
	saver.clear()
	hud.dialogue.text = ""
	hud.show_menu("complete")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func animate_ascent(seconds: float) -> void:
	var turn := maxf(0,seconds-3)
	world.rocket.position = Vector3(turn*turn*0.28,1.4*seconds*seconds+0.08*seconds*seconds*seconds,-249-turn*turn*0.5)
	world.rocket.rotation = Vector3(-0.004*turn*turn,0,-0.0025*turn*turn)
	frame_camera(WORLD.pad(24+seconds*0.5,5+seconds*0.8,-222),world.rocket.global_position+Vector3.UP*6)


func set_objective(chapter: String, objective: String) -> void:
	hud.chapter.text = chapter
	hud.objective.text = objective


func speak(line: String, seconds: float) -> void:
	hud.dialogue.text = line
	var spoken: float = voice.play_line(line) if is_instance_valid(voice) else 0.0
	dialogue_until = game_time + maxf(seconds,spoken)


func play_cue(stream: AudioStream, pitch := 1.0) -> void:
	audio.stream = stream
	audio.pitch_scale = pitch
	audio.play()


func frame_camera(point: Vector3, target: Vector3) -> void:
	film.global_position = point
	film.look_at(target)


func move_camera(destination: Vector3, focus: Vector3, duration: float) -> Signal:
	var from := film.global_position
	var old_focus := from - film.global_basis.z * from.distance_to(focus)
	var motion := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_method(func(weight: float): frame_camera(from.lerp(destination, weight), old_focus.lerp(focus, weight)),
		0.0, 1.0, duration)
	return motion.finished


func begin_film(point: Vector3, target: Vector3) -> void:
	pilot.set_control(false)
	pilot.weapon.hide()
	frame_camera(point, target)
	film.make_current()
	hud.set_film(true)


func end_film() -> void:
	camera.make_current()
	hud.set_film(false)
	pilot.weapon.visible=pilot.vehicle==null and not pilot.equipped.is_empty()
	pilot.set_control(true)


func place_pilot(point: Vector3, heading: float) -> void:
	pilot.global_position = point
	pilot.rotation = Vector3(0, heading, 0)
	pilot.head.rotation = Vector3.ZERO
	pilot.velocity = Vector3.ZERO
	pilot.spawn_transform = pilot.global_transform
	pilot.reset_physics_interpolation()
	if squad!=null: squad.relocate()


func on_death() -> void:
	defeated = true
	pilot.set_control(false)
	hud.show_menu("death")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func respawn() -> void:
	var restart_boss := step==Step.BATTLE or step==Step.REVEAL
	defeated = false
	get_tree().paused = false
	for bolt in $Projectiles.get_children():
		bolt.queue_free()
	if step == Step.TUTORIAL and is_instance_valid(tutorial_drone):
		tutorial_drone.reset_drone()
	pilot.dismount(false)
	if step == Step.BIKE:
		world.bike.position = Vector3(0, 0, -25.3)
		world.bike.rotation = Vector3.ZERO
		world.scout.position = Vector3(6.2, 0, -29.0)
		world.scout.rotation = Vector3.ZERO
	elif step == Step.TRANSPORT:
		world.transport.position = WORLD.at(1, 0, 0, -26)
		world.transport.rotation = Vector3.ZERO
	place_pilot(checkpoint, checkpoint_heading)
	pilot.restore_health()
	pilot.weapon.cancel_reload()
	pilot.weapon.ammo = pilot.weapon.magazine_capacity
	pilot.weapon.reserve_ammo = maxi(pilot.weapon.reserve_ammo, pilot.weapon.magazine_capacity * 3)
	if is_instance_valid(pilot.loadout.offhand):
		pilot.loadout.offhand.cancel_reload()
		pilot.loadout.offhand.ammo=pilot.loadout.offhand.magazine_capacity
		pilot.loadout.offhand.reserve_ammo=maxi(pilot.loadout.offhand.reserve_ammo,pilot.loadout.offhand.magazine_capacity*2)
	if pilot.shield_unlocked:
		pilot.shield_charge = 100
	pilot.oxygen = 100
	pilot.asphyxia_timer = 0
	hud.title_card.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if restart_boss:
		if is_instance_valid(mothership):
			mothership.active = false
			mothership.clear_defenders()
			mothership.queue_free()
			mothership = null
		for container in [$Effects,$Wrecks]:
			for effect in container.get_children(): effect.queue_free()
		story.preparation = 0; story.boss_defeated = false; story.link.repair()
		world.set_pad_lock(true)
		ship_reveal()
		return
	pilot.set_control(true)


func toggle_pause() -> void:
	if equipment_room!=null and equipment_room.window.visible: equipment_room.close();return
	if exploration.opened:
		exploration.close()
		return
	if base_life.log_window.visible:
		base_life.close_journal()
		return
	if code_window.visible:
		close_code()
		return
	if defeated or transition or step in [Step.BRIEFING, Step.INTRO, Step.REVEAL, Step.ASCENT, Step.COMPLETE]:
		return
	if get_tree().paused:
		get_tree().paused = false
		hud.title_card.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		pilot.set_control(true)
	else:
		var saved := false
		if saver.enabled:
			saved = saver.write_save(self)
			if saved: save_clock = 0
		pilot.set_control(false)
		hud.show_menu("pause")
		if saver.enabled:
			hud.card_copy.text += "\n"+("Progression sauvegardée." if saved else "Sauvegarde indisponible : le précédent point est conservé.")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true


func restart() -> void:
	saver.clear()
	saver.enabled = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func continue_saved_game() -> void:
	var data: Dictionary = saver.read_save()
	if data.is_empty() or not saver.restore(self,data):
		hud.card_copy.text = "La sauvegarde est indisponible. Vous pouvez commencer une nouvelle campagne."
		return
	saved_stage = step
	save_clock = 0

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(pilot): saver.write_save(self)
