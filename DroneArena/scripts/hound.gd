extends CharacterBody3D
## Quadrupède au sol : poursuite, trot articulé, verrouillage puis double impulsion.

signal destroyed(enemy: CharacterBody3D)
const WRECK := preload("res://scripts/drone_wreck.gd")
const IMPACT := preload("res://scripts/drone_debris.gd")
const COLLISION := preload("res://scripts/actor_collision.gd")
const REACTION := preload("res://scripts/hit_reaction.gd")
@export var campaign_combat := false
@export var preferred_range: float = 7.0
@export var heavy_wreck: bool = false
@export var wreck_mass: float = 70.0
@export var drone_name: String = "LIMIER K-9"
@export var max_health: int = 3
@export var move_speed: float = 4.05
@export var attack_enabled: bool = true
@export var fire_interval: float = 2.8
@export var charge_duration: float = .85
@export var initial_delay: float = 4.2
@export var orbit_direction: float = 1.0
@onready var director: Node3D = get_parent()
@onready var player: CharacterBody3D = get_parent().get_parent().get_node("Player")
@onready var hull: Node3D = $Hull
@onready var visual: Node3D = $Hull/VisualModel
@onready var muzzle: Node3D = visual.find_child("LaserMuzzle",true,false)
@onready var turret: Node3D = visual.find_child("Turret",true,false)
@onready var hit_shape: CollisionShape3D = $HitShape
@onready var warning: MeshInstance3D = $Warning
@onready var health_fill: MeshInstance3D = $Hull/HealthFill
var hips: Array[Node3D] = []
var knees: Array[Node3D] = []
var health: int = 3
var alive: bool = true
var spawn_transform: Transform3D
var cooldown: float = 0.0
var charge_remaining: float = 0.0
var locked_aim := Vector3.ZERO
var shots_fired: int = 0
var path := PackedVector3Array()
var path_index: int = 0
var path_refresh: float = 0.0
var gait: float = 0.0
var burst_remaining: int = 0
var burst_time: float = 0.0
var stuck_time: float = 0.0
var base_fire_interval: float
var base_initial_delay: float
var wreck: RigidBody3D
var tactics := preload("res://scripts/enemy_tactics.gd").new()
var extra_colliders: Array[CollisionShape3D] = []
var recoil := REACTION.new()
var hurt_time := 0.0
var damage_details := preload("res://missions/lunar_escape/damage_details.gd").new()


func _ready() -> void:
	base_fire_interval = fire_interval
	base_initial_delay = initial_delay
	spawn_transform = global_transform
	$Hull/NameTag.text = drone_name
	warning.mesh = warning.mesh.duplicate()
	for part in ["FL","FR","RL","RR"]:
		hips.append(visual.find_child("Hip"+part,true,false))
		knees.append(visual.find_child("Knee"+part,true,false))
	if campaign_combat:
		damage_details.build(visual,Vector3(0,1.22,0.10),0.55,1.35)
		$ShotSound.stream = preload("res://audio/lunar_hound_pulse.wav")
		$ShotSound.volume_db = -7.5
		$ShotSound.unit_size = 6.0
		$ImpactSound.stream = preload("res://audio/lunar_armor_hit.wav")
		$ImpactSound.volume_db = -8.5
		$StepSound.stream = preload("res://audio/lunar_servo_step.wav")
		$StepSound.volume_db = -10.5
		$ChargeSound.volume_db = -9.0
		$ChargeSound.pitch_scale = $ChargeSound.stream.get_length() / charge_duration
		var armor := BoxShape3D.new()
		armor.size = Vector3(1.13, 1.14, 1.86)
		hit_shape.shape = armor
		hit_shape.position = Vector3(0, 1.06, 0.02)
		extra_colliders.append(COLLISION.add_box(self, Vector3(0.64, 0.66, 0.81), Vector3(0, 1.15, -1.00)))
		for hip in hips:
			var center := to_local(hip.global_position)
			extra_colliders.append(COLLISION.add_box(self, Vector3(0.34, 0.93, 0.52), Vector3(center.x, 0.49, center.z - 0.06)))
	reset_drone()


