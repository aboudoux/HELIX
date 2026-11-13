extends AnimatableBody3D

signal destroyed
signal phase_changed(phase: int)

enum Attack { RECOVER, VOLLEY, BARRAGE, SHOCKWAVE }
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const BOLT := preload("res://scenes/enemy_bolt.tscn")
const IMPACT := preload("res://scripts/drone_debris.gd")
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const FINISH := preload("res://missions/lunar_escape/finishes.gd")
const COLLISION := preload("res://scripts/actor_collision.gd")
const REACTION := preload("res://scripts/hit_reaction.gd")
const WRECK := preload("res://scripts/drone_wreck.gd")
const BURST := preload("res://scripts/drone_burst.gd")
const MAX_HEALTH := 360
const DAMAGE := preload("res://missions/lunar_escape/damage_details.gd")

var pilot: CharacterBody3D
var patrol_center: Vector3
var active := false
var launch_target: StaticBody3D
var health := MAX_HEALTH
var max_health := MAX_HEALTH
var escort_wave_hits: Array[RID] = []
var elapsed := 0.0
var patrol_clock := 0.0
var aggression := 0.0
var cooldown := 1.6
var phase := 0
var attack := Attack.RECOVER
var pattern_index := 0
var shots_left := 0
var target := Vector3.ZERO
var emitters: Array[MeshInstance3D] = []
var warning: MeshInstance3D
var light: OmniLight3D
var visual: Node3D
var recoil := REACTION.new()
var strike_sites: Array[Vector3] = []
var strike_marks: Array[MeshInstance3D] = []
var strike_radius := 0.0
var core: MeshInstance3D
var core_cover: MeshInstance3D
var subsystem_hp: Array[int] = [6,6]
var subsystems: Array[MeshInstance3D] = []
var wave: MeshInstance3D
var wave_origin := Vector3.ZERO
var wave_radius := 0.0
var wave_active := false
var wave_hit := false
var warning_sound: AudioStreamPlayer3D
var discharge_sound: AudioStreamPlayer3D
var guard_director: Node3D
var guards: Array[CharacterBody3D] = []
var walker: Node3D
var reinforcement_delay := -1.0
var reinforcements_called := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	sync_to_physics = false
	COLLISION.add_box(self,Vector3(7,2.1,5.4),Vector3.ZERO)
	COLLISION.add_box(self,Vector3(5.8,1.5,4.8),Vector3(0,.72,-.25))
	COLLISION.add_box(self,Vector3(2.7,1.2,1.2),Vector3(0,.15,-3))
	var core_shape:=CylinderShape3D.new();core_shape.radius=1.77;core_shape.height=.68
	COLLISION.add_shape(self,core_shape,Vector3(0,-1.12,0))
	visual = Node3D.new()
	visual.name = "Visual"
	visual.set_meta("wreck_geometry", "quadrupede_helios")
	add_child(visual)
	var ceramic := FINISH.create(Color("777a78"), 0.46, 0.43, 0.76)
	var graphite := FINISH.create(Color("40494e"), 0.42, 0.58, 0.75)
	KIT.bevel(visual,Vector3.ZERO,Vector3(7.0,2.1,5.4),.45,graphite)
	KIT.bevel(visual,Vector3(0,.72,-.25),Vector3(5.8,1.5,4.8),.35,ceramic)
	KIT.bevel(visual,Vector3(0,.15,-3.0),Vector3(2.7,1.2,1.2),.22,graphite)
	for eye in [-.7,0,.7]: WORLD.ball(visual,Vector3(eye,.28,-3.62),Vector3(.25,.22,.12),WORLD.RED)
	# Separate service plates and fasteners break up the large pressure hull.
	for side in [-1.0,1.0]:
		for segment in range(3):
			var panel:=KIT.bevel(visual,Vector3(side*3.52,.18,-1.75+segment*1.7),Vector3(.18,1.35,1.48),.08,ceramic)
			for y in [-.48,.48]:
				for z in [-.52,.52]: WORLD.ball(panel,Vector3(side*.11,y,z),Vector3(.07,.10,.10),WORLD.STEEL)
			KIT.bevel(panel,Vector3(side*.12,-.12,0),Vector3(.04,.10,.8),.01,graphite)
		for segment in range(2):
			KIT.bevel(visual,Vector3(side*1.42,1.51,-1.42+segment*2.25),Vector3(2.65,.12,2.04),.08,ceramic)
		KIT.bevel(visual,Vector3(side*1.85,.25,-2.74),Vector3(.26,.72,.08),.02,preload("res://materials/Orange.tres"))
	WORLD.cylinder(visual, Vector3(0, -0.97, 0), 1.77, 1.49, 0.48, ceramic)
	core = WORLD.cylinder(visual, Vector3(0, -1.29, 0), 1.15, 0.92, 0.23, WORLD.CYAN)
	core_cover = WORLD.cylinder(visual, Vector3(0, -1.31, 0), 1.20, 0.98, 0.26, graphite)
	set_core_exposed(false)
	for side in [-1.0,1.0]:
		var pod := KIT.bevel(visual,Vector3(side*4.6,-0.12,0.1),Vector3(1.38,0.86,1.60),0.15,WORLD.STEEL)
		KIT.bevel(pod,Vector3(side*0.70,0,0),Vector3(0.04,0.57,1.15),0.015,WORLD.AMBER)
		subsystems.append(pod)
		COLLISION.add_box(self,Vector3(1.4,0.88,1.62),pod.position)
	for plate in range(12):
		var angle := TAU * plate / 12
		var armor := KIT.bevel(visual, Vector3(cos(angle) * 4.10, -0.44, sin(angle) * 2.88),
			Vector3(1.64, 0.53, 1.82), 0.21, ceramic if plate % 3 == 0 else WORLD.ARMOR)
		armor.rotation = Vector3(0.21, -angle, 0)
		KIT.bevel(armor, Vector3(0, -0.274, -0.14), Vector3(1.11, 0.055, 0.79), 0.023, graphite)
		for offset in [-0.34, 0.34]:
			KIT.bevel(armor, Vector3(offset, -0.305, -0.28), Vector3(0.13, 0.034, 0.47), 0.014, WORLD.STEEL)
	for side in [-1.0,1.0]:
		for slot in range(6):
			KIT.bevel(visual,Vector3(side*2.3,1.5,-1.8+slot*.65),Vector3(.7,.10,.28),.035,graphite)
	for i in range(10):
		var angle := TAU * i / 10
		var point := Vector3(cos(angle) * 3.72, -0.87, sin(angle) * 2.68)
		WORLD.ball(visual, point, Vector3(0.97, 0.54, 0.80), WORLD.STEEL)
		emitters.append(WORLD.ball(visual, point - Vector3.UP * 0.25, Vector3(0.54, 0.30, 0.54), WORLD.RED))
	# Four twin-barrel batteries, integrated into the actual volley emitter cycle.
	for i in range(4):
		var angle := TAU*i/4.0+PI/4
		var base := Vector3(cos(angle)*2.8,1.75,sin(angle)*1.6)
		KIT.bevel(visual,base,Vector3(1.35,0.65,1.15),0.14,graphite)
		for side in [-0.24,0.24]:
			var a := base+Vector3(side,.15,0)
			var muzzle := a+Vector3(0,0,-2.1)
			KIT.rod(visual,a,muzzle,0.14,WORLD.STEEL)
			KIT.rod(visual,muzzle+Vector3(0,0,.38),muzzle,0.19,graphite)
			emitters.append(WORLD.ball(visual,muzzle,Vector3.ONE*0.18,WORLD.RED))
	warning = WORLD.cylinder(self, Vector3.ZERO, 0.035, 0.035, 1.0, WORLD.RED)
	warning.hide()
	var target_ring := TorusMesh.new()
	target_ring.inner_radius = 0.92
	target_ring.outer_radius = 1.0
	for i in range(3):
		var ring := WORLD.mesh_node(self, Vector3.ZERO, target_ring, WORLD.AMBER)
		ring.top_level = true
		ring.hide()
		strike_marks.append(ring)
	light = OmniLight3D.new()
	light.position = Vector3(0, -0.75, 0)
	light.light_color = Color("ff517d")
	light.omni_range = 21.0
	light.light_energy = 1.5
	add_child(light)
	var wave_mesh := TorusMesh.new()
	wave_mesh.inner_radius = 0.96
	wave_mesh.outer_radius = 1.0
	wave = WORLD.mesh_node(self,Vector3.ZERO,wave_mesh,WORLD.AMBER)
	wave.top_level = true
	wave.hide()
	warning_sound = AudioStreamPlayer3D.new()
	warning_sound.stream = preload("res://audio/hound_charge.wav")
	warning_sound.volume_db = -8
	warning_sound.unit_size = 18
	warning_sound.max_distance = 80
	add_child(warning_sound)
	discharge_sound = AudioStreamPlayer3D.new()
	discharge_sound.stream = preload("res://audio/lunar_hound_pulse.wav")
	discharge_sound.volume_db = -9
	discharge_sound.unit_size = 18
	discharge_sound.max_distance = 80
	add_child(discharge_sound)
	# Physics bodies discard root scaling: enlarge actual visuals and shape resources.
	visual.scale = Vector3.ONE*1.7
	for collider in get_children():
		if not collider is CollisionShape3D: continue
		collider.position *= 1.7
		var shape: Shape3D = collider.shape
		if shape is ConvexPolygonShape3D:
			var enlarged := PackedVector3Array()
			for point in shape.points: enlarged.append(point*1.7)
			shape.points = enlarged
		elif shape is CylinderShape3D:
			shape.radius *= 1.7; shape.height *= 1.7
		elif shape is BoxShape3D: shape.size *= 1.7
	walker=preload("res://missions/lunar_escape/boss_walker_legs.gd").new()
	visual.add_child(walker);walker.build(self,ceramic,WORLD.STEEL,graphite)


