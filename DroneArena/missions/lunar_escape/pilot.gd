extends "res://scripts/player.gd"

const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const ARMORY := preload("res://missions/lunar_escape/armory.gd")
const PISTOL_SHOT := preload("res://audio/recorded_pistol.wav")
const ASTRONAUT := preload("res://missions/lunar_escape/astronaut.gd")
const EVA_FINISH := preload("res://missions/lunar_escape/eva_photo_finish.gd")
const WEAPONS := {
	"pistol": {"name": "Pistolet", "capacity": 12, "rounds": 48, "interval": 0.26, "reload": 1.1, "range": 85.0, "pellets": 1},
	"shotgun": {"name": "Fusil à pompe", "capacity": 6, "rounds": 30, "interval": 0.8, "reload": 1.7, "range": 38.0, "pellets": 7},
	"smg": {"name": "Fusil automatique", "capacity": 28, "rounds": 168, "interval": 0.095, "reload": 1.35, "range": 85.0, "pellets": 1},
}

var inventory: Dictionary = {}
var equipped := ""
var in_control := false
var building := false
var shield_charge := 0.0
var shield_unlocked := false
var shielding := false
var shield_delay := 0.0
var shield_visual: Node3D
var gun_visual: Node3D
var vehicle: Node3D
var vehicle_speed := 0.0
var bike_boost := 1.0
var drive_colliders: Array[CollisionShape3D] = []
var vehicle_engine: AudioStreamPlayer
var default_shot: AudioStream
var default_shot_volume: float
var oxygen := 100.0
var oxygen_efficiency := 1.0
var shield_recovery := 28.0
var upgrades: Array[String] = []
var asphyxia_timer := 0.0
var cannon_cooldown := 0.0
var cannon_sound: AudioStreamPlayer
var third_person := false
var shoulder_side := 1.0
var shoulder_blend := 1.0
var camera_height := NAN
var avatar: Node3D
var camera_probe := SphereShape3D.new()
var footsteps: AudioStreamPlayer
var step_index := 0
var steps_played := 0
var foot_surface := "metal"
var foot_distance := 0.0
var loadout: Node


func _ready() -> void:
	super._ready()
	avatar = ASTRONAUT.new()
	avatar.name = "Astronaut"
	add_child(avatar)
	avatar.build()
	EVA_FINISH.dress_pilot(avatar)
	avatar.set_reinforced(false)
	avatar.hide()
	camera_probe.radius = 0.22
	weapon.fired.connect(func(_point,_hit):
		if is_instance_valid(avatar.gun): avatar.gun.fired()
	)
	footsteps = AudioStreamPlayer.new()
	footsteps.stream = preload("res://audio/foley/footstep_concrete_000.ogg")
	footsteps.volume_db = -17
	add_child(footsteps)
	default_shot = weapon.shot_sound.stream
	default_shot_volume = weapon.shot_sound.volume_db
	collision_mask |= 24
	weapon.hide()
	weapon.model.get_node("VisualModel").hide()
	var fill := OmniLight3D.new()
	fill.position = Vector3(-0.33, 0.15, -0.43)
	fill.omni_range = 1.35
	fill.light_color = Color("d1e1ee")
	fill.light_energy = 0.38
	fill.light_cull_mask = ARMORY.VIEWMODEL_LAYER
	$Head/Camera3D.add_child(fill)
	vehicle_engine = AudioStreamPlayer.new()
	var hum := preload("res://audio/elevator_motor.wav").duplicate() as AudioStreamWAV
	hum.loop_mode = AudioStreamWAV.LOOP_FORWARD
	hum.loop_end = roundi(hum.get_length() * hum.mix_rate)
	vehicle_engine.stream = hum
	vehicle_engine.volume_db = -26.0
	add_child(vehicle_engine)
	cannon_sound = AudioStreamPlayer.new()
	cannon_sound.stream = preload("res://audio/lunar_hound_pulse.wav")
	cannon_sound.volume_db = -6.0
	cannon_sound.max_polyphony = 2
	add_child(cannon_sound)
	shield_visual = preload("res://missions/lunar_escape/shield.gd").new()
	$Head/Camera3D.add_child(shield_visual)
	shield_visual.build()
	shield_visual.position = Vector3(-0.42,-0.22,-0.77)
	shield_visual.rotation.y = -0.20
	shield_visual.hide()


