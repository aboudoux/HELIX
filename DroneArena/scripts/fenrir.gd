extends "res://scripts/hound.gd"
## Alpha quadrupède : canons alternés, visée figée, surchauffe à mi-vie.
signal phase_changed(value: int)
var phase: int = 1
var configured_speed: float = 4.0
var projectile_damage: int = 9
var projectile_speed: float = 21.0
@onready var right_muzzle: Node3D = visual.find_child("LaserMuzzleRight",true,false)


func _ready() -> void:
	super._ready()
	deactivate()


func configure_difficulty(profile: Dictionary) -> void:
	var level: int = Difficulty.PROFILES.find(profile)
	level = clampi(level,0,2)
	max_health = [60,85,115][level]
	health = max_health
	move_speed = [3.0,4.0,4.8][level]
	configured_speed = move_speed
	fire_interval = [3.8,3.1,2.6][level]
	charge_duration = [1.8,1.5,1.25][level]
	initial_delay = 3.5
	projectile_damage = [6,9,12][level]
	projectile_speed = [18.0,21.0,24.0][level]
	$ChargeSound.pitch_scale = $ChargeSound.stream.get_length()/charge_duration
	cooldown = initial_delay
	health_fill.scale.x = 1


func activate() -> void:
	reset_drone()
	show()
	set_physics_process(true)
	set_process(true)
	director.navigation_ready = false


func deactivate() -> void:
	alive = false
	hide()
	set_physics_process(false)
	set_process(false)
	hit_shape.set_deferred("disabled",true)
	for sound in [$ChargeSound,$ShotSound,$StepSound,$ImpactSound]: sound.stop()


func reset_drone() -> void:
	super.reset_drone()
	phase = 1
	move_speed = configured_speed
	shots_fired = 0


func receive_hit_at(point: Vector3, normal: Vector3, incoming: Vector3) -> bool:
	var accepted := super.receive_hit_at(point,normal,incoming)
	if accepted and alive and phase==1 and health<=max_health/2:
		phase = 2
		move_speed *= 1.15
		phase_changed.emit(phase)
	return accepted


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
			var origin: Vector3 = muzzle.global_position if shots_fired%2==0 else right_muzzle.global_position
			director.fire_alpha(origin,locked_aim,get_rid(),projectile_damage,projectile_speed)
			shots_fired += 1
			$ShotSound.play()
			burst_remaining -= 1
			burst_time = .24 if phase==1 else .18
			if burst_remaining==0:
				cooldown = fire_interval*(.8 if phase==2 else 1.0)
				warning.hide()
	elif charge_remaining>0:
		charge_remaining = maxf(0,charge_remaining-delta)
		update_warning()
		if charge_remaining<=0:
			burst_remaining = 4 if phase==1 else 6
			burst_time = 0
	elif cooldown<=0:
		locked_aim = player.get_aim_point()
		charge_remaining = charge_duration*(.85 if phase==2 else 1.0)
		$ChargeSound.play()
		update_warning()
