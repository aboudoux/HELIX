extends CharacterBody3D
const SUIT := preload("res://missions/lunar_escape/escort_suit.gd")
const BOLT := preload("res://missions/lunar_escape/escort_bolt.gd")
var squad: Node3D
var identity := "MAËL"
var slot := 0
var recruited := false
var embarked := false
var health := 140
var max_health := 140
var alive := true
var avatar: Node3D
var caption: Label3D
var target: Node3D
var path := PackedVector3Array()
var path_index := 0
var route_clock := 0.0
var attack_clock := 0.6
var think_clock := 0.0
var rounds := 6
var reload_left := 0.0
var flash_left := 0.0
var hurt_left := 0.0
var safe_time := 0.0
var heal_fraction := 0.0
var shots_fired := 0
var waiting := false
var boarding_weight := 0.0
var greeting_left := 0.0
var sound: AudioStreamPlayer3D
var reload_sound: AudioStreamPlayer3D
var refuge_origin := Vector3.ZERO
var refuge_goal := Vector3.ZERO
var refuge_clock := 0.0
var refuge_wait := 0.3
var refuge_leg := 0
var visitor_visible := false
var has_greeted := false
var notice_clock := 0.0
var refuge_stuck := 0.0
var downed := false
var bleed_left := 0.0
var revives_left := 1
var revive_protection := 0.0
var fall_tween: Tween
var heard_point := Vector3.ZERO
var listen_left := 0.0

func _ready() -> void:
	add_to_group("escorts")
	collision_layer = 16; collision_mask = 25
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(47)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28; capsule.height = 1.78
	shape.shape = capsule; shape.position.y = 0.91
	add_child(shape)
	avatar = SUIT.new()
	avatar.identity = identity
	avatar.accent = [Color("87957b"),Color("7592a1"),Color("bda071")][slot]
	add_child(avatar)
	avatar.build()
	caption = squad.game.WORLD.placard(self,identity,Vector3(0,2.12,0),Color("b4e4d7"))
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.pixel_size = 0.002
	sound = AudioStreamPlayer3D.new()
	sound.stream = preload("res://audio/lunar_rifle.wav")
	sound.volume_db = -13; sound.max_distance = 45
	add_child(sound)
	reload_sound = AudioStreamPlayer3D.new()
	reload_sound.stream = preload("res://audio/weapon_reload.wav")
	reload_sound.volume_db = -18; reload_sound.max_distance = 12
	add_child(reload_sound)

func get_aim_point() -> Vector3:
	return global_position+Vector3.UP*1.25

func board_ship_step(weight: float, start: Vector3, destination: Vector3) -> void:
	var delta := maxf(0,weight-boarding_weight)*1.8
	boarding_weight = weight
	position = start.lerp(destination,weight)
	velocity = (destination-start)/1.8
	rotation.y = atan2(-velocity.x,-velocity.z)
	avatar.animate_escort(self,delta,get_aim_point()-global_basis.z*8,0,false)

func recruit() -> void:
	recruited = true
	greeting_left = 2.2
	if get_parent()!=squad.game.world: reparent(squad.game.world,true)
	show()
	avatar.show()
	avatar.gun.show()
	route_clock = 0

func reset_at(point: Vector3, restore_health := true) -> void:
	listen_left = 0.0
	if restore_health:
		health = max_health; downed = false; bleed_left = 0; revives_left = 1; revive_protection = 0
	if fall_tween != null: fall_tween.kill()
	alive = true; embarked = false
	avatar.rotation = Vector3.ZERO; avatar.position = Vector3.ZERO
	global_position = point; velocity = Vector3.ZERO
	collision_layer = 0 if downed else 16
	path.clear(); target = null; route_clock = 0
	rounds = 6; reload_left = 0; hurt_left = 0; safe_time = 0
	visible = recruited
	reset_physics_interpolation()