func set_control(enabled: bool) -> void:
	in_control = enabled
	velocity = Vector3.ZERO
	shielding = false
	shield_visual.hide()
	weapon.set_enabled(enabled and vehicle == null and not equipped.is_empty())
	refresh_view()
	if is_instance_valid(loadout): loadout.sync_control()


func _unhandled_input(event: InputEvent) -> void:
	if not in_control or get_tree().paused:
		return
	if vehicle == null:
		super._unhandled_input(event)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		head.rotation.y = clampf(head.rotation.y - event.relative.x * mouse_sensitivity, -0.85, 0.85)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * mouse_sensitivity, -0.65, 0.65)


func movement_gravity() -> Vector3:
	return get_parent().world.movement_gravity(global_position)

func _physics_process(delta: float) -> void:
	jump_speed = 4.0
	if not in_control or health <= 0:
		return
	var left_block: bool = is_instance_valid(loadout) and loadout.active and loadout.left=="shield" and Input.is_action_pressed("aim")
	var shield_equipped: bool = not is_instance_valid(loadout) or not loadout.active or loadout.left=="shield"
	shielding = not building and shield_equipped and shield_unlocked and shield_charge > 0.0 and vehicle == null and (Input.is_physical_key_pressed(KEY_F) or left_block)
	shield_visual.visible = shielding and (not using_third_person() or not avatar.visible)
	shield_visual.set_charge(shield_charge)
	shield_visual.scale = shield_visual.scale.lerp(Vector3.ONE * (1.12 if shielding else 0.75), minf(delta * 12.0, 1.0))
	shield_delay = maxf(0.0, shield_delay - delta)
	if shield_delay == 0.0 and not shielding:
		shield_charge = minf(100.0 if shield_unlocked else 0.0, shield_charge + shield_recovery * delta)
	if vehicle != null:
		drive(delta)
		var cannon:=vehicle.get_node_or_null("Canon")
		if cannon!=null: cannon.rotation=Vector3(head.rotation.x,head.rotation.y,0)
		cannon_cooldown = maxf(0.0, cannon_cooldown - delta)
		if Input.is_action_pressed("fire") and cannon_cooldown == 0.0:
			fire_cannon()
	else:
		var was_grounded := is_on_floor()
		var fall_speed := velocity.y
		super._physics_process(delta)
		if not was_grounded and is_on_floor() and fall_speed < -1.5:
			play_footstep(true)
		if is_on_floor(): foot_distance += Vector2(velocity.x,velocity.z).length()*delta
		else: foot_distance = 0.0
		if is_on_floor() and foot_distance>(3.1 if is_sprinting else 2.7):
			foot_distance = 0.0
			play_footstep(false)
	update_follow_camera(delta)

