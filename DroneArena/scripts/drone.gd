extends CharacterBody3D

signal destroyed(drone: CharacterBody3D)

const WRECK := preload("res://scripts/drone_wreck.gd")
const IMPACT := preload("res://scripts/drone_debris.gd")
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


func _ready() -> void:
	base_fire_interval = fire_interval
	base_initial_delay = initial_delay
	spawn_transform = global_transform
	$Hull/NameTag.text = drone_name
	warning.mesh = warning.mesh.duplicate()
	for rotor in rotors.get_children():
		rotor_blades.append(rotor.find_child("Blades*", false, false))
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
	if not alive or not director.navigation_ready or player.health <= 0:
		return
	cooldown = maxf(0.0, cooldown - delta)
	path_refresh -= delta
	var offset := player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	var sees_player := has_line_of_sight()
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
	var facing: Vector3 = locked_aim-global_position if charge_remaining>0 else (offset if sees_player else tactics.last_known_position-global_position)
	if facing.length() > .01:
		rotation.y = lerp_angle(rotation.y,atan2(-facing.x,-facing.z),minf(delta*6,1))
	update_attack(delta, sees_player and distance < 25.0)


func has_line_of_sight() -> bool:
	var query := PhysicsRayQueryParameters3D.create(muzzle.global_position, player.get_aim_point(), 11, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == player


func update_attack(delta: float, can_see: bool) -> void:
	if not attack_enabled or not can_see:
		charge_remaining = 0.0
		warning.hide()
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
	elif cooldown <= 0.0:
		locked_aim = player.get_aim_point()
		charge_remaining = charge_duration
		update_warning()


func update_warning() -> void:
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
	hull.position.y = sin(elapsed * 3.5) * 0.065
	for blades in rotor_blades:
		blades.rotate_y(delta * 32.0 * orbit_direction)
	state_label.text = "VERROUILLAGE" if charge_remaining > 0.0 else ("IMPACT" if hurt_flash > 0.0 else "HOSTILE")
	state_label.modulate = Color(1.0, 0.45, 0.2) if charge_remaining > 0.0 else Color(1.0, 0.25, 0.2)


func receive_hit() -> bool:
	return receive_hit_at(global_position-global_basis.z*.75,-global_basis.z,global_basis.z)


func receive_hit_at(point: Vector3, normal: Vector3, incoming: Vector3) -> bool:
	if not alive or get_tree().paused:
		return false
	var impact := IMPACT.new()
	get_tree().current_scene.get_node("Effects").add_child(impact)
	impact.setup(point+normal*.025,normal,incoming,false,velocity)
	impact_sound.pitch_scale = randf_range(0.96, 1.04)
	impact_sound.play()
	health -= 1
	hurt_flash = 0.18
	tactics.react_to_hit()
	path_refresh = 0
	health_fill.scale.x = maxf(float(health) / max_health, 0.001)
	if health <= 0:
		var wreck_velocity := velocity
		alive = false
		rotor_sound.silence()
		velocity = Vector3.ZERO
		charge_remaining = 0.0
		hit_shape.set_deferred("disabled", true)
		$ShotSound.stop()
		wreck = WRECK.new()
		wreck.name = "Epave_"+name
		get_tree().current_scene.get_node("Wrecks").add_child(wreck)
		var heavy: bool = is_in_group("boss")
		var spin: float = get("barrel_speed") if heavy else 0.0
		wreck.setup($Hull/VisualModel,wreck_velocity,heavy,spin)
		hull.hide()
		warning.hide()
		destroyed.emit(self)
	return true


func reset_drone() -> void:
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
	path_refresh = 0.0
	path = PackedVector3Array()
	hurt_flash = 0.0
	health_fill.scale.x = 1.0
	hit_shape.set_deferred("disabled", false)
	hull.show()
	warning.hide()
	$ShotSound.stop()
	impact_sound.stop()
	reset_physics_interpolation()
