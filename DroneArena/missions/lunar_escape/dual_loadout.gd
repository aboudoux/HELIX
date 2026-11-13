extends Node
const WEAPON := preload("res://scenes/weapon.tscn")
const MELEE := preload("res://missions/lunar_escape/melee_model.gd")
const GUNS := ["pistol","shotgun","smg"]
const BLADES := ["sabre","lance"]
const NAMES := {"none":"Main libre","pistol":"Pistolet","shotgun":"Fusil à pompe","smg":"Fusil automatique","sabre":"Sabre","lance":"Lance","shield":"Bouclier balistique"}
var pilot: CharacterBody3D
var game: Node3D
var unlocked := false
var active := false
var right := "pistol"
var left := "none"
var armor := 0
var reserves: Dictionary = {}
var offhand: Node3D
var left_visual: Node3D
var melee_right: Node3D
var melee_left: Node3D
var swings := [0.0,0.0]
var hit_pending := [false,false]
var trigger_armed := [false,false]
var hit_count := 0
var panel: Label
var swing_sound: AudioStreamPlayer
var reload_queue: Array[Node3D] = []
var reload_current: Node3D
var reload_wait := 0.0
var reload_started := false

func cancel_hand_reload() -> void:
	for gun in [pilot.weapon,offhand]:
		if not is_instance_valid(gun): continue
		gun.hand_busy=false
		if is_instance_valid(gun.reload_visual): gun.reload_visual.stowed=false
		if gun==reload_current: gun.cancel_reload()
	reload_queue.clear();reload_current=null;reload_started=false

func _input(event: InputEvent) -> void:
	if not active or pilot.building or left=="none" or not pilot.in_control or pilot.vehicle!=null or get_tree().paused: return
	if event.is_action_pressed("reload") and not event.is_echo() and reload_current==null:
		for gun in [pilot.weapon if right not in BLADES else null,offhand]:
			if is_instance_valid(gun) and gun.ammo<gun.magazine_capacity and gun.reserve_ammo!=0:
				reload_queue.append(gun)
		reload_queue.sort_custom(func(a,b):return a.ammo<b.ammo)
		next_hand_reload()

func next_hand_reload() -> void:
	if reload_queue.is_empty(): cancel_hand_reload();return
	reload_current=reload_queue.pop_front();reload_wait=.18;reload_started=false
	for gun in [pilot.weapon,offhand]:
		if not is_instance_valid(gun): continue
		gun.hand_busy=true
		if is_instance_valid(gun.reload_visual): gun.reload_visual.stowed=gun!=reload_current

func update_hand_reload(delta: float) -> void:
	if reload_current==null: return
	if not reload_started:
		reload_wait-=delta
		if reload_wait<=0:
			reload_started=reload_current.start_reload()
			if not reload_started: next_hand_reload()
	elif not reload_current.is_reloading: next_hand_reload()

func setup(campaign: Node3D) -> void:
	game=campaign;pilot=game.pilot
	panel=game.hud.label(game.hud.content,"",15,Color("cde7e7"))
	game.hud.pin(panel,Control.PRESET_BOTTOM_LEFT,Vector2(22,-126),Vector2(640,42))
	swing_sound=AudioStreamPlayer.new();add_child(swing_sound)
	swing_sound.stream=preload("res://audio/weapon_reload.wav");swing_sound.volume_db=-15

func configure(main: String, secondary: String, protection: int) -> void:
	if not unlocked or main not in GUNS+BLADES or secondary not in GUNS+BLADES+["none","shield"]: return
	cancel_hand_reload()
	store_offhand()
	active=true;right=main;left=secondary;armor=clampi(protection,0,2)
	pilot.weapon.cancel_reload()
	if main not in BLADES:
		pilot.unlock_weapon(main)
	else:
		pilot.weapon.hide();pilot.weapon.set_enabled(false)
	# Every gun is issued once; revisiting the terminal never refills magazines.
	for model in [offhand,melee_left,melee_right]:
		if is_instance_valid(model):
			model.hide();model.queue_free()
	offhand=null;melee_left=null;melee_right=null
	if secondary in GUNS: build_offhand(secondary)
	if main in BLADES: melee_right=make_blade(main,false)
	if secondary in BLADES: melee_left=make_blade(secondary,true)
	pilot.shield_unlocked=pilot.shield_unlocked or secondary=="shield"
	if secondary=="shield": pilot.shield_charge=maxf(pilot.shield_charge,30.0)
	pilot.max_health=[125,150,175][armor]
	pilot.health=mini(pilot.health,pilot.max_health)
	pilot.avatar.set_reinforced(true)
	pilot.avatar.ceramic.set_shader_parameter("tint",[Color("d0d4c7"),Color("869b98"),Color("495b64")][armor])
	# The inventory changes gear only. Mission clearance is granted at the armory.
	pilot.set_third_person(false)
	swings.assign([0.0,0.0]);hit_pending.assign([false,false]);trigger_armed.assign([false,false])
	sync_control()