func play_footstep(landing: bool) -> void:
	var ray := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*0.2,global_position-Vector3.UP*0.55,1,[get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	foot_surface = "dust" if not hit.is_empty() and hit.collider.get_meta("impact_surface","")=="dust" else "metal"
	step_index = (step_index+randi_range(1,4))%5
	footsteps.stream = load("res://audio/foley/footstep_%s_%03d.ogg"%["snow" if foot_surface=="dust" else "concrete",step_index])
	footsteps.pitch_scale = randf_range(0.98,1.02)
	footsteps.volume_db = -12 if landing else (-14 if is_sprinting else -17)
	footsteps.play(); steps_played += 1


func fire_cannon() -> void:
	if vehicle == null or not in_control or get_tree().paused or cannon_cooldown > 0.0:
		return
	var heavy: bool=vehicle.get_meta("sealed",false)
	cannon_cooldown = 1.15 if heavy else .32
	var camera: Camera3D = $Head/Camera3D
	var origin := vehicle.to_global(vehicle.get_meta("cannon_muzzle"))
	if vehicle.has_node("ChassisVisuel"): origin=vehicle.get_node("ChassisVisuel").to_global(vehicle.get_meta("cannon_muzzle"))
	var target := camera.global_position - camera.global_basis.z * 120.0
	var excluded: Array[RID] = [get_rid(), vehicle.get_node("ParkedCollision").get_rid()]
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, target, 9, excluded)
	var sight := space.intersect_ray(query)
	if not sight.is_empty():
		target = sight.position
	var cannon:=vehicle.get_node_or_null("Canon")
	if cannon!=null:
		cannon.look_at(target,Vector3.UP)
		origin=cannon.muzzle.global_position
	query = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.8, origin, 9, excluded)
	query.hit_from_inside = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		query = PhysicsRayQueryParameters3D.create(origin, target + origin.direction_to(target) * 0.03, 9, excluded)
		query.hit_from_inside = true
		hit = space.intersect_ray(query)
	if not hit.is_empty():
		target = hit.position
		if hit.collider.has_method("receive_hit_at"):
			hit.collider.receive_hit_at(hit.position, hit.normal, origin.direction_to(target),10000 if heavy else 1)
	weapon.spawn_effect(origin, target, true, not hit.is_empty())
	if cannon!=null: cannon.fire()
	cannon_sound.stream=preload("res://audio/tank_cannon.wav") if heavy else preload("res://audio/lunar_hound_pulse.wav")
	cannon_sound.volume_db=-3.5 if heavy else -6.0
	cannon_sound.pitch_scale = randf_range(0.96, 1.04)
	cannon_sound.play()


signal directional_hit(origin: Vector3)

func apply_damage_from(amount: int, origin: Vector3) -> bool:
	var accepted := apply_damage(amount)
	if accepted: directional_hit.emit(origin)
	return accepted

func apply_damage(amount: int) -> bool:
	var vault_armor := int(get_meta("bunker_armor",0))
	if amount>0 and vault_armor>0: amount=maxi(1,roundi(amount*(1.0-(.05+.10*vault_armor))))
	if amount > 0 and is_instance_valid(vehicle) and vehicle.get_meta("sealed", false):
		amount = maxi(1, roundi(amount * 0.55))
	if shielding and amount > 0 and hurt_cooldown <= 0.0 and health > 0 and not get_tree().paused:
		var coverage := minf(1.0, shield_charge / (amount * 2.8))
		shield_charge = maxf(0.0, shield_charge - amount * 2.8)
		shield_delay = 1.25 if shield_recovery>28.0 else 1.8
		shield_visual.scale = Vector3.ONE * 1.23
		shield_visual.hit()
		avatar.shield.hit()
		amount = maxi(1, roundi(amount * (1.0 - 0.8 * coverage)))
	return super.apply_damage(amount)


func update_air(delta: float, breathable: bool) -> void:
	if breathable:
		oxygen = minf(100.0, oxygen + delta * 20.0)
		asphyxia_timer = 0.0
		return
	oxygen = maxf(0.0, oxygen - delta * 0.72 * oxygen_efficiency)
	if oxygen > 0.0:
		return
	asphyxia_timer -= delta
	if asphyxia_timer <= 0.0 and super.apply_damage(10):
		asphyxia_timer = 1.2


func eat_ration() -> int:
	var recovered := mini(max_health - health, 30)
	if recovered > 0:
		health += recovered
		health_changed.emit(health, max_health)
	return recovered


func unlock_weapon(key: String) -> void:
	if not WEAPONS.has(key): return
	if not inventory.has(key):
		var profile: Dictionary = WEAPONS[key]
		inventory[key] = {"loaded": profile.capacity, "reserve": profile.rounds}
	equip(key)