func apply_damage(amount: int) -> bool:
	if downed or revive_protection>0 or amount<=0: return false
	if not recruited or embarked or not alive or squad.game.defeated or not squad.game.pilot.in_control or get_tree().paused or hurt_left>0: return false
	health = maxi(0,health-amount)
	hurt_left = 0.22; safe_time = 0
	avatar.torso.rotation.x = -0.09
	if health==0:
		if revives_left>0:
			downed = true; bleed_left = 22.0; velocity = Vector3.ZERO; target = null
			collision_layer = 0
			fall_tween = create_tween().set_parallel(true)
			fall_tween.tween_property(avatar,"rotation:z",PI*.43,.4)
			fall_tween.tween_property(avatar,"position:y",.28,.4)
			squad.game.speak(identity+" · À terre ! Approchez et maintenez G pour me secourir !",5)
		else: die()
	elif health<=40: squad.warn_wounded(self)
	return true

func die() -> void:
	alive = false; downed = false; collision_layer = 0
	avatar.rotation.z = PI*.48; avatar.position.y = .22
	squad.escort_lost(self)

func revive() -> bool:
	if not downed or not alive or bleed_left<=0: return false
	if fall_tween != null: fall_tween.kill()
	downed = false
	revives_left -= 1; bleed_left = 0; health = ceili(max_health*.4)
	collision_layer = 16; hurt_left = .22; revive_protection = 2.0; safe_time = 0; route_clock = 0
	fall_tween = create_tween().set_parallel(true)
	fall_tween.tween_property(avatar,"rotation",Vector3.ZERO,.45)
	fall_tween.tween_property(avatar,"position",Vector3.ZERO,.45)
	return true