func store_offhand() -> void:
	if is_instance_valid(offhand) and left in GUNS:
		reserves[left]={"loaded":offhand.ammo,"reserve":offhand.reserve_ammo}
		offhand.cancel_reload()

func build_offhand(key: String) -> void:
	var profile: Dictionary=pilot.WEAPONS[key]
	if not reserves.has(key): reserves[key]={"loaded":profile.capacity,"reserve":profile.rounds}
	offhand=WEAPON.instantiate()
	offhand.position=Vector3(-.30,-.24,-.54)
	pilot.get_node("Head/Camera3D").add_child(offhand)
	offhand.model.get_node("VisualModel").hide()
	offhand.fire_action=&"aim";offhand.aim_allowed=false
	offhand.magazine_capacity=profile.capacity;offhand.ammo=clampi(int(reserves[key].loaded),0,profile.capacity);offhand.reserve_ammo=int(reserves[key].reserve)
	offhand.fire_interval=profile.interval;offhand.reload_duration=profile.reload;offhand.max_range=profile.range
	offhand.pellets=profile.pellets;offhand.spread=.036 if key=="shotgun" else 0
	offhand.automatic=key=="smg";offhand.campaign_effects=true
	offhand.shot_sound.stream=load("res://audio/recorded_%s.wav"%{"pistol":"pistol","shotgun":"shotgun","smg":"rifle"}[key])
	offhand.shot_sound.volume_db=-6;offhand.reload_sound.volume_db=-11
	offhand.shot_sound.bus="LunarSuit"
	left_visual=game.WORLD.gun(offhand.model,key,true);left_visual.scale.x=-1;left_visual.support.hide()
	left_visual.hand_side=-1;left_visual.one_handed=true
	offhand.reload_managed=true
	offhand.reload_visual=left_visual;offhand.muzzle.position=left_visual.muzzle

func make_blade(key: String, is_left: bool) -> Node3D:
	var model:=MELEE.new();pilot.get_node("Head/Camera3D").add_child(model);model.build(key,true,is_left)
	model.position=Vector3(-.32 if is_left else .32,-.28,-.57)
	model.rotation.z=.24 if is_left else -.24
	return model

func primary_changed(key: String) -> void:
	if not active: return
	cancel_hand_reload()
	right=key
	if is_instance_valid(melee_right): melee_right.hide();melee_right.queue_free();melee_right=null
	sync_control()

func sync_control() -> void:
	if not active: return
	var allowed: bool=pilot.in_control and not pilot.building and pilot.vehicle==null and not get_tree().paused
	pilot.weapon.tool_blocked=pilot.building
	pilot.weapon.aim_allowed=left=="none"
	pilot.weapon.reload_managed=left!="none"
	if is_instance_valid(pilot.gun_visual): pilot.gun_visual.one_handed=left!="none"
	if right in BLADES: pilot.weapon.set_enabled(false);pilot.weapon.hide()
	if is_instance_valid(pilot.gun_visual): pilot.gun_visual.support.visible=left=="none"
	if is_instance_valid(offhand):
		offhand.tool_blocked=pilot.building
		offhand.visible=allowed
		offhand.set_enabled(allowed)
	for model in [melee_right,melee_left]:
		if is_instance_valid(model): model.visible=allowed
	trigger_armed.assign([false,false])

