extends StaticBody3D
## Une cible d'entraînement réutilisable. Pas encore un ennemi.

@export var target_name: String = "CIBLE 01"
@export var recovery_delay: float = 2.0
@onready var plate: Node3D = $Plate
@onready var hit_shape: CollisionShape3D = $HitShape
@onready var status: Label3D = $Status
var active: bool = true
var recovery_remaining: float = 0.0
var times_hit: int = 0


func _ready() -> void:
	$NameTag.text = target_name


func receive_hit() -> bool:
	if not active:
		return false
	active = false
	times_hit += 1
	recovery_remaining = recovery_delay
	hit_shape.set_deferred("disabled", true)
	status.text = "TOUCHÉ"
	status.modulate = Color(1.0, 0.64, 0.3)
	return true


func _physics_process(delta: float) -> void:
	var angle := 0.0 if active else deg_to_rad(-80)
	plate.rotation.x = move_toward(plate.rotation.x, angle, delta * 8.0)
	if not active:
		recovery_remaining -= delta
		if recovery_remaining <= 0.0:
			reset_target()


func reset_target() -> void:
	active = true
	recovery_remaining = 0.0
	hit_shape.set_deferred("disabled", false)
	plate.rotation = Vector3.ZERO
	status.text = "PRÊT"
	status.modulate = Color(0.35, 0.9, 0.95)
