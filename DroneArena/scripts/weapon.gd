extends Node3D
## Le rayon part du centre de la caméra. Un second test depuis le canon
## empêche de tirer à travers un obstacle qui masque seulement l'arme.

signal fired(hit_position: Vector3, target_hit: bool)

const EFFECT := preload("res://scripts/shot_effect.gd")
@export_range(0.08, 1.0, 0.01) var fire_interval: float = 0.20
@export var max_range: float = 100.0
@export var aim_fov: float = 58.0
@export var aim_position := Vector3(0.0, -0.188, -0.5)
@export_range(0.1, 1.0, 0.05) var aim_sensitivity: float = 0.65
@export var aim_transition_speed: float = 7.0
@export_range(1, 120, 1) var magazine_capacity: int = 30
@export_range(0.5, 5.0, 0.1) var reload_duration: float = 1.8

@onready var camera: Camera3D = get_parent()
@onready var model: Node3D = $Model
@onready var muzzle: Marker3D = $Model/Muzzle
@onready var flash: MeshInstance3D = $Model/Muzzle/Flash
@onready var muzzle_light: OmniLight3D = $Model/Muzzle/Light
@onready var shot_sound: AudioStreamPlayer = $ShotSound
@onready var hit_sound: AudioStreamPlayer = $HitSound
@onready var reload_sound: AudioStreamPlayer = $ReloadSound
@onready var empty_sound: AudioStreamPlayer = $EmptySound
var enabled: bool = false
var shots_fired: int = 0
var cooldown: float = 0.0
var trigger_ready: bool = true
var recoil: float = 0.0
var flash_time: float = 0.0
var last_hit: Dictionary = {}
var is_aiming: bool = false
var aim_blend: float = 0.0
var aim_ready: bool = true
var hip_position: Vector3
var hip_fov: float
var ammo: int = 0
var is_reloading: bool = false
var reload_remaining: float = 0.0
var reload_ready: bool = true
var empty_ready: bool = true


func _ready() -> void:
	hip_position = position
	hip_fov = camera.fov
	ammo = magazine_capacity


func wants_to_aim() -> bool:
	return enabled and not is_reloading and aim_ready and Input.is_action_pressed("aim")


func look_multiplier() -> float:
	return lerpf(1.0,aim_sensitivity,aim_blend)


func clear_aim() -> void:
	is_aiming = false
	aim_blend = 0.0
	position = hip_position
	camera.fov = hip_fov


func update_aim(delta: float) -> void:
	if not Input.is_action_pressed("aim"):
		aim_ready = true
	is_aiming = wants_to_aim()
	aim_blend = move_toward(aim_blend,1.0 if is_aiming else 0.0,delta*aim_transition_speed)
	position = hip_position.lerp(aim_position,aim_blend)
	camera.fov = lerpf(hip_fov,aim_fov,aim_blend)


func set_enabled(value: bool) -> void:
	enabled = value
	# Le clic sur Reprendre ne doit jamais déclencher un tir dans l'arène.
	trigger_ready = not Input.is_action_pressed("fire")
	# Après le menu ou une pause, relâcher le clic droit avant de viser à nouveau.
	aim_ready = not Input.is_action_pressed("aim")
	reload_ready = not Input.is_action_pressed("reload")
	clear_aim()
	if not value:
		flash_time = 0.0
		flash.hide()
		muzzle_light.hide()
		shot_sound.stop()
		hit_sound.stop()
		empty_sound.stop()
	# Le son et l'animation du rechargement sont soumis à la pause du joueur.
	# Garder leur état permet de reprendre exactement au même point.


func _physics_process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	if not enabled:
		return
	if not Input.is_action_pressed("fire"):
		trigger_ready = true
		empty_ready = true
	if not Input.is_action_pressed("reload"):
		reload_ready = true
	if reload_ready and Input.is_action_just_pressed("reload"):
		start_reload()
	if is_reloading:
		reload_remaining = maxf(reload_remaining - delta, 0.0)
		if reload_remaining <= 0.0:
			ammo = magazine_capacity
			is_reloading = false
		update_aim(delta)
		return
	update_aim(delta)
	if Input.is_action_pressed("fire") and trigger_ready and cooldown <= 0.0:
		fire()