func visible_target(enemy: Node3D) -> bool:
	if not is_instance_valid(enemy): return false
	var ray := PhysicsRayQueryParameters3D.create(get_aim_point(),squad.aim_point(enemy),27,[get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).get("collider")==enemy

func _physics_process(delta: float) -> void:
	if not alive or embarked or not squad.game.pilot.in_control: return
	revive_protection = maxf(0,revive_protection-delta)
	if downed:
		bleed_left = maxf(0,bleed_left-delta)
		caption.text = "%s · SECOURS · %d s" % [identity,ceili(bleed_left)]
		caption.modulate = Color("ff805d")
		velocity.y += squad.game.world.movement_gravity(global_position).y*delta
		move_and_slide()
		if bleed_left<=0: die()
		return
	if not recruited:
		if is_visible_in_tree(): animate_refuge(delta)
		return
	greeting_left = maxf(0,greeting_left-delta)
	listen_left = maxf(0.0, listen_left-delta)
	hurt_left = maxf(0,hurt_left-delta); safe_time += delta
	flash_left = maxf(0,flash_left-delta)
	attack_clock = maxf(0,attack_clock-delta)
	think_clock -= delta; route_clock -= delta
	if think_clock<=0:
		think_clock = 0.55+slot*0.06
		target = null
		var nearest := 30.0
		for enemy in squad.enemies:
			if not squad.hostile_alive(enemy): continue
			var distance := global_position.distance_to(enemy.global_position)
			if distance<nearest and visible_target(enemy): target = enemy; nearest = distance
	if not squad.hostile_alive(target): target = null
	if squad.hostile_alive(squad.commands.focus) and visible_target(squad.commands.focus): target = squad.commands.focus
	if target != null: squad.warn_behind(self, target)
	if target==null and safe_time>12 and health<max_health:
		heal_fraction += delta*2
		if heal_fraction>=1: health = mini(max_health,health+int(heal_fraction)); heal_fraction = fmod(heal_fraction,1)
	if reload_left>0:
		reload_left = maxf(0,reload_left-delta)
		if reload_left==0: rounds = 6
	elif target!=null and attack_clock<=0 and visible_target(target):
		fire()
	var leader: CharacterBody3D = squad.game.pilot
	var leader_point: Vector3 = squad.TERRAIN.nearest_image(leader.global_position,global_position)
	var holding: bool = squad.commands.holding and squad.commands.hold_points.has(get_instance_id())
	if holding: leader_point = squad.commands.hold_points[get_instance_id()]
	var goal: Vector3 = leader_point+leader.global_basis.z*(2.2+slot*0.65)+leader.global_basis.x*((slot-1)*1.0)
	if holding: goal = leader_point
	var separation := global_position.distance_to(leader_point)
	# Never run through walls to reach a formation slot; routing uses the leader's traversable position.
	if route_clock<=0:
		route_clock = 0.85+slot*0.12
		path = squad.route(global_position,leader_point)
		path_index = 1 if path.size()>1 else 0
	while path_index<path.size() and global_position.distance_to(path[path_index])<0.45: path_index += 1
	var direction := Vector3.ZERO
	var stop_distance := 2.6+slot*0.6
	if holding: stop_distance = .45
	var in_doorway := false
	for door in squad.game.world.doors.values():
		if global_position.distance_to(door.global_position)>3: continue
		var local: Vector3 = door.to_local(global_position)
		if absf(local.x)<door.width*0.5+0.3 and absf(local.z)<1.05 and absf(local.y)<0.5: in_doorway = true
	if (separation>stop_distance or in_doorway or absf(global_position.y-leader.global_position.y)>0.6) and path_index<path.size():
		direction = path[path_index]-global_position
		direction.y = 0
		direction = direction.normalized()
	elif not holding and separation<1.5:
		direction = global_position-leader_point
		direction.y = 0; direction = direction.normalized()
	elif separation<=stop_distance and squad.clear_walk(global_position,goal):
		direction = goal-global_position
		direction.y = 0
		if direction.length()<0.7: direction = Vector3.ZERO
		else: direction = direction.normalized()*0.35
	for ally in squad.members:
		if ally!=self and ally.recruited and not ally.embarked:
			var away: Vector3 = global_position-ally.global_position
			away.y = 0
			if away.length()<0.9 and away.length()>0.01: direction += away.normalized()*0.65
	# Yield to a moving player in narrow passages rather than holding formation in the doorway.
	if separation<2.6 and Vector2(leader.velocity.x,leader.velocity.z).length()>0.7:
		var forward := Vector3(leader.velocity.x,0,leader.velocity.z).normalized()
		var relative := global_position-leader_point
		var side := forward.cross(Vector3.UP)
		var lateral := relative.dot(side)
		if relative.dot(forward) > -.35 and absf(lateral) < .9:
			if lateral < 0.0 or (is_zero_approx(lateral) and slot%2==1): side = -side
			for candidate in [side, -side]:
				if squad.clear_walk(global_position,global_position+candidate*1.15):
					direction = candidate
					break
	direction = direction.limit_length(1)
	var escape: Vector3 = squad.avoid_blast(self)
	if escape.length_squared()>0.01 and squad.clear_walk(global_position,global_position+escape*1.3): direction = escape
	var speed := 8.8 if separation>8 else 4.8
	var desired := direction*speed
	velocity.x = move_toward(velocity.x,desired.x,delta*14)
	velocity.z = move_toward(velocity.z,desired.z,delta*14)
	velocity.y = -0.5 if is_on_floor() else velocity.y+squad.game.world.movement_gravity(global_position).y*delta
	if is_on_floor() and squad.wave_near(self): velocity.y = 4.0
	move_and_slide()
	waiting = separation>stop_distance+2 and (path.is_empty() or get_position_delta().length()<delta*0.15)
	for door in squad.game.world.doors.values():
		if door.secured or door.get_meta("closed_by_player",false) or door.is_open or door.opening or global_position.distance_to(door.global_position)>2.2: continue
		for i in range(path_index,mini(path_index+5,path.size())):
			var local: Vector3 = door.to_local(path[i])
			if absf(local.x)<door.width*0.5 and absf(local.z)<1.0 and absf(local.y)<0.5:
				if door.airlock!=null: door.airlock.escort_request(self,door)
				else: door.open()
				break
	var look: Vector3 = squad.aim_point(target) if target!=null else get_aim_point()+(-global_basis.z if direction.length()<0.05 else direction)*8
	var facing := look-global_position
	if facing.length()>0.1: rotation.y = lerp_angle(rotation.y,atan2(-facing.x,-facing.z),1-exp(-delta*7))
	if target == null and listen_left > 0.0: look = heard_point
	avatar.animate_escort(self,delta,look,1-reload_left/2.3 if reload_left>0 else 0,flash_left>0)
	caption.text = "%s · %d %%"%[identity,roundi(100.0*health/max_health)]
	caption.modulate = Color("ffae81") if health<=40 else Color.WHITE

func animate_refuge(delta: float) -> void:
	var pilot: CharacterBody3D = squad.game.pilot
	refuge_clock += delta; notice_clock -= delta
	greeting_left = maxf(0,greeting_left-delta)
	if notice_clock<=0:
		notice_clock = 0.15
		var camera: Camera3D = squad.game.camera
		visitor_visible = global_position.distance_to(pilot.global_position)<15 and camera.is_position_in_frustum(get_aim_point())
		if visitor_visible:
			var sight := PhysicsRayQueryParameters3D.create(camera.global_position,get_aim_point(),1)
			visitor_visible = get_world_3d().direct_space_state.intersect_ray(sight).is_empty()
		if visitor_visible and not has_greeted:
			has_greeted = true; greeting_left = 2.2; refuge_wait = 0.7
	var offset := refuge_goal-global_position; offset.y = 0
	refuge_wait = maxf(0,refuge_wait-delta)
	if refuge_wait==0 and offset.length()<0.18:
		choose_refuge_goal(pilot)
		offset = refuge_goal-global_position; offset.y = 0
	var desired := Vector3.ZERO
	if refuge_wait==0 and offset.length()>0.18: desired = offset.normalized()*0.85
	if global_position.distance_to(pilot.global_position)<1.4: desired = Vector3.ZERO
	velocity.x = move_toward(velocity.x,desired.x,delta*2.4)
	velocity.z = move_toward(velocity.z,desired.z,delta*2.4)
	velocity.y = -0.5 if is_on_floor() else velocity.y+squad.game.world.movement_gravity(global_position).y*delta
	move_and_slide()
	refuge_stuck = refuge_stuck+delta if desired.length()>0.1 and get_position_delta().length()<delta*0.12 else 0.0
	if refuge_stuck>0.6:
		refuge_goal = global_position; refuge_wait = 0.8; refuge_stuck = 0
	elif desired.length()>0.1 and global_position.distance_to(refuge_goal)<0.18:
		refuge_wait = 1.4+slot*0.45
	var aim: Vector3 = pilot.get_aim_point()+Vector3.UP*0.35 if visitor_visible else get_aim_point()-global_basis.z*8
	var facing := aim-global_position if visitor_visible else velocity
	if Vector2(facing.x,facing.z).length()>0.1:
		rotation.y = lerp_angle(rotation.y,atan2(-facing.x,-facing.z),1-exp(-delta*3.5))
	avatar.animate_escort(self,delta,aim,0,false)

func choose_refuge_goal(pilot: CharacterBody3D) -> void:
	# Short, floor-checked walks stay inside the refuge rather than pursuing the player.
	for attempt in range(12):
		var angle := refuge_leg*2.4+slot*1.7+attempt*0.53
		var candidate := refuge_origin+Vector3(cos(angle),0,sin(angle))*(0.85+0.15*(attempt%3))
		if candidate.distance_to(pilot.global_position)<1.5: continue
		var floor_hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*0.3,candidate-Vector3.UP*0.4,1))
		if floor_hit.is_empty() or floor_hit.normal.y<0.8: continue
		candidate.y = floor_hit.position.y+0.025
		if not squad.clear_walk(global_position,candidate): continue
		refuge_goal = candidate; refuge_leg += 1
		return
	refuge_goal = global_position; refuge_wait = 1.0

func fire() -> void:
	var origin: Vector3 = avatar.muzzle.global_position
	var aim: Vector3 = squad.aim_point(target)
	# Check the actual muzzle as well as the eyes, including teammates and the player.
	var check := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,aim,27,[get_rid()]))
	if check.get("collider")!=target: attack_clock = 0.25; return
	var bolt := BOLT.new()
	bolt.owner_rid = get_rid(); bolt.squad = squad
	squad.game.get_node("Projectiles").add_child(bolt)
	bolt.global_position = origin
	bolt.velocity = origin.direction_to(aim)*75
	bolt.look_at(aim)
	sound.play(); flash_left = 0.065
	avatar.gun.shot_age = 0
	shots_fired += 1; rounds -= 1
	attack_clock = 0.85+slot*0.15
	if rounds<=0: reload_left = 2.3; reload_sound.play()