func equip(key: String) -> void:
	if not WEAPONS.has(key) or not inventory.has(key) or equipped == key:
		return
	if not equipped.is_empty():
		inventory[equipped] = {"loaded": weapon.ammo, "reserve": weapon.reserve_ammo}
	equipped = key
	var profile: Dictionary = WEAPONS[key]
	weapon.magazine_capacity = profile.capacity
	weapon.fire_interval = profile.interval
	weapon.reload_duration = profile.reload
	weapon.max_range = profile.range
	weapon.automatic = key == "smg"
	weapon.pellets = profile.pellets
	weapon.spread = 0.036 if key == "shotgun" else 0.0
	weapon.shot_sound.stream = PISTOL_SHOT if key == "pistol" else (load("res://audio/recorded_shotgun.wav") if key=="shotgun" else load("res://audio/recorded_rifle.wav"))
	weapon.shot_sound.volume_db = -3.0 if key=="shotgun" else (-4.0 if key=="pistol" else -6.0)
	weapon.reload_sound.volume_db = -9.0
	weapon.hit_sound.volume_db = -17.0
	weapon.recoil_strength = {"pistol":1.0,"shotgun":1.65,"smg":0.62}[key]
	weapon.campaign_effects = true
	weapon.reset_weapon()
	weapon.ammo = inventory[key].loaded
	weapon.reserve_ammo = inventory[key].reserve
	if is_instance_valid(gun_visual):
		gun_visual.hide()
		gun_visual.queue_free()
	gun_visual = WORLD.gun(weapon.model, key, true)
	weapon.reload_visual = gun_visual
	weapon.muzzle.position = gun_visual.muzzle
	weapon.aim_position.y = -gun_visual.sight_height
	weapon.visible = vehicle == null
	weapon.set_enabled(in_control and vehicle == null)
	avatar.equip(key)
	refresh_view()
	if is_instance_valid(loadout): loadout.primary_changed(key)


func add_ammo(key: String, rounds: int) -> void:
	if key == equipped:
		weapon.reserve_ammo += rounds
	elif inventory.has(key):
		inventory[key].reserve += rounds


func mount(ride: Node3D) -> void:
	vehicle = ride
	var parked := ride.get_node("ParkedCollision")
	parked.set_parked(false)
	global_position = ride.global_position + Vector3.UP * 0.025
	rotation.y = ride.rotation.y
	body_shape.set_deferred("disabled", true)
	for source in parked.parts:
		var part := CollisionShape3D.new()
		part.shape = source.shape
		part.position = source.position
		add_child(part)
		drive_colliders.append(part)
	head.position = vehicle.get_meta("eye_position")
	head.rotation.x = -0.07
	head.rotation.y = 0.0
	vehicle_speed = 0.0
	velocity = Vector3.ZERO
	vehicle_engine.play()
	weapon.hide()
	weapon.set_enabled(false)
	refresh_view()
	if is_instance_valid(loadout): loadout.sync_control()


func dismount(move_aside := true) -> bool:
	if vehicle == null:
		return true
	if move_aside and not find_exit():
		return false
	vehicle.get_node("ParkedCollision").set_parked(true)
	vehicle = null
	vehicle_speed = 0.0
	velocity = Vector3.ZERO
	capsule.height = STANDING_HEIGHT
	for part in drive_colliders:
		part.set_deferred("disabled", true)
		part.queue_free()
	drive_colliders.clear()
	body_shape.set_deferred("disabled", false)
	body_shape.position.y = STANDING_HEIGHT * 0.5
	head.position = Vector3(0, STANDING_HEIGHT - EYE_OFFSET, 0)
	head.rotation.x = 0.0
	head.rotation.y = 0.0
	vehicle_engine.stop()
	weapon.show()
	weapon.set_enabled(in_control)
	refresh_view()
	if is_instance_valid(loadout): loadout.sync_control()
	return true


func using_third_person() -> bool:
	return third_person and vehicle==null


func set_third_person(enabled: bool) -> void:
	third_person = enabled and not (is_instance_valid(loadout) and loadout.active)
	refresh_view()