func activate() -> void:
	active = true
	collision_layer = 8
	set_core_exposed(true)
	if guards.is_empty(): spawn_defenders(6)
	guard_director.process_mode = Node.PROCESS_MODE_INHERIT

func spawn_defenders(count: int) -> void:
	var game := get_parent()
	if not is_instance_valid(guard_director):
		guard_director = preload("res://scripts/drone_director.gd").new()
		guard_director.name = "GardeDuBoss"
		guard_director.navigation_region = Rect2i(-42,int(WORLD.COPERNIC_Z)-34,84,68)
		guard_director.floor_height = WORLD.ROOF_HEIGHT
		guard_director.flight_height = WORLD.ROOF_HEIGHT+4
		guard_director.projectile_damage = 10
		guard_director.projectile_speed = 19
		game.add_child(guard_director)
		guard_director.process_mode = Node.PROCESS_MODE_DISABLED
	for i in range(count):
		var angle := TAU*(guards.size())/6.0
		var origin := patrol_center+Vector3(cos(angle)*16,0,sin(angle)*12)
		origin.y = WORLD.ROOF_HEIGHT+4
		add_defender(origin, false)


func add_defender(origin: Vector3, reinforcement: bool) -> CharacterBody3D:
	var drone := preload("res://scenes/drone.tscn").instantiate() as CharacterBody3D
	drone.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	drone.campaign_combat = true
	drone.max_health = 8 if reinforcement else 5
	drone.move_speed = 5.2 if reinforcement else 4.0
	drone.fire_interval = 1.65 if reinforcement else 2.0
	drone.initial_delay = 1.4 if reinforcement else 3.5
	drone.drone_name = "INTERCEPTEUR DE RENFORT" if reinforcement else "GARDE DU QUADRUPÈDE"
	drone.position = origin
	guard_director.add_child(drone)
	FINISH.apply_tree(drone)
	guards.append(drone)
	return drone