func _physics_process(delta: float) -> void:
	if not active: return
	var allowed: bool=pilot.in_control and not pilot.building and pilot.vehicle==null and not game.defeated
	panel.visible=allowed
	if not allowed:
		cancel_hand_reload()
		if is_instance_valid(offhand) and offhand.enabled: offhand.set_enabled(false);offhand.hide()
		for model in [melee_right,melee_left]:
			if is_instance_valid(model): model.hide()
		return
	if is_instance_valid(offhand) and not offhand.enabled: offhand.show();offhand.set_enabled(true)
	if right in BLADES: pilot.weapon.set_enabled(false);pilot.weapon.hide()
	update_hand_reload(delta)
	if reload_current!=null and left=="shield": pilot.shield_visual.hide();pilot.shielding=false
	panel.text="Gauche · %s%s    |    Droite · %s"%[NAMES.get(left,left)," %d / %d"%[offhand.ammo,offhand.reserve_ammo] if is_instance_valid(offhand) else "",NAMES.get(right,right)]
	for hand in range(2):
		var key: String=right if hand==0 else left
		var action:=&"fire" if hand==0 else &"aim"
		if not Input.is_action_pressed(action): trigger_armed[hand]=true
		if key not in BLADES: continue
		if reload_current==null and trigger_armed[hand] and Input.is_action_pressed(action) and swings[hand]<=0:
			swings[hand]=.65 if key=="sabre" else .85;hit_pending[hand]=true;trigger_armed[hand]=false;swing_sound.play()
		var duration:=.65 if key=="sabre" else .85
		swings[hand]=maxf(0,swings[hand]-delta)
		if hit_pending[hand] and swings[hand]<duration*.62:
			hit_pending[hand]=false;strike(key)
		var model: Node3D=melee_right if hand==0 else melee_left
		if is_instance_valid(model):
			model.visible=reload_current==null
			var weight:=sin((1.0-swings[hand]/duration)*PI) if swings[hand]>0 else 0.0
			model.rotation=Vector3(-.25-weight*.68,weight*(1 if hand else -1)*.50,(.24 if hand else -.24)+weight*(.42 if hand else -.42))
			model.position.z=-.57-weight*(.48 if key=="lance" else .12)
			model.align_forearms(game.camera)

func strike(key: String) -> void:
	var camera: Camera3D=game.camera
	var reach:=3.2 if key=="lance" else 2.1
	var space:=game.get_world_3d().direct_space_state
	var best: Dictionary={};var distance:=reach
	# A small swept fan catches nearby bodies, while every ray stops at walls.
	for offset in [-.12,0.0,.12]:
		var direction: Vector3=(-camera.global_basis.z+camera.global_basis.x*offset).normalized()
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position+direction*reach,13,[pilot.get_rid()]))
		if hit.is_empty() or not hit.collider.has_method("receive_hit_at"): continue
		var d: float=camera.global_position.distance_to(hit.position)
		if d<=distance: best=hit;distance=d
	if not best.is_empty():
		if best.collider.receive_hit_at(best.position,best.normal,-camera.global_basis.z,4 if key=="lance" else 3):
			hit_count+=1;pilot.weapon.hit_sound.play()

func snapshot() -> Dictionary:
	store_offhand()
	return {"unlocked":unlocked,"active":active,"right":right,"left":left,"armor":armor,"reserves":reserves.duplicate(true)}

func restore(data: Dictionary) -> void:
	# Live hand models and counters belong to the state before the checkpoint.
	cancel_hand_reload()
	if is_instance_valid(offhand): offhand.set_enabled(false)
	for model in [offhand,melee_left,melee_right]:
		if is_instance_valid(model): model.hide();model.queue_free()
	offhand=null;melee_left=null;melee_right=null
	unlocked=bool(data.get("unlocked",false));reserves=data.get("reserves",{}).duplicate(true)
	active=false
	right=pilot.equipped;left="none";armor=0
	panel.hide()
	pilot.weapon.aim_allowed=true
	pilot.weapon.reload_managed=false
	if is_instance_valid(pilot.gun_visual):
		pilot.gun_visual.one_handed=false
		pilot.gun_visual.support.show()
	if unlocked and data.get("active",false): configure(data.get("right","pistol"),data.get("left","none"),int(data.get("armor",0)))
