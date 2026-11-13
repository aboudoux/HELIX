extends CharacterBody3D

signal destroyed(drone: CharacterBody3D)

const WRECK := preload("res://scripts/drone_wreck.gd")
const IMPACT := preload("res://scripts/drone_debris.gd")
const COLLISION := preload("res://scripts/actor_collision.gd")
const REACTION := preload("res://scripts/hit_reaction.gd")
@export var campaign_combat := false
@export var drone_name: String = "SENTINELLE 01"
@export var max_health: int = 3
@export var move_speed: float = 3.0
@export var attack_enabled: bool = true
@export var fire_interval: float = 2.2
@export var charge_duration: float = 0.6
@export var initial_delay: float = 3.0
@export var orbit_direction: float = 1.0
@onready var director: Node3D = get_parent()
@onready var player: CharacterBody3D = get_parent().get_parent().get_node("Player")
@onready var hull: Node3D = $Hull
@onready var hit_shape: CollisionShape3D = $HitShape
@onready var muzzle: Marker3D = $Hull/Muzzle
@onready var warning: MeshInstance3D = $Warning
@onready var state_label: Label3D = $Hull/State
@onready var health_fill: MeshInstance3D = $Hull/HealthFill
@onready var impact_sound: AudioStreamPlayer3D = $ImpactSound
@onready var rotor_sound: AudioStreamPlayer3D = $RotorSound
@onready var rotors: Node3D = $Hull/VisualModel.find_child("Rotors", true, false)
var rotor_blades: Array[Node3D] = []
var health: int = 3
var alive: bool = true
var spawn_transform: Transform3D
var cooldown: float = 0.0
var charge_remaining: float = 0.0
var locked_aim := Vector3.ZERO
var path := PackedVector3Array()
var path_index: int = 0
var path_refresh: float = 0.0
var elapsed: float = 0.0
var hurt_flash: float = 0.0
var shots_fired: int = 0
var base_fire_interval: float
var base_initial_delay: float
var wreck: RigidBody3D
var tactics := preload("res://scripts/enemy_tactics.gd").new()
var extra_colliders: Array[CollisionShape3D] = []
var recoil := REACTION.new()
var damage_details := preload("res://missions/lunar_escape/damage_details.gd").new()
var blocked_time := 0.0
var charge_light: OmniLight3D
var charge_sound: AudioStreamPlayer3D
var patrol_points := PackedVector3Array()
var patrol_index := 0
var patrol_alerted := false
var bank := Vector2.ZERO
var damaged_rotors: Dictionary = {}


func _ready() -> void:
	base_fire_interval = fire_interval
	base_initial_delay = initial_delay
	spawn_transform = global_transform
	$Hull/NameTag.text = drone_name
	warning.mesh = warning.mesh.duplicate()
	for rotor in rotors.get_children():
		rotor_blades.append(rotor.find_child("Blades*", false, false))
		if campaign_combat:
			var disc := CylinderShape3D.new()
			disc.radius = 0.28
			disc.height = 0.16
			extra_colliders.append(COLLISION.add_shape(self, disc, to_local(rotor.global_position)))
	if campaign_combat:
		$Hull/NameTag.hide()
		state_label.hide()
		$Hull/HealthBack.hide()
		health_fill.hide()
		charge_light = OmniLight3D.new()
		charge_light.light_color = Color(1.0, 0.28, 0.08)
		charge_light.omni_range = 1.1
		charge_light.hide()
		muzzle.add_child(charge_light)
		charge_sound = AudioStreamPlayer3D.new()
		charge_sound.stream = preload("res://audio/hound_charge.wav")
		charge_sound.volume_db = -16.0
		charge_sound.unit_size = 3.0
		charge_sound.max_distance = 16.0
		muzzle.add_child(charge_sound)
		$ShotSound.stream = preload("res://audio/lunar_drone_pulse.wav")
		$ShotSound.volume_db = -7.5
		$ShotSound.unit_size = 6.0
		impact_sound.stream = preload("res://audio/lunar_armor_hit.wav")
		impact_sound.volume_db = -8.5
		rotor_sound.base_volume += 3.0
		var fuselage := BoxShape3D.new()
		fuselage.size = Vector3(0.82, 0.58, 0.91)
		hit_shape.shape = fuselage
		damage_details.build($Hull/VisualModel,Vector3(0,0.02,0),0.40,0.65)
	reset_drone()