func send_reinforcements() -> void:
	# Enter high from both sides of the roof, then descend into flight range.
	for side in [-1.0, 1.0]:
		for index in 2:
			var lane := -219.0-index*8.0
			var origin := WORLD.pad(side*(60.0+index*6.0), 12.0, lane)
			var arrival := WORLD.pad(side*(30.0-index*4.0), 4.0, lane)
			var drone := add_defender(origin, true)
			drone.set_physics_process(false)
			var approach := arrival-origin
			drone.rotation.y = atan2(-approach.x,-approach.z)
			drone.velocity = approach / 3.2
			var flight := drone.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
			flight.tween_property(drone, "position", arrival, 3.2+index*.4).set_trans(Tween.TRANS_SINE)
			flight.tween_callback(func():
				if drone.alive and active:
					drone.velocity = Vector3.ZERO
					drone.set_physics_process(true)
			)

func clear_defenders(destroy_visuals := false) -> void:
	if not is_instance_valid(guard_director): return
	guard_director.process_mode = Node.PROCESS_MODE_DISABLED
	for drone in guards:
		if not is_instance_valid(drone): continue
		if destroy_visuals and drone.alive: drone.receive_hit_at(drone.global_position,Vector3.UP,Vector3.DOWN,9999)
	guard_director.queue_free(); guards.clear()

