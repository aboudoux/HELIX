extends CharacterBody3D

signal destroyed(enemy: CharacterBody3D)

const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const BOLT := preload("res://scenes/hound_bolt.tscn")
const IMPACT := preload("res://scripts/drone_debris.gd")
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const FINISH := preload("res://missions/lunar_escape/finishes.gd")
const COLLISION := preload("res://scripts/actor_collision.gd")
const REACTION := preload("res://scripts/hit_reaction.gd")
const WRECK := preload("res://scripts/drone_wreck.gd")
const LEG := preload("res://missions/lunar_escape/spider_leg.gd")
const DAMAGE := preload("res://missions/lunar_escape/damage_details.gd")

var pilot: CharacterBody3D
var lane: float
var floor_level := 0.0
var left_wall := -13.31
var right_wall := 13.31
var offset: float
var elapsed := 0.0
var cooldown := 2.6
var health := 5
var max_health := 5
var move_speed := 3.25
var projectile_damage := 9
var projectile_speed := 20.0
var fire_interval := 1.6
var charge_duration := 0.52
var legs: Array[Node3D] = []
var visual: Node3D
var eye: MeshInstance3D
var warning: MeshInstance3D
var locked_target := Vector3.ZERO
var charging := false
var route: PackedVector3Array
var route_length := 0.0
var walk_direction := 1.0
var blocked_time := 0.0
var recoil := REACTION.new()
var attack_sound: AudioStreamPlayer3D
var charge_sound: AudioStreamPlayer3D
var leg_sound: AudioStreamPlayer3D
var impact_sound: AudioStreamPlayer3D
var distance_since_step := 0.0
var gait := 0.0
var mandibles: Array[Node3D] = []
var damaged_legs: Array[int] = []
var armor := DAMAGE.new()
var ambush_armed := false
var ambush_warning := 0.0


func _ready() -> void:
	max_health = health
	collision_layer = 8
	collision_mask = 3
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	COLLISION.add_box(self, Vector3(0.95, 0.48, 1.28), Vector3(0, 0.065, 0.025))
	COLLISION.add_box(self, Vector3(1.76, 0.33, 0.74), Vector3(0, -0.01, -0.03))
	visual = Node3D.new()
	visual.name = "Visual"
	visual.set_meta("wreck_geometry", "araignee_helios_articulee_v2")
	add_child(visual)
	var shell := FINISH.create(Color("b6b9a6"), 0.58, 0.38, 0.30)
	var dark := FINISH.create(Color("252e33"),0.78,0.43,0.24)
	# Exposed chassis, overlapping carapace, rear cooling vanes and six optics.
	KIT.bevel(visual,Vector3(0,0.015,0.02),Vector3(0.67,0.25,1.04),0.10,dark)
	armor.build(visual,Vector3(0,0.09,0.22),0.34,0.65)
	for side in [-1.0,1.0]:
		for i in range(3):
			var plate := KIT.bevel(visual,Vector3(side*(0.20-i*0.025),0.18,0.02+i*0.20),Vector3(0.36-i*0.035,0.13,0.29),0.04,shell)
			plate.rotation = Vector3(-0.12,side*0.13,side*-0.30)
			KIT.bevel(visual,Vector3(side*0.34,0.018,0.11+i*0.12),Vector3(0.026,0.075,0.052),0.008,WORLD.AMBER)
		for i in range(4):
			KIT.bevel(visual,Vector3(side*0.11,0.269,0.24+i*0.058),Vector3(0.13,0.018,0.025),0.005,dark)
	KIT.bevel(visual,Vector3(0,0.10,-0.38),Vector3(0.62,0.20,0.35),0.065,shell)
	KIT.bevel(visual,Vector3(0,0.045,-0.55),Vector3(0.50,0.17,0.08),0.025,dark)
	eye = WORLD.ball(visual,Vector3(0,0.07,-0.603),Vector3(0.095,0.095,0.05),WORLD.RED)
	for side in [-1.0,1.0]:
		for i in range(2):
			var p := Vector3(side*(0.105+i*0.09),0.07+i*0.037,-0.592+i*0.018)
			WORLD.ball(visual,p,Vector3.ONE*(0.078-i*0.013),WORLD.RED)
		var jaw := Node3D.new()
		jaw.position = Vector3(side*0.23,-0.06,-0.47)
		visual.add_child(jaw)
		KIT.rod(jaw,Vector3.ZERO,Vector3(side*0.075,-0.025,-0.20),0.038,WORLD.STEEL)
		KIT.rod(jaw,Vector3(side*0.075,-0.025,-0.20),Vector3(side*0.015,-0.09,-0.29),0.027,dark)
		mandibles.append(jaw)
	KIT.rod(visual,Vector3(0,-0.08,-0.28),Vector3(0,-0.08,-0.64),0.065,dark)
	WORLD.ball(visual,Vector3(0,-0.08,-0.65),Vector3(0.055,0.055,0.025),WORLD.AMBER)
	warning = WORLD.cylinder(self, Vector3.ZERO, 0.018, 0.018, 1.0, WORLD.RED)
	warning.hide()
	for side in [-1.0, 1.0]:
		for joint in range(4):
			var leg := LEG.new()
			visual.add_child(leg)
			leg.build(joint,side,shell)
			legs.append(leg)
	route = PackedVector3Array([
		Vector3(left_wall, floor_level + 0.58, lane),
		Vector3(left_wall, floor_level + 3.67, lane - 2.0),
		Vector3(left_wall + 0.83, floor_level + 4.02, lane - 2.8),
		Vector3(right_wall - 0.83, floor_level + 4.02, lane - 2.8),
		Vector3(right_wall, floor_level + 3.67, lane - 2.0),
		Vector3(right_wall, floor_level + 0.58, lane),
	])
	for index in range(route.size() - 1):
		route_length += route[index].distance_to(route[index + 1])
	update_route(0.0)
	attack_sound = spatial_cue("AttackSound", preload("res://audio/lunar_spider_pulse.wav"), -7.5, 6.0)
	charge_sound = spatial_cue("ChargeSound", preload("res://audio/hound_charge.wav"), -11.0, 5.0)
	charge_sound.pitch_scale = charge_sound.stream.get_length() / charge_duration
	leg_sound = spatial_cue("LegSound", preload("res://audio/lunar_spider_click.wav"), -13.0, 4.0)
	impact_sound = spatial_cue("ImpactSound", preload("res://audio/lunar_armor_hit.wav"), -8.5, 5.0)


