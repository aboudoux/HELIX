extends Node3D

const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const COLLISION := preload("res://scripts/actor_collision.gd")
const EFFECT := preload("res://scripts/shot_effect.gd")
const FOOTPRINT := Vector3(.82, 1.04, .82)
const OFFSET := Vector3(0, -.23, 0)
const RANGE := 22.0

var game: Node3D
var base: StaticBody3D
var head: Node3D
var barrel: MeshInstance3D
var sound: AudioStreamPlayer3D
var timer := .65


func build(body: StaticBody3D, campaign: Node3D, finish: Material) -> void:
	base = body
	game = campaign
	process_mode = Node.PROCESS_MODE_PAUSABLE
	COLLISION.add_box(base, FOOTPRINT, OFFSET)
	KIT.bevel(self, Vector3(0,-.67,0), Vector3(.82,.16,.82), .045, WORLD.FRAME)
	KIT.bevel(self, Vector3(0,-.4,0), Vector3(.72,.45,.72), .065, finish)
	for side in [-1.0, 1.0]:
		KIT.bevel(self, Vector3(side*.366,-.37,0), Vector3(.024,.28,.56), .009, WORLD.STEEL)
		KIT.bevel(self, Vector3(side*.379,-.37,.13), Vector3(.01,.056,.24), .003, WORLD.CYAN)
	WORLD.cylinder(self, Vector3(0,-.13,0), .26, .29, .12, WORLD.FRAME)
	head = Node3D.new()
	head.position.y = .05
	add_child(head)
	KIT.bevel(head, Vector3.ZERO, Vector3(.46,.26,.42), .06, WORLD.FRAME)
	KIT.bevel(head, Vector3(0,.14,.03), Vector3(.36,.08,.33), .025, finish)
	KIT.bevel(head, Vector3(.14,.03,-.212), Vector3(.08,.075,.04), .012, WORLD.CYAN)
	barrel = WORLD.cylinder(head, Vector3(0,-.01,-.28), .045,.062,.23,WORLD.STEEL,Vector3(PI/2,0,0))
	sound = AudioStreamPlayer3D.new()
	sound.stream = preload("res://audio/recorded_pistol.wav")
	sound.volume_db = -17
	sound.unit_size = 4
	sound.max_distance = 30
	add_child(sound)


func _physics_process(delta: float) -> void:
	if not base.visible or not game.pilot.in_control or game.defeated or game.transition:
		return
	if global_position.distance_squared_to(game.pilot.global_position) > 38.0*38.0:
		return
	timer -= delta
	if timer > 0.0:
		return
	timer = .20
	var closest := RANGE * RANGE
	var target_hit: Dictionary = {}
	for enemy in game.squad.enemies:
		if not game.squad.hostile_alive(enemy):
			continue
		var aim: Vector3 = game.squad.aim_point(enemy)
		var distance := head.global_position.distance_squared_to(aim)
		if distance >= closest or distance < .30:
			continue
		var ray := PhysicsRayQueryParameters3D.create(head.global_position, aim, 31, [base.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.get("collider") == enemy:
			target_hit = hit
			closest = distance
	if target_hit.is_empty():
		return
	var point: Vector3 = target_hit.position
	var direction := head.global_position.direction_to(point)
	head.look_at(point, Vector3.RIGHT if absf(direction.y) > .98 else Vector3.UP)
	if not target_hit.collider.receive_hit_at(point, target_hit.normal, direction, 1):
		return
	timer = .65
	sound.pitch_scale = randf_range(.94, 1.06)
	sound.play()
	barrel.position.z = -.22
	create_tween().tween_property(barrel, "position:z", -.28, .16)
	var effect := EFFECT.new()
	game.get_node("Effects").add_child(effect)
	effect.setup(head.to_global(Vector3(0,-.01,-.39)), point, true, true)