func configure_difficulty(profile: Dictionary) -> void:
	max_health = profile.health
	health = max_health
	move_speed = profile.move_speed*1.35
	fire_interval = base_fire_interval*profile.fire_scale
	initial_delay = base_initial_delay*profile.delay_scale
	charge_duration = profile.charge+.25
	$ChargeSound.pitch_scale = $ChargeSound.stream.get_length()/charge_duration
	cooldown = initial_delay
	health_fill.scale.x = 1.0


func has_line_of_sight() -> bool:
	var space := get_world_3d().direct_space_state
	# Le canon dorsal ne doit pas tirer au travers d'une paroi où il dépasse.
	var body_to_muzzle := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP, muzzle.global_position,11,[get_rid()])
	if not space.intersect_ray(body_to_muzzle).is_empty():
		return false
	var query := PhysicsRayQueryParameters3D.create(muzzle.global_position,player.get_aim_point(),27,[get_rid()])
	var hit := space.intersect_ray(query)
	return not hit.is_empty() and hit.collider == player


func _physics_process(delta: float) -> void:
	var escorts := get_tree().current_scene.get_node_or_null("EscortSquad")
	if campaign_combat and escorts!=null: player = escorts.pick_target(self,player)
	if not alive or not director.navigation_ready or player.health <= 0:
		return
	cooldown = maxf(0,cooldown-delta)
	path_refresh -= delta
	var offset := player.global_position-global_position
	offset.y = 0
	var sees := has_line_of_sight()
	tactics.observe(self,delta,sees)
	var desired := Vector3.ZERO
	if path_refresh <= 0:
		path = director.ground_path(global_position,tactics.choose_destination(self,true,preferred_range))
		path_index = 1 if path.size()>1 else 0
		path_refresh = .35
	while path_index < path.size() and Vector2(global_position.x-path[path_index].x,global_position.z-path[path_index].z).length() < .3:
		path_index += 1
	if path_index < path.size():
		desired = path[path_index]-global_position
		desired.y = 0
		desired = desired.normalized()
	if charge_remaining>0 or burst_remaining>0:
		desired = Vector3.ZERO
	velocity.x = move_toward(velocity.x,desired.x*move_speed,delta*12)
	velocity.z = move_toward(velocity.z,desired.z*move_speed,delta*12)
	velocity.y = 0 if is_on_floor() else velocity.y+get_gravity().y*delta
	move_and_slide()
	stuck_time = stuck_time+delta if not desired.is_zero_approx() and Vector2(velocity.x,velocity.z).length()<.2 else 0.0
	if stuck_time>.8:
		director.ground_navigation.ready = false
		stuck_time = 0
	var facing := desired if not sees else offset
	if charge_remaining>0 or burst_remaining>0:
		facing = locked_aim-global_position
	if facing.length()>.01:
		var heading := lerp_angle(rotation.y, atan2(-facing.x, -facing.z), minf(delta * 6, 1))
		if campaign_combat:
			COLLISION.try_turn(self, Basis(Vector3.UP, heading), 0.035)
		else:
			rotation.y = heading
	update_attack(delta,sees and offset.length()<28)
	var aim: Vector3 = locked_aim if charge_remaining>0 or burst_remaining>0 else player.get_aim_point()
	var direction: Vector3 = aim-turret.global_position
	turret.rotation.x = clampf(atan2(direction.y,Vector2(direction.x,direction.z).length()),-.45,.6)


func update_attack(delta: float, can_see: bool) -> void:
	if not attack_enabled or not can_see:
		charge_remaining = 0
		burst_remaining = 0
		warning.hide()
		$ChargeSound.stop()
		return
	if burst_remaining>0:
		burst_time -= delta
		update_warning()
		if burst_time<=0:
			director.spawn_hound_bolt(muzzle.global_position,muzzle.global_position.direction_to(locked_aim),get_rid())
			shots_fired += 1
			$ShotSound.play()
			burst_remaining -= 1
			burst_time = .22
			if burst_remaining==0:
				cooldown = fire_interval
				warning.hide()
	elif charge_remaining>0:
		charge_remaining = maxf(0,charge_remaining-delta)
		update_warning()
		if charge_remaining<=0:
			burst_remaining = 2
			burst_time = 0
	elif cooldown<=0:
		locked_aim = player.get_aim_point()
		charge_remaining = charge_duration
		$ChargeSound.play()
		update_warning()


func update_warning() -> void:
	var line := locked_aim-muzzle.global_position
	warning.show()
	(warning.mesh as CylinderMesh).height = maxf(line.length(),.01)
	warning.global_position = (locked_aim+muzzle.global_position)*.5
	warning.global_basis = Basis(Quaternion(Vector3.UP,line.normalized()))


