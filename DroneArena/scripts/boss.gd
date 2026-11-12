extends "res://scripts/drone.gd"
## CERBÈRE : double Gatling, rafales annoncées et poursuite limitée au cœur.

signal health_changed(current: int, maximum: int)
signal phase_changed(phase: int)
const HEALTH := [32, 44, 60]
const DAMAGE := [4, 6, 8]
const SPEED := [16.0, 18.0, 21.0]
var difficulty_level: int = 1
var phase: int = 1
var burst_remaining: int = 0
var round_timer: float = 0.0
var rounds_per_burst: int = 10
var projectile_damage: int = 6
var projectile_speed: float = 18.0
var left_shots: int = 0
var right_shots: int = 0
var next_gun: int = 0
var barrel_speed: float = 0.0
var flash_time := [0.0, 0.0]
var guns: Array[Node3D] = []
var barrels: Array[Node3D] = []
var muzzles: Array[Node3D] = []
var warnings: Array[MeshInstance3D] = []
var flashes: Array[OmniLight3D] = []


func _ready() -> void:
	super._ready()
	for side in ["Left", "Right"]:
		var gun: Node3D = $Hull/VisualModel.find_child(side, true, false)
		guns.append(gun)
		barrels.append(gun.get_node(side+"Barrels"))
		muzzles.append(gun.get_node(side+"Muzzle"))
		var line: MeshInstance3D = $Warning if side == "Left" else $WarningRight
		line.mesh = line.mesh.duplicate()
		warnings.append(line)
		var flash := OmniLight3D.new()
		flash.light_color = Color(1,.28,.035)
		flash.light_energy = 3.5
		flash.omni_range = 4.0
		gun.get_node(side+"Muzzle").add_child(flash)
		flash.hide()
		flashes.append(flash)
	deactivate()


func configure_difficulty(profile: Dictionary) -> void:
	difficulty_level = clampi(int(profile.health)-2,0,2)
	max_health = HEALTH[difficulty_level]
	health = max_health
	projectile_damage = DAMAGE[difficulty_level]
	projectile_speed = SPEED[difficulty_level]
	move_speed = [2.2, 3.0, 3.5][difficulty_level]
	charge_duration = [1.45, 1.15, .95][difficulty_level]
	fire_interval = [3.3, 2.4, 1.95][difficulty_level]
	rounds_per_burst = [8, 10, 12][difficulty_level]
	health_changed.emit(health,max_health)


func reset_drone() -> void:
	super.reset_drone()
	phase = 1
	burst_remaining = 0
	round_timer = 0.0
	shots_fired = 0
	left_shots = 0
	right_shots = 0
	next_gun = 0
	barrel_speed = 0.0
	elapsed = 0.0
	$WarningRight.hide()
	for i in range(guns.size()):
		guns[i].position.z = -.42
		barrels[i].rotation.z = 0.0
		flash_time[i] = 0.0
		flashes[i].hide()
	health_changed.emit(health,max_health)


func deactivate() -> void:
	reset_drone()
	alive = false
	hide()
	hit_shape.set_deferred("disabled",true)
	set_physics_process(false)
	set_process(false)
	director.navigation_ready = false


func activate() -> void:
	reset_drone()
	cooldown = 2.5
	show()
	set_physics_process(true)
	set_process(true)


func _physics_process(delta: float) -> void:
	if not alive or player.health <= 0 or not director.navigation_ready:
		return
	cooldown = maxf(0.0,cooldown-delta)
	path_refresh -= delta
	var offset := player.global_position-global_position
	offset.y = 0
	var sees_player := has_line_of_sight()
	tactics.observe(self,delta,sees_player)
	# Approche par la grille en contournant réacteur, caisses et cloisons.
	if path_refresh <= 0:
		var desired_target: Vector3 = tactics.choose_destination(self,false,13.0)
		path = director.flight_path(global_position,desired_target)
		path_index = 1 if path.size()>1 else 0
		path_refresh = .45
	while path_index < path.size() and global_position.distance_to(path[path_index]) < .25:
		path_index += 1
	var desired := Vector3.ZERO
	if path_index < path.size():
		desired = global_position.direction_to(path[path_index])*move_speed
	if charge_remaining > 0 or burst_remaining > 0:
		desired *= .2
	velocity = velocity.move_toward(desired,delta*5)
	velocity.y = (director.FLIGHT_HEIGHT-global_position.y)*4
	move_and_slide()
	# Le verrouillage reste figé durant la rafale : le joueur peut esquiver.
	var facing: Vector3 = locked_aim-global_position if charge_remaining>0 or burst_remaining>0 else (offset if sees_player else tactics.last_known_position-global_position)
	if facing.length_squared() > .01:
		rotation.y = lerp_angle(rotation.y,atan2(-facing.x,-facing.z),minf(delta*3,1))
	update_attack(delta,offset.length()<44 and sees_player)


