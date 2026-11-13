extends "res://scripts/drone.gd"

signal reinforcements_called

enum Role { SCOUT, REPAIR }
var role: Role
var lock_time := 0.0
var transmitted := false
var pulse_left := 0.0
var repair_cooldown := 0.0
var beam: MeshInstance3D

func _ready() -> void:
	super._ready()
	var color := Color("ffd36f") if role == Role.SCOUT else Color("74ffaa")
	$Hull/NameTag.modulate = color
	$Hull/NameTag.show()
	if role == Role.REPAIR:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.035
		mesh.bottom_radius = 0.035
		beam = MeshInstance3D.new()
		beam.mesh = mesh
		beam.material_override = material
		beam.top_level = true
		add_child(beam)
		beam.hide()
		destroyed.connect(func(_drone): beam.hide())

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not alive or not director.navigation_ready or player.health <= 0:
		return
	if role == Role.SCOUT:
		update_transmission(delta)
	else:
		update_repairs(delta)

func update_transmission(delta: float) -> void:
	if transmitted:
		$Hull/NameTag.text = "ÉCLAIREUR · SIGNAL ÉMIS"
		return
	if global_position.distance_to(player.global_position) > 19.0 or not has_line_of_sight():
		lock_time = 0.0
		$Hull/NameTag.text = "ÉCLAIREUR · COUPEZ SA LIGNE DE VUE"
		return
	lock_time += delta
	$Hull/NameTag.text = "TRANSMISSION D'ALERTE · %d %%" % mini(100,roundi(lock_time/1.5*100))
	if lock_time >= 1.5:
		transmitted = true
		reinforcements_called.emit()

func update_repairs(delta: float) -> void:
	pulse_left = maxf(0.0, pulse_left - delta)
	beam.visible = pulse_left > 0.0
	repair_cooldown = maxf(0.0, repair_cooldown - delta)
	if repair_cooldown > 0.0:
		return
	repair_cooldown = 0.25
	for ally in director.get_children():
		if ally == self or not ally.has_method("receive_repair") or not ally.alive or ally.health >= ally.max_health:
			continue
		var origin := global_position
		var target: Vector3 = ally.global_position
		var distance := origin.distance_to(target)
		if distance < 0.05 or distance > 8.0:
			continue
		var query := PhysicsRayQueryParameters3D.create(origin, target, 1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		ally.receive_repair()
		repair_cooldown = 1.25
		pulse_left = 0.28
		beam.global_position = (origin + target) * 0.5
		beam.global_basis = Basis(Quaternion(Vector3.UP, origin.direction_to(target)))
		(beam.mesh as CylinderMesh).height = distance
		beam.show()
		return