func _process(delta: float) -> void:
	if not alive:
		return
	var speed := Vector2(velocity.x,velocity.z).length()
	gait += delta*speed*4.5
	var walking := clampf(speed/2,0,1)
	for i in range(4):
		var phase := gait+(PI if i in [1,2] else 0.0)
		hips[i].rotation.x = sin(phase)*.43*walking
		knees[i].rotation.x = maxf(0,-sin(phase))*.55*walking
	hull.position.y = absf(sin(gait))*.025*walking
	hurt_time = maxf(0.0, hurt_time - delta)
	if campaign_combat:
		recoil.apply(hull, Vector3.UP * hull.position.y, delta)
	$Hull/State.text = "IMPACT" if hurt_time > 0.0 else ("VISÉE LASER" if charge_remaining>0 or burst_remaining>0 else "POURSUITE")
	var step := int(gait/PI)
	if speed>1 and step != int(get_meta("step",-1)):
		set_meta("step",step)
		$StepSound.pitch_scale = randf_range(.9,1.1)
		$StepSound.play()


func receive_hit() -> bool:
	return receive_hit_at(global_position+Vector3.UP,-global_basis.z,global_basis.z)


func receive_hit_at(point: Vector3, normal: Vector3, incoming: Vector3, damage: int = 1) -> bool:
	if not alive or get_tree().paused:
		return false
	if campaign_combat: damage = preload("res://missions/lunar_escape/enemy_roles.gd").resolve(self,point,incoming,damage)
	var impact := IMPACT.new()
	get_tree().current_scene.get_node("Effects").add_child(impact)
	impact.setup(point+normal*.025,normal,incoming,false,velocity)
	$ImpactSound.play()
	$ImpactSound.pitch_scale = randf_range(0.88,1.12)
	health = maxi(0, health - damage)
	if campaign_combat:
		recoil.kick(self, incoming, 0.15)
		damage_details.hit(self,point,float(health)/max_health,incoming)
		hurt_time = 0.20
	tactics.react_to_hit()
	path_refresh = 0
	health_fill.scale.x = maxf(float(health)/max_health,.001)
	if health<=0:
		alive = false
		hit_shape.set_deferred("disabled",true)
		COLLISION.set_enabled(extra_colliders, false)
		warning.hide()
		for sound in [$ChargeSound,$ShotSound,$StepSound]: sound.stop()
		wreck = WRECK.new()
		wreck.name = "Epave_"+name
		get_tree().current_scene.get_node("Wrecks").add_child(wreck)
		wreck.setup(visual,velocity,heavy_wreck)
		wreck.mass = wreck_mass
		wreck.set_fall_gravity(1.0)
		wreck.add_to_group("hound_wrecks")
		if campaign_combat:
			wreck.crash_sound.volume_db += 2.5
			wreck.collapse_robot(1.13, 1.12)
		velocity = Vector3.ZERO
		hull.hide()
		director.ground_navigation.ready = false
		destroyed.emit(self)
	return true


func reset_drone() -> void:
	if campaign_combat: preload("res://missions/lunar_escape/enemy_roles.gd").reset(self)
	damage_details.reset()
	if is_instance_valid(wreck) and not wreck.is_queued_for_deletion(): wreck.queue_free()
	wreck = null
	global_transform = spawn_transform
	tactics.reset(player.global_position,orbit_direction)
	velocity = Vector3.ZERO
	health = max_health
	alive = true
	cooldown = initial_delay
	charge_remaining = 0
	burst_remaining = 0
	path_refresh = 0
	stuck_time = 0
	gait = 0
	set_meta("step",-1)
	path.clear()
	health_fill.scale.x = 1
	hit_shape.set_deferred("disabled",false)
	COLLISION.set_enabled(extra_colliders, true)
	hull.show()
	hull.position = Vector3.ZERO
	hull.rotation = Vector3.ZERO
	recoil.reset()
	hurt_time = 0.0
	turret.rotation = Vector3.ZERO
	for part in hips+knees: part.rotation = Vector3.ZERO
	for sound in [$ChargeSound,$ShotSound,$StepSound,$ImpactSound]: sound.stop()
	warning.hide()
	reset_physics_interpolation()
