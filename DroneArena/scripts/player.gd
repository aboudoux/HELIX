extends CharacterBody3D
## Le corps gère les collisions, Head la rotation verticale, Camera3D la vue.

signal health_changed(current: int, maximum: int)
signal died

@export var max_health: int = 100
var health: int = 100
var hurt_cooldown: float = 0.0

@export var move_speed: float = 6.0
@export var sprint_speed: float = 9.5
@export var crouch_speed: float = 3.0
@export var aim_move_speed: float = 4.0
@export var acceleration: float = 24.0
@export var jump_speed: float = 7.5
@export_range(0.0005, 0.008, 0.0001) var mouse_sensitivity: float = 0.002

@onready var head: Node3D = $Head
@onready var weapon: Node3D = $Head/Camera3D/Weapon
@onready var body_shape: CollisionShape3D = $CollisionShape3D
const STANDING_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.05
const EYE_OFFSET := .15
const POSTURE_SPEED := 6.0
var capsule: CapsuleShape3D
var standing_probe: CapsuleShape3D
var is_crouching: bool = false
var is_sprinting: bool = false
var spawn_transform: Transform3D


func _ready() -> void:
	spawn_transform = global_transform
	# Une capsule indépendante évite de modifier les autres instances du joueur.
	capsule = body_shape.shape.duplicate() as CapsuleShape3D
	body_shape.shape = capsule
	standing_probe = capsule.duplicate() as CapsuleShape3D
	standing_probe.height = STANDING_HEIGHT
	health = max_health


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity: float = mouse_sensitivity*weapon.look_multiplier()
		rotate_y(-event.relative.x * sensitivity)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * sensitivity, deg_to_rad(-85), deg_to_rad(85))


func _physics_process(delta: float) -> void:
	hurt_cooldown = maxf(0.0, hurt_cooldown - delta)
	if health <= 0:
		return
	update_posture(delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_action_just_pressed("jump") and not is_crouching:
		velocity.y = jump_speed

	var axes := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := global_basis * Vector3(axes.x, 0.0, axes.y)
	var aiming: bool = weapon.wants_to_aim()
	is_sprinting = Input.is_action_pressed("sprint") and not is_crouching and not aiming and not axes.is_zero_approx()
	var speed := crouch_speed if is_crouching else (aim_move_speed if aiming else (sprint_speed if is_sprinting else move_speed))
	var control := acceleration if is_on_floor() else acceleration * 0.35
	velocity.x = move_toward(velocity.x, direction.x * speed, control * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, control * delta)
	move_and_slide()

	# Filet de sécurité si le décor est modifié pendant l'apprentissage.
	if global_position.y < -12.0:
		reset_to_spawn()


func can_stand() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing_probe
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	# Une petite marge au sol évite de confondre le plancher avec un plafond.
	query.transform = global_transform * Transform3D(Basis.IDENTITY,Vector3(0,STANDING_HEIGHT*.5+.025,0))
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()


func update_posture(delta: float) -> void:
	var crouch := Input.is_action_pressed("crouch")
	if not crouch and capsule.height < STANDING_HEIGHT-.001:
		crouch = not can_stand()
	var target := CROUCH_HEIGHT if crouch else STANDING_HEIGHT
	var height := move_toward(capsule.height,target,POSTURE_SPEED*delta)
	if not is_equal_approx(capsule.height,height):
		capsule.height = height
		# Réduire la capsule par le haut conserve la position des pieds sur le sol.
		body_shape.position.y = height*.5
		head.position.y = height-EYE_OFFSET
	is_crouching = crouch or capsule.height < STANDING_HEIGHT-.001


func get_aim_point() -> Vector3:
	# Les drones visent le corps à sa hauteur actuelle, même accroupi.
	return global_transform * Vector3(0,capsule.height*.6,0)


func reset_to_spawn() -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	head.rotation = Vector3.ZERO
	capsule.height = STANDING_HEIGHT
	body_shape.position.y = STANDING_HEIGHT*.5
	head.position.y = STANDING_HEIGHT-EYE_OFFSET
	is_crouching = false
	is_sprinting = false
	weapon.reset_weapon()
	reset_physics_interpolation()


func apply_damage(amount: int) -> bool:
	if amount <= 0 or health <= 0 or hurt_cooldown > 0.0 or get_tree().paused:
		return false
	health = maxi(health - amount, 0)
	hurt_cooldown = 0.35
	$HurtSound.play()
	health_changed.emit(health, max_health)
	if health == 0:
		velocity = Vector3.ZERO
		is_sprinting = false
		died.emit()
	return true


func restore_health() -> void:
	health = max_health
	hurt_cooldown = 0.0
	$HurtSound.stop()
	health_changed.emit(health, max_health)