func _exit_tree() -> void:
	if is_instance_valid(guard_director): guard_director.queue_free()


func _physics_process(delta: float) -> void:
	if not active or pilot.health <= 0:
		return
	if reinforcement_delay >= 0.0:
		reinforcement_delay -= delta
		if reinforcement_delay < 0.0: send_reinforcements()
	elapsed += delta
	recoil.apply(visual, Vector3.ZERO, delta)
	aggression = move_toward(aggression, float(phase), delta * 1.6)
	patrol_clock += delta * (0.56 + aggression * 0.13)
	global_position = patrol_center + Vector3(sin(patrol_clock) * (8.5 + aggression * 1.5),sin(elapsed*2.8)*.10,cos(elapsed*.65)*2.0)
	rotation.y=lerp_angle(rotation.y,atan2(pilot.global_position.x-global_position.x,pilot.global_position.z-global_position.z)+PI,delta*1.0)
	walker.update_pose(self,delta)
	if wave_active:
		advance_wave(delta)
		return
	cooldown -= delta
	if cooldown > 0.0:
		if attack == Attack.VOLLEY:
			show_warning()
		return
	match attack:
		Attack.RECOVER:
			start_attack()
		Attack.VOLLEY:
			fire_volley_shot()
		Attack.BARRAGE:
			fire_barrage()
		Attack.SHOCKWAVE:
			wave_active = true
			discharge_sound.play()


func start_attack() -> void:
	set_core_exposed(false)
	pattern_index += 1
	warning_sound.pitch_scale = 0.65+phase*0.12
	warning_sound.play()
	if phase==2 and pattern_index%3==0:
		attack = Attack.SHOCKWAVE
		cooldown = 1.25
		wave_origin = pilot.global_position
		wave_origin.x = global_position.x
		wave_origin.z = global_position.z
		var cast := PhysicsRayQueryParameters3D.create(wave_origin+Vector3.UP*8,wave_origin-Vector3.UP*12,1)
		var ground := get_world_3d().direct_space_state.intersect_ray(cast)
		wave_origin = ground.get("position",wave_origin)+Vector3.UP*0.10
		wave_radius = 1.0
		wave_hit = false
		escort_wave_hits.clear()
		wave.global_position = wave_origin
		wave.scale = Vector3(1,0.15,1)
		wave.show()
	elif phase > 0 and pattern_index % 2 == 0:
		attack = Attack.BARRAGE
		cooldown = 0.98 if phase == 1 else 0.86
		light.light_energy = 2.8
		show_strike_marks()
	else:
		attack = Attack.VOLLEY
		target = pilot.get_aim_point()
		var squad := get_tree().current_scene.get_node_or_null("EscortSquad")
		if squad!=null: target = squad.pick_target(self,pilot).get_aim_point()
		if is_instance_valid(launch_target) and launch_target.health>0 and pattern_index%3==1:
			target = launch_target.global_position+Vector3.UP*1.4
		shots_left = [5, 7, 9][phase]-(2 if subsystem_hp[0]==0 else 0)
		cooldown = [0.74, 0.65, 0.56][phase]
		show_warning()