func _process(delta: float) -> void:
	recoil = move_toward(recoil, 0.0, delta * 6.5)
	var kick := recoil*lerpf(1.0,.3,aim_blend)
	var pose := reload_pose()
	model.position = Vector3(-pose*.12, kick*.025-pose*.075, kick*.085+pose*.08)
	model.rotation = Vector3(kick*.07-pose*.15, pose*.22, pose*.48)
	flash_time = maxf(flash_time - delta, 0.0)
	flash.visible = flash_time > 0.0
	muzzle_light.visible = flash_time > 0.0


func fire() -> void:
	# Appelé uniquement durant la physique : aucun accès au monde verrouillé.
	if not enabled or get_tree().paused or cooldown > 0.0 or is_reloading:
		return
	if ammo <= 0:
		# Un clic à vide par pression, même en maintenant le bouton gauche.
		if empty_ready:
			empty_sound.play()
			empty_ready = false
		return
	cooldown = fire_interval
	ammo -= 1
	shots_fired += 1
	var start := camera.global_position
	var aim := start - camera.global_basis.z * max_range
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(start, aim, 13)
	query.hit_from_inside = true
	last_hit = space.intersect_ray(query)
	if not last_hit.is_empty():
		aim = last_hit.position
	# Prolonger légèrement le segment évite de manquer la surface visée.
	var muzzle_start := muzzle.global_position
	# Vérifier aussi l'espace jusqu'au canon : il peut dépasser derrière une paroi.
	query = PhysicsRayQueryParameters3D.create(start, muzzle_start, 13)
	query.hit_from_inside = true
	var obstruction := space.intersect_ray(query)
	if obstruction.is_empty():
		query = PhysicsRayQueryParameters3D.create(muzzle_start, aim + (aim - muzzle_start).normalized() * 0.02, 13)
		query.hit_from_inside = true
		obstruction = space.intersect_ray(query)
	if not obstruction.is_empty():
		last_hit = obstruction
		aim = obstruction.position
	var target_hit := false
	if not last_hit.is_empty():
		var collider: Object = last_hit.collider
		if collider.has_method("receive_hit_at"):
			target_hit = collider.receive_hit_at(aim,last_hit.normal,(aim-start).normalized())
		elif collider.has_method("receive_hit"):
			target_hit = collider.receive_hit()
		if not collider.has_method("receive_hit_at"):
			spawn_effect(aim + last_hit.normal * 0.012, aim, false, target_hit)
	spawn_effect(muzzle_start, aim, true, target_hit)
	recoil = 1.0
	flash_time = 0.045
	flash.show()
	muzzle_light.show()
	shot_sound.pitch_scale = randf_range(0.96, 1.04)
	shot_sound.play()
	if target_hit:
		hit_sound.play()
	fired.emit(aim, target_hit)


func start_reload() -> bool:
	if not enabled or get_tree().paused or is_reloading or ammo >= magazine_capacity:
		return false
	is_reloading = true
	reload_remaining = reload_duration
	reload_ready = false
	recoil = 0.0
	flash_time = 0.0
	flash.hide()
	muzzle_light.hide()
	empty_sound.stop()
	reload_sound.pitch_scale = reload_sound.stream.get_length()/reload_duration
	reload_sound.play()
	return true


func reload_pose() -> float:
	if not is_reloading:
		return 0.0
	var progress := 1.0-reload_remaining/reload_duration
	return smoothstep(0.0,.16,progress)*(1.0-smoothstep(.76,1.0,progress))


func cancel_reload() -> void:
	is_reloading = false
	reload_remaining = 0.0
	reload_sound.stop()
	model.transform = Transform3D.IDENTITY


func spawn_effect(start: Vector3, end: Vector3, beam: bool, on_target: bool) -> void:
	var effect := Node3D.new()
	effect.set_script(EFFECT)
	# Tous les effets restent sous un nœud soumis à la pause et s'autodétruisent.
	get_tree().current_scene.get_node("Effects").add_child(effect)
	effect.setup(start, end, beam, on_target)


func reset_weapon() -> void:
	cancel_reload()
	ammo = magazine_capacity
	empty_ready = true
	cooldown = 0.0
	recoil = 0.0
	flash_time = 0.0
	last_hit = {}
	model.transform = Transform3D.IDENTITY
	set_enabled(enabled)