func configure_difficulty(profile: Dictionary) -> void:
	max_health = profile.health
	health = max_health
	move_speed = profile.move_speed
	fire_interval = base_fire_interval * profile.fire_scale
	initial_delay = base_initial_delay * profile.delay_scale
	charge_duration = profile.charge
	cooldown = initial_delay
	health_fill.scale.x = 1.0


func _physics_process(delta: float) -> void:
	var escorts := get_tree().current_scene.get_node_or_null("EscortSquad")
	if campaign_combat and escorts!=null: player = escorts.pick_target(self,player)
	if not alive or not director.navigation_ready or player.health <= 0:
		return
	cooldown = maxf(0.0, cooldown - delta)
	path_refresh -= delta
	var offset := player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	var sees_player := has_line_of_sight()
	if not patrol_points.is_empty():
		update_patrol(delta, sees_player and distance < 16.0, offset)
		return
	tactics.observe(self,delta,sees_player)
	var desired := Vector3.ZERO
	if path_refresh <= 0.0:
		path = director.flight_path(global_position,tactics.choose_destination(self,false,9.0))
		path_index = 1 if path.size()>1 else 0
		path_refresh = .35
	while path_index < path.size() and global_position.distance_to(path[path_index]) < .35:
		path_index += 1
	if path_index < path.size():
		desired = global_position.direction_to(path[path_index])
	# Un petit écartement empêche les drones de rester empilés sur le même chemin.
	for other in director.get_children():
		if other != self and other.alive:
			var away: Vector3 = global_position - other.global_position
			away.y = 0.0
			if away.length() < 2.3 and away.length() > 0.01:
				desired += away.normalized() * 0.8
	if desired.length() > 1.0:
		desired = desired.normalized()
	velocity = velocity.move_toward(desired * move_speed, delta * 8.0)
	velocity.y = (director.flight_height - global_position.y) * 5.0
	move_and_slide()
	if campaign_combat and move_speed>0:
		blocked_time = blocked_time+delta if desired.length()>0.2 and get_position_delta().length()<delta*0.3 else 0.0
		if blocked_time>0.7:
			tactics.react_to_hit()
			path_refresh = 0.0
			director.navigation_ready = false
			blocked_time = 0.0
	var facing: Vector3 = locked_aim-global_position if charge_remaining>0 else (offset if sees_player else tactics.last_known_position-global_position)
	if facing.length() > .01:
		var heading := lerp_angle(rotation.y, atan2(-facing.x, -facing.z), minf(delta * 6, 1))
		if campaign_combat:
			COLLISION.try_turn(self, Basis(Vector3.UP, heading))
		else:
			rotation.y = heading
	update_attack(delta, sees_player and distance < 25.0)


func update_patrol(delta: float, sees_player: bool, offset: Vector3) -> void:
	var waypoint := patrol_points[patrol_index]
	if global_position.distance_to(waypoint) < 0.3:
		patrol_index = (patrol_index + 1) % patrol_points.size()
		waypoint = patrol_points[patrol_index]
	var course := waypoint - global_position
	course.y = 0.0
	if not patrol_alerted and sees_player and (-global_basis.z).dot(offset.normalized()) > 0.2:
		patrol_alerted = true
		cooldown = maxf(cooldown, 1.4)
	var engaged := patrol_alerted and sees_player
	var facing := offset if engaged else course
	if charge_remaining > 0 and engaged:
		facing = locked_aim - global_position
	if facing.length_squared() > 0.01:
		var heading := lerp_angle(rotation.y, atan2(-facing.x, -facing.z), 1.0-exp(-delta*5.0))
		COLLISION.try_turn(self, Basis(Vector3.UP, heading))
	var speed := (0.7 if engaged else 1.5) * (0.7 if not damaged_rotors.is_empty() else 1.0)
	var desired := course.normalized() * speed if charge_remaining <= 0 else Vector3.ZERO
	velocity = velocity.move_toward(desired, delta * 4.0)
	velocity.y = (waypoint.y - global_position.y) * 4.0
	move_and_slide()
	update_attack(delta, engaged)


