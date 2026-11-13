extends Node3D
## Détection sur tout le segment parcouru pour ne pas traverser les parois.

@export var speed: float = 16.0
@export var damage: int = 10
@export var pulse_length: float = 1.8
@onready var core: MeshInstance3D = $Core
@onready var trail: MeshInstance3D = $Trail
var direction := Vector3.FORWARD
var source_position := Vector3.ZERO
var shooter: RID
var remaining: float = 4.0
var travelled: float = 0.0


func launch(origin: Vector3, travel_direction: Vector3, owner_rid: RID) -> void:
	global_position = origin
	source_position = origin
	direction = travel_direction.normalized()
	shooter = owner_rid
	travelled = 0.0
	look_at(origin + direction, Vector3.RIGHT if absf(direction.y) > 0.99 else Vector3.UP)
	update_pulse()


func _physics_process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
		return
	var next := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next, 27, [shooter])
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if hit.collider.has_method("apply_damage_from"):
			hit.collider.apply_damage_from(damage, source_position)
		elif hit.collider.has_method("apply_damage"):
			hit.collider.apply_damage(damage)
		queue_free()
	else:
		travelled += global_position.distance_to(next)
		global_position = next
		update_pulse()


func update_pulse() -> void:
	# La pointe reste à la position physique du tir ; le trait s'étend derrière.
	# Il grandit à la sortie du canon et ne dépasse pas derrière son point de départ.
	var length := minf(travelled,pulse_length)
	for part in [core,trail]:
		part.visible = length > .001
		part.scale.y = maxf(length,.001)
		part.position.z = length*.5