func fire_volley_shot() -> void:
	discharge_sound.pitch_scale = randf_range(0.88,1.06)
	discharge_sound.play()
	var from := emitters[(pattern_index*3+shots_left)%emitters.size()].global_position
	var bolt := BOLT.instantiate()
	bolt.damage = 20 + phase * 4
	bolt.speed = 31.0 + phase * 5.0 - (4.0 if subsystem_hp[0]==0 else 0.0)
	get_tree().current_scene.get_node("Projectiles").add_child(bolt)
	bolt.launch(from, from.direction_to(target), get_rid())
	shots_left -= 1
	cooldown = 0.18 - phase * 0.025
	if shots_left == 0:
		recover()


func show_strike_marks() -> void:
	strike_sites.clear()
	strike_radius = 2.0 if phase == 1 else 2.45
	if subsystem_hp[1]==0: strike_radius *= 0.78
	var center: Vector3 = pilot.global_position
	var movement := Vector3(pilot.velocity.x, 0, pilot.velocity.z).limit_length(6.0)
	var lead := movement * 0.46
	if lead.length_squared() < 0.6:
		lead = Vector3(3.5, 0, 0)
	var space := get_world_3d().direct_space_state
	for i in range(2 if phase == 1 else 3):
		var offset := Vector3.ZERO if i == 0 else (lead if i == 1 else -lead)
		var predicted := center + offset
		var cast := PhysicsRayQueryParameters3D.create(predicted + Vector3.UP * 0.4, predicted - Vector3.UP * 3.4, 1)
		var hit := space.intersect_ray(cast)
		var site: Vector3 = hit.get("position", predicted) + Vector3.UP * 0.055
		strike_sites.append(site)
		strike_marks[i].global_position = site
		strike_marks[i].scale = Vector3(strike_radius, 0.16, strike_radius)
		strike_marks[i].show()


func fire_barrage() -> void:
	discharge_sound.pitch_scale = 0.6
	discharge_sound.play()
	var player_point: Vector3 = pilot.global_position
	for site in strike_sites:
		var squad := get_tree().current_scene.get_node_or_null("EscortSquad")
		if squad!=null: squad.blast(site,strike_radius,23 if phase==1 else 31)
		var effect := BURST.new()
		get_tree().current_scene.get_node("Effects").add_child(effect)
		effect.explode(site, Vector3.UP * 0.35)
		var separation := player_point - site
		if absf(separation.y) < 2.2 and Vector2(separation.x, separation.z).length() <= strike_radius:
			pilot.apply_damage_from(23 if phase == 1 else 31, global_position)
	recover()


func recover() -> void:
	attack = Attack.RECOVER
	cooldown = [1.45, 1.18, 0.98][phase]
	cooldown += subsystem_hp.count(0)*0.25
	wave_active = false
	if wave!=null: wave.hide()
	set_core_exposed(active)
	warning.hide()
	for ring in strike_marks:
		ring.hide()
	strike_sites.clear()
	light.light_energy = 1.5


func set_core_exposed(exposed: bool) -> void:
	core.visible = exposed
	core_cover.visible = not exposed


func show_warning() -> void:
	var from := emitters[(pattern_index*3+shots_left)%emitters.size()].global_position
	var line := target - from
	warning.global_position = from + line * 0.5
	warning.global_basis = Basis(Quaternion(Vector3.UP, line.normalized()))
	(warning.mesh as CylinderMesh).height = maxf(line.length(), 0.01)
	warning.show()
	light.light_energy = 1.2 + (1.0 - clampf(cooldown / 0.68, 0.0, 1.0)) * 1.5