func refresh_view() -> void:
	if not is_instance_valid(avatar): return
	var active := using_third_person()
	weapon.model.visible = not active
	avatar.visible = active and not equipped.is_empty()
	weapon.world_muzzle = avatar.muzzle if active else null
	weapon.body_origin = head if active else null
	if not active:
		$Head/Camera3D.position = Vector3.ZERO
	# Camera movement is evaluated in physics, including the first frame after a cut.


func update_follow_camera(delta: float) -> void:
	if not using_third_person(): return
	var view: Camera3D = $Head/Camera3D
	var aiming: bool = weapon.wants_to_aim()
	shoulder_blend = lerpf(shoulder_blend,shoulder_side,1.0-exp(-delta*9.0))
	var origin := head.global_position
	if is_nan(camera_height) or absf(camera_height-origin.y)>1.0: camera_height = origin.y
	camera_height = lerpf(camera_height,origin.y,1.0-exp(-delta*14.0))
	var desired := Vector3(0.57*shoulder_blend,0.17,1.75 if aiming else 3.10)
	# Smooth small stair-height changes, then sweep the entire offset from the head.
	desired += head.global_basis.inverse()*Vector3.UP*clampf(camera_height-origin.y,-0.22,0.22)
	var travel := head.global_basis*desired
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = camera_probe
	query.transform = Transform3D(Basis.IDENTITY,origin)
	query.motion = travel
	query.collision_mask = 9
	query.exclude = [get_rid()]
	var sweep := space.cast_motion(query)
	var allowed := sweep[0] if sweep.size()>0 else 1.0
	var ray := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+travel,9,[get_rid()]))
	if not ray.is_empty():
		allowed = minf(allowed,maxf(0.0,(origin.distance_to(ray.position)-0.24)/travel.length()))
	var next := desired*maxf(0.0,allowed-0.015)
	# Retract immediately; ease only the return so walls never catch the camera.
	var distance := minf(next.length(),lerpf(view.position.length(),next.length(),1.0-exp(-delta*12.0)))
	view.position = next.normalized()*distance
	avatar.visible = not equipped.is_empty() and view.position.length()>0.82
	weapon.model.visible = not avatar.visible
	weapon.world_muzzle = avatar.muzzle if avatar.visible else null
	var aim := space.intersect_ray(PhysicsRayQueryParameters3D.create(view.global_position,view.global_position-view.global_basis.z*150.0,13,[get_rid()]))
	var target: Vector3 = aim.get("position",view.global_position-view.global_basis.z*150.0)
	avatar.animate(self,delta,target)


func find_exit() -> bool:
	var space := get_world_3d().direct_space_state
	var parked := vehicle.get_node("ParkedCollision") as StaticBody3D
	var dimensions: Vector2 = parked.footprint
	var exceptions: Array[RID] = [get_rid(), parked.get_rid()]
	for side in [global_basis.x, -global_basis.x, global_basis.z]:
		var span := dimensions.y if absf(side.dot(global_basis.z)) > 0.5 else dimensions.x
		var adjacent: Vector3 = global_position + side * (span + 0.73)
		var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(adjacent + Vector3.UP * 0.9, adjacent - Vector3.UP * 1.4, 1, exceptions))
		if floor_hit.is_empty() or floor_hit.normal.y < 0.7:
			continue
		var landing: Vector3 = floor_hit.position + Vector3.UP * 0.04
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = standing_probe
		query.collision_mask = collision_mask
		query.exclude = exceptions
		query.transform = Transform3D(Basis.IDENTITY, landing + Vector3.UP * STANDING_HEIGHT * 0.5)
		var free_landing := space.intersect_shape(query, 1).is_empty()
		var center := global_position + Vector3.UP * (STANDING_HEIGHT * 0.5 + 0.12)
		query.motion = query.transform.origin - center
		query.transform.origin = center
		var sweep := space.cast_motion(query)
		if free_landing and sweep[0] >= 0.99:
			global_position = landing
			reset_physics_interpolation()
			return true
	return false