func has_line_of_sight() -> bool:
	var query := PhysicsRayQueryParameters3D.create(muzzle.global_position, player.get_aim_point(), 27, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == player


func receive_repair() -> void:
	if alive and health < max_health:
		health += 1
		if campaign_combat and is_instance_valid(damage_details.smoke): damage_details.smoke.emitting = float(health)/max_health<=0.5
		health_fill.scale.x = float(health) / max_health


func update_attack(delta: float, can_see: bool) -> void:
	if not attack_enabled or not can_see:
		charge_remaining = 0.0
		warning.hide()
		if charge_sound != null: charge_sound.stop()
		return
	if charge_remaining > 0.0:
		charge_remaining -= delta
		update_warning()
		if charge_remaining <= 0.0:
			director.spawn_bolt(muzzle.global_position, muzzle.global_position.direction_to(locked_aim), get_rid())
			shots_fired += 1
			$ShotSound.pitch_scale = randf_range(0.96, 1.04)
			$ShotSound.play()
			cooldown = fire_interval
			warning.hide()
			if charge_sound != null: charge_sound.stop()
	elif cooldown <= 0.0:
		locked_aim = player.get_aim_point()
		charge_remaining = charge_duration
		if charge_sound != null: charge_sound.play()
		update_warning()


func update_warning() -> void:
	if charge_light != null:
		return
	warning.show()
	var line := locked_aim - muzzle.global_position
	(warning.mesh as CylinderMesh).height = maxf(line.length(), 0.01)
	warning.global_position = (locked_aim + muzzle.global_position) * 0.5
	warning.global_basis = Basis(Quaternion(Vector3.UP, line.normalized()))


func _process(delta: float) -> void:
	if not alive:
		return
	elapsed += delta
	hurt_flash = maxf(0.0, hurt_flash - delta)
	var hover := sin(elapsed * 3.5) * 0.065
	if campaign_combat:
		recoil.apply(hull, Vector3.UP * hover, delta)
		var local_speed := global_basis.inverse() * velocity
		var flight_tilt := Vector2(clampf(local_speed.z*.065, -.17, .17), clampf(-local_speed.x*.11, -.24, .24))
		bank = bank.lerp(flight_tilt, 1.0-exp(-delta*7.0))
		hull.rotation.x += bank.x
		hull.rotation.z += bank.y
		if not damaged_rotors.is_empty():
			hull.rotation.z += sin(elapsed*18.0)*0.085
	else:
		hull.position.y = hover
	for index in rotor_blades.size():
		var rotor_speed := 10.0 if damaged_rotors.has(index) else 32.0
		rotor_blades[index].rotate_y(delta * rotor_speed * orbit_direction)
	if charge_light != null:
		charge_light.visible = charge_remaining > 0.0
		if charge_light.visible:
			var progress := 1.0 - clampf(charge_remaining / charge_duration, 0.0, 1.0)
			charge_light.light_energy = lerpf(0.45, 1.65, progress)
	if state_label.visible:
		state_label.text = "VERROUILLAGE" if charge_remaining > 0.0 else ("IMPACT" if hurt_flash > 0.0 else "HOSTILE")
		state_label.modulate = Color(1.0, 0.45, 0.2) if charge_remaining > 0.0 else Color(1.0, 0.25, 0.2)


func receive_hit() -> bool:
	return receive_hit_at(global_position-global_basis.z*.75,-global_basis.z,global_basis.z)


func receive_hit_at(point: Vector3, normal: Vector3, incoming: Vector3, damage: int = 1) -> bool:
	if not alive or get_tree().paused:
		return false
	if campaign_combat: damage = preload("res://missions/lunar_escape/enemy_roles.gd").resolve(self,point,incoming,damage)
	var impact := IMPACT.new()
	get_tree().current_scene.get_node("Effects").add_child(impact)
	impact.setup(point+normal*.025,normal,incoming,false,velocity)
	impact_sound.pitch_scale = randf_range(0.96, 1.04)
	impact_sound.play()
	health = maxi(0, health - damage)
	if campaign_combat:
		var rotor_hit := -1
		for index in rotor_blades.size():
			var local_hit: Vector3 = rotor_blades[index].get_parent_node_3d().to_local(point)
			if Vector2(local_hit.x, local_hit.z).length() < .31 and absf(local_hit.y) < .18:
				rotor_hit = index
				damaged_rotors[index] = true
				break
		var push := incoming if rotor_hit == -1 else incoming + global_basis.x * signf(to_local(point).x)
		recoil.kick(self, push, 0.18 if rotor_hit == -1 else 0.26)
		damage_details.hit(self,point,float(health)/max_health,incoming)
		if not patrol_points.is_empty() and not patrol_alerted:
			patrol_alerted = true
			cooldown = maxf(cooldown, 1.1)
	hurt_flash = 0.18
	tactics.react_to_hit()
	path_refresh = 0
	health_fill.scale.x = maxf(float(health) / max_health, 0.001)
	if health <= 0:
		var wreck_velocity := velocity
		if campaign_combat: wreck_velocity += incoming.normalized() * 1.7
		alive = false
		rotor_sound.silence()
		velocity = Vector3.ZERO
		charge_remaining = 0.0
		hit_shape.set_deferred("disabled", true)
		COLLISION.set_enabled(extra_colliders, false)
		$ShotSound.stop()
		if charge_sound != null: charge_sound.stop()
		wreck = WRECK.new()
		wreck.name = "Epave_"+name
		get_tree().current_scene.get_node("Wrecks").add_child(wreck)
		var heavy: bool = is_in_group("boss")
		var spin: float = get("barrel_speed") if heavy else 0.0
		wreck.setup($Hull/VisualModel,wreck_velocity,heavy,spin)
		wreck.explosive = campaign_combat
		if campaign_combat:
			wreck.crash_sound.volume_db += 4.0
		hull.hide()
		warning.hide()
		destroyed.emit(self)
	return true


func reset_drone() -> void:
	if campaign_combat: preload("res://missions/lunar_escape/enemy_roles.gd").reset(self)
	damage_details.reset()
	if is_instance_valid(wreck) and not wreck.is_queued_for_deletion(): wreck.queue_free()
	wreck = null
	rotor_sound.silence()
	global_transform = spawn_transform
	tactics.reset(player.global_position,orbit_direction)
	velocity = Vector3.ZERO
	health = max_health
	alive = true
	cooldown = initial_delay
	charge_remaining = 0.0
	if charge_light != null:
		charge_light.hide()
		charge_sound.stop()
	patrol_index = 0
	patrol_alerted = false
	bank = Vector2.ZERO
	damaged_rotors.clear()
	path_refresh = 0.0
	path = PackedVector3Array()
	hurt_flash = 0.0
	recoil.reset()
	hull.rotation = Vector3.ZERO
	health_fill.scale.x = 1.0
	hit_shape.set_deferred("disabled", false)
	COLLISION.set_enabled(extra_colliders, true)
	hull.show()
	warning.hide()
	$ShotSound.stop()
	impact_sound.stop()
	reset_physics_interpolation()