func update_attack(delta: float, can_see: bool) -> void:
	if not attack_enabled or not can_see:
		charge_remaining = 0.0
		burst_remaining = 0
		cooldown = maxf(cooldown,.7)
		for line in warnings: line.hide()
		return
	if burst_remaining > 0:
		round_timer -= delta
		if round_timer <= 0:
			fire_round()
			round_timer += .11 if phase == 1 else .085
			burst_remaining -= 1
			if burst_remaining == 0:
				cooldown = fire_interval*(.82 if phase==2 else 1.0)
	elif charge_remaining > 0:
		charge_remaining = maxf(0,charge_remaining-delta)
		update_warning()
		if charge_remaining <= 0:
			burst_remaining = rounds_per_burst+(2 if phase==2 else 0)
			round_timer = 0.0
			for line in warnings: line.hide()
	elif cooldown <= 0:
		locked_aim = player.get_aim_point()
		charge_remaining = charge_duration*(.9 if phase==2 else 1.0)
		update_warning()


func fire_round() -> void:
	var index := next_gun
	next_gun = 1-next_gun
	var origin: Vector3 = muzzles[index].global_position
	# Vérifier chaque bouche : le canon extérieur ne traverse jamais une couverture.
	var query := PhysicsRayQueryParameters3D.create(origin,locked_aim,1,[get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return
	director.spawn_round(origin,locked_aim,get_rid(),projectile_damage,projectile_speed)
	shots_fired += 1
	if index==0: left_shots += 1
	else: right_shots += 1
	flash_time[index] = .065
	$ShotSound.global_position = origin
	$ShotSound.pitch_scale = randf_range(.7,.79)
	$ShotSound.play()


func update_warning() -> void:
	for i in range(warnings.size()):
		var line: MeshInstance3D = warnings[i]
		var origin: Vector3 = muzzles[i].global_position
		var direction := locked_aim-origin
		line.show()
		(line.mesh as CylinderMesh).height = maxf(direction.length(),.01)
		line.global_position = (origin+locked_aim)*.5
		line.global_basis = Basis(Quaternion(Vector3.UP,direction.normalized()))


func _process(delta: float) -> void:
	if not alive:
		return
	super._process(delta)
	hull.position.y = sin(elapsed*2.2)*.09
	var firing := burst_remaining>0
	barrel_speed = move_toward(barrel_speed,65.0 if firing else (30.0 if charge_remaining>0 else 0.0),delta*70)
	for i in range(guns.size()):
		barrels[i].rotate_z(delta*barrel_speed*(-1 if i==0 else 1))
		flash_time[i] = maxf(0,flash_time[i]-delta)
		flashes[i].visible = flash_time[i]>0
		guns[i].position.z = lerpf(guns[i].position.z,-.42+(.1 if flash_time[i]>0 else 0.0),minf(delta*25,1))
	state_label.text = "RAFALE  ·  À COUVERT !" if firing else ("VERROUILLAGE  ·  ESQUIVEZ" if charge_remaining>0 else ("SURCHAUFFE" if phase==2 else "CERBÈRE ACTIF"))
	$Hull/EyeLight.light_energy = (1.7 if phase==2 else .8)+sin(elapsed*8)*.2


func receive_hit_at(point: Vector3, normal: Vector3, incoming: Vector3) -> bool:
	var accepted := super.receive_hit_at(point,normal,incoming)
	if not accepted:
		return false
	health_changed.emit(health,max_health)
	if alive and phase==1 and health<=max_health/2:
		phase = 2
		phase_changed.emit(phase)
	if not alive:
		burst_remaining = 0
		$WarningRight.hide()
		for flash in flashes: flash.hide()
	return true