func try_turn(heading: float) -> void:
	var transform := Transform3D(Basis(Vector3.UP, heading), global_position + Vector3.UP * 0.06)
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.collision_mask = collision_mask
	var parked := vehicle.get_node("ParkedCollision") as StaticBody3D
	query.exclude = [get_rid(), parked.get_rid()]
	for part in drive_colliders:
		query.shape = part.shape
		query.transform = transform * part.transform
		if not space.intersect_shape(query, 1).is_empty():
			return
	rotation.y = heading


func drive(delta: float) -> void:
	hurt_cooldown = maxf(0.0, hurt_cooldown - delta)
	var steer := Input.get_axis("move_left", "move_right")
	var throttle := Input.get_axis("move_back", "move_forward")
	var top_speed: float = vehicle.get_meta("top_speed")
	var acceleration_rate: float = vehicle.get_meta("acceleration")
	if vehicle.get_meta("motorcycle", false):
		var boost_requested := throttle > 0.0 and Input.is_action_pressed("sprint")
		if boost_requested and bike_boost > 0.0:
			bike_boost = maxf(0.0, bike_boost - delta / 2.8)
			top_speed *= 1.28
			acceleration_rate *= 1.55
		elif not boost_requested:
			bike_boost = minf(1.0, bike_boost + delta / 5.0)
	var speed_goal := throttle * (top_speed if throttle >= 0.0 else 6.0)
	if signf(speed_goal) != signf(vehicle_speed):
		acceleration_rate *= 1.65
	vehicle_speed = move_toward(vehicle_speed, speed_goal, delta * acceleration_rate)
	if absf(vehicle_speed) > 0.3 and not is_zero_approx(steer):
		try_turn(rotation.y - steer * delta * float(vehicle.get_meta("turn_rate")) * signf(vehicle_speed))
	var travel := -global_basis.z * vehicle_speed
	velocity.x = travel.x
	velocity.z = travel.z
	# Keep horizontal motion free of downward pushes on a flat contact.
	velocity.y = 0.0 if is_on_floor() else velocity.y + movement_gravity().y * delta
	if vehicle.get_meta("sealed",false): push_vehicle_enemies(travel*delta)
	move_and_slide()
	apply_floor_snap()
	if is_on_wall():
		vehicle_speed *= 0.4
	if global_position.y < -29:
		global_transform = spawn_transform
		vehicle_speed = 0
	vehicle.global_position = global_position
	vehicle.rotation.y = rotation.y
	vehicle_engine.pitch_scale = 0.75 + absf(vehicle_speed) / top_speed * 0.75
	for wheel in vehicle.get_meta("wheels"):
		wheel.rotate_x(-vehicle_speed * delta / float(vehicle.get_meta("wheel_radius")))

func push_vehicle_enemies(motion: Vector3) -> void:
	if motion.length_squared()<.000001: return
	var pushed: Dictionary={}
	var space:=get_world_3d().direct_space_state
	for part in drive_colliders:
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=part.shape;query.margin=.07
		query.transform=global_transform*part.transform
		query.transform.origin+=motion
		query.collision_mask=8;query.exclude=[get_rid()]
		for hit in space.intersect_shape(query,16):
			var enemy: Object=hit.collider
			if not enemy is CharacterBody3D or not enemy.has_method("receive_hit_at") or pushed.has(enemy): continue
			pushed[enemy]=true
			# Only moving tracks crush. A stationary hull never deals contact damage.
			# Check scenery first so overlapping probes cannot crush through a wall.
			var contact: Vector3 = enemy.global_position + Vector3.UP * 0.65
			var obstruction := space.intersect_ray(PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.65, contact, 1, [get_rid()]))
			if not obstruction.is_empty(): continue
			if absf(vehicle_speed) >= 2.0:
				enemy.receive_hit_at(contact, -motion.normalized(), motion.normalized(), 1000000)
				continue
			# Move the enemy through physics: a wall can stop it, never teleport through it.
			enemy.move_and_collide(motion*1.25+motion.normalized()*.025)