func receive_hit_at(point: Vector3, normal: Vector3, incoming: Vector3, damage: int = 1) -> bool:
	if not active:
		return false
	set_meta("last_armor_hit",false)
	set_meta("last_weak_hit",false)
	set_meta("weak_multiplier",4)
	var local := visual.to_local(point)
	var subsystem_hit := false
	for i in range(subsystems.size()):
		if subsystem_hp[i]>0 and local.distance_to(subsystems[i].position)<1.35:
			subsystem_hit = true
			subsystem_hp[i] = maxi(0,subsystem_hp[i]-damage)
			if subsystem_hp[i]==0:
				DAMAGE.shed(self,subsystems[i],incoming*3)
				# Hide the nacelle's luminous trim as well as the armor shell.
				subsystems[i].hide()
			break
	if core.visible and local.y < -0.7 and Vector2(local.x, local.z).length() < 1.5:
		set_meta("last_weak_hit",true)
		damage *= 4
	elif not core.visible and not subsystem_hit and damage<10000:
		# Closed armor is a timing puzzle; exposed subsystems remain valid targets.
		damage = 0
		set_meta("last_armor_hit",true)
	health = maxi(0, health - damage)
	var next_phase := 2 if health <= max_health / 3 else (1 if health <= max_health * 2 / 3 else 0)
	if next_phase != phase and health > 0:
		phase = next_phase
		if not reinforcements_called:
			reinforcements_called = true
			reinforcement_delay = 1.8
		phase_changed.emit(phase)
	recoil.kick(self, incoming, 0.22)
	var sparks := IMPACT.new()
	get_tree().current_scene.get_node("Effects").add_child(sparks)
	sparks.setup(point + normal * 0.025, normal, incoming, false)
	if health == 0:
		active = false
		clear_defenders(true)
		recover()
		set_deferred("collision_layer", 0)
		var wreck := WRECK.new()
		wreck.name = "Epave_Vaisseau"
		get_tree().current_scene.get_node("Wrecks").add_child(wreck)
		var side := -1.0 if global_position.x < 0.0 else 1.0
		wreck.setup(visual, Vector3(8.0 * side, -0.3, -2.0), true)
		wreck.linear_velocity.x = side * 11.0
		wreck.explosive = true
		hide()
		destroyed.emit()
	return true


func advance_wave(delta: float) -> void:
	wave_radius += delta*12.0
	wave.scale = Vector3(wave_radius,0.18,wave_radius)
	var offset := pilot.global_position-wave_origin
	var distance := Vector2(offset.x,offset.z).length()
	var squad := get_tree().current_scene.get_node_or_null("EscortSquad")
	if squad!=null:
		for actor in squad.members:
			if not actor.recruited or actor.embarked or actor.get_rid() in escort_wave_hits: continue
			var delta_position: Vector3 = actor.global_position-wave_origin
			if absf(Vector2(delta_position.x,delta_position.z).length()-wave_radius)<0.7 and absf(delta_position.y)<0.75:
				var cast := PhysicsRayQueryParameters3D.create(wave_origin+Vector3.UP*0.35,actor.get_aim_point(),1)
				if get_world_3d().direct_space_state.intersect_ray(cast).is_empty(): actor.apply_damage(24); escort_wave_hits.append(actor.get_rid())
	if not wave_hit and absf(distance-wave_radius)<0.7 and offset.y<0.75 and offset.y>-1.0:
		var ray := PhysicsRayQueryParameters3D.create(wave_origin+Vector3.UP*0.35,pilot.get_aim_point(),1)
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			pilot.apply_damage_from(24, global_position)
			wave_hit = true
	if wave_radius>29.0: recover()


func tactical_status() -> String:
	var status := "RÉACTEUR EXPOSÉ · VISEZ LE BLEU"
	match attack:
		Attack.VOLLEY: status = "SALVE VERROUILLÉE · DÉPLACEZ-VOUS"
		Attack.BARRAGE: status = "BOMBARDEMENT · SORTEZ DES CERCLES"
		Attack.SHOCKWAVE: status = "ONDE AU SOL · SAUTEZ [ESPACE]"
	return "PHASE %d / 3 · "%(phase+1)+status+"\n"+("Blindage fermé · Visez les nacelles orange" if not core.visible else "Réacteur bleu · Dégâts ×4")+" · %d / 2"%(2-subsystem_hp.count(0))