func spatial_cue(cue_name: String, stream: AudioStream, volume: float, reach: float) -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	sound.name = cue_name
	sound.stream = stream
	sound.volume_db = volume
	sound.unit_size = reach
	sound.max_distance = 30.0
	add_child(sound)
	return sound


func _physics_process(delta: float) -> void:
	var escorts := get_tree().current_scene.get_node_or_null("EscortSquad")
	if escorts!=null: pilot = escorts.pick_target(self,pilot)
	if ambush_armed:
		velocity = Vector3.ZERO
		var line := PhysicsRayQueryParameters3D.create(eye.global_position,pilot.get_aim_point(),19,[get_rid()])
		var seen := get_world_3d().direct_space_state.intersect_ray(line)
		if global_position.distance_to(pilot.global_position)<12.0 and seen.get("collider")==pilot:
			ambush_armed = false
			ambush_warning = 0.85
			charge_sound.play()
		return
	if ambush_warning>0.0:
		ambush_warning = maxf(0.0,ambush_warning-delta)
		eye.scale = Vector3.ONE*(1.0+0.25*sin(ambush_warning*25))
		cooldown = 0.2
		return
	eye.scale = Vector3.ONE
	var advance := delta * walk_direction * (0.25 if charging else 1.0)
	elapsed += advance
	var start := global_position
	if update_route(delta):
		elapsed -= advance
		blocked_time += delta
		if blocked_time >= 0.45:
			walk_direction *= -1.0
			blocked_time = 0.0
	else:
		blocked_time = 0.0
	velocity = (global_position - start) / delta
	distance_since_step += global_position.distance_to(start)
	if distance_since_step >= 0.66:
		distance_since_step = fmod(distance_since_step, 0.66)
		var overhead := global_basis.y.y < -0.65
		leg_sound.volume_db = -7.0 if overhead else -13.0
		leg_sound.pitch_scale = randf_range(0.89, 1.13) * (0.88 if overhead else 1.0)
		leg_sound.play()
	gait += global_position.distance_to(start)/0.70
	var anticipation := 1.0-clampf(cooldown/charge_duration,0,1) if charging else 0.0
	recoil.apply(visual, Vector3(0,sin(gait*TAU*2)*0.018-anticipation*0.055,0), delta)
	for leg in legs:
		leg.step(self,gait)
	for i in range(mandibles.size()):
		mandibles[i].rotation.y = (1 if i==0 else -1)*(0.10+anticipation*0.38)
	if pilot.health <= 0:
		return
	cooldown = maxf(0.0, cooldown - delta)
	var from := eye.global_position
	var target: Vector3 = pilot.get_aim_point()
	if charging:
		var line := locked_target - from
		warning.global_position = from + line * 0.5
		warning.global_basis = Basis(Quaternion(Vector3.UP, line.normalized()))
		(warning.mesh as CylinderMesh).height = maxf(line.length(), 0.01)
		warning.show()
		if cooldown > 0.0:
			return
		var bolt := BOLT.instantiate()
		bolt.damage = projectile_damage
		bolt.speed = projectile_speed
		get_tree().current_scene.get_node("Projectiles").add_child(bolt)
		bolt.launch(from, line.normalized(), get_rid())
		attack_sound.play()
		cooldown = fire_interval
		charging = false
		warning.hide()
		return
	if from.distance_to(target) > 22.0:
		return
	var query := PhysicsRayQueryParameters3D.create(from, target, 19, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if cooldown <= 0 and hit.get("collider") == pilot:
		locked_target = target
		charging = true
		cooldown = charge_duration
		charge_sound.play()


func update_route(delta: float) -> bool:
	# Chaque point est décalé de la surface. La normale oriente les pattes vers la paroi.
	var normals := [Vector3.RIGHT, Vector3.RIGHT, Vector3.DOWN, Vector3.DOWN, Vector3.LEFT, Vector3.LEFT]
	var travel := fposmod(elapsed * move_speed + offset, route_length * 2.0)
	var returning := travel >= route_length
	var blocked := false
	if returning:
		travel = route_length * 2.0 - travel
	for index in range(route.size() - 1):
		var segment := route[index].distance_to(route[index + 1])
		if travel > segment and index < route.size() - 2:
			travel -= segment
			continue
		var weight := clampf(travel / segment, 0.0, 1.0)
		var target := route[index].lerp(route[index + 1], weight)
		var normal: Vector3 = normals[index].slerp(normals[index + 1], weight).normalized()
		var forward := route[index].direction_to(route[index + 1]) * (-1.0 if returning else 1.0) * walk_direction
		forward = (forward - normal * forward.dot(normal)).normalized()
		var surface_basis := Basis.looking_at(forward, normal)
		if delta == 0:
			global_position = target
			global_basis = surface_basis
		else:
			blocked = move_and_collide((target - global_position).limit_length(move_speed * delta * 1.20)) != null
			COLLISION.try_turn(self, global_basis.slerp(surface_basis, minf(delta * 12, 1.0)).orthonormalized())
		break
	return blocked


func receive_hit_at(point: Vector3, normal: Vector3, incoming: Vector3, damage: int = 1) -> bool:
	if health <= 0:
		return false
	health = maxi(0, health - damage)
	ambush_armed = false
	armor.hit(self,point,float(health)/max_health,incoming)
	# The outer collision volume covers the knee assemblies; precision shots
	# disable at most two legs and never stack an unlimited speed penalty.
	var local_hit := to_local(point)
	if health>0 and absf(local_hit.x)>0.50 and damaged_legs.size()<2:
		var closest := -1
		var nearest := INF
		for i in range(legs.size()):
			var distance: float = legs[i].knee_joint.global_position.distance_squared_to(point)
			if not i in damaged_legs and distance<nearest:
				closest = i
				nearest = distance
		if closest>=0:
			damaged_legs.append(closest)
			legs[closest].damaged = true
			move_speed *= 0.78
			DAMAGE.shed(self,legs[closest].upper.get_child(1),incoming)
	recoil.kick(self, incoming, 0.15)
	var sparks := IMPACT.new()
	get_tree().current_scene.get_node("Effects").add_child(sparks)
	sparks.setup(point + normal * 0.025, normal, incoming, false)
	if health <= 0:
		set_deferred("collision_layer", 0)
		var wreck := WRECK.new()
		wreck.name = "Epave_Araignee"
		get_tree().current_scene.get_node("Wrecks").add_child(wreck)
		wreck.setup(visual, velocity, false)
		wreck.crash_sound.volume_db += 2.5
		wreck.mass = 42.0
		wreck.collapse_robot(0.11, 0.91)
		hide()
		destroyed.emit(self)
		queue_free()
	else:
		impact_sound.play()
	return true


func arm_ambush() -> void:
	offset = route_length*0.5
	elapsed = 0.0
	update_route(0.0)
	for leg in legs:
		leg.initialized = false
		leg.step(self,0.60)
	ambush_armed = true
