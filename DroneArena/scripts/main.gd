extends Node3D
## Le menu continue à recevoir les entrées lorsque le personnage est en pause.

@onready var player: CharacterBody3D = $Player
@onready var overlay: Control = $Interface/Overlay
@onready var title: Label = $Interface/Overlay/Card/Content/Title
@onready var subtitle: Label = $Interface/Overlay/Card/Content/Subtitle
@onready var resume_button: Button = $Interface/Overlay/Card/Content/Resume
@onready var reset_button: Button = $Interface/Overlay/Card/Content/Reset
@onready var reticle: Control = $Interface/Reticle
@onready var heading_label: Label = $Interface/Header/Heading
var has_started: bool = false
var target_hits: int = 0
var hit_feedback_time: float = 0.0
var drones_destroyed: int = 0
var game_over: bool = false
var damage_feedback_time: float = 0.0
var previous_health: int = 100
var active_difficulty: int = 1
@onready var difficulty_picker: VBoxContainer = $Interface/Overlay/Card/Content/Difficulty


func _ready() -> void:
	resume_button.pressed.connect(start_exploration)
	reset_button.pressed.connect(restart_exploration)
	$Interface/Overlay/Card/Content/Quit.pressed.connect(get_tree().quit)
	player.weapon.fired.connect(_on_weapon_fired)
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	for drone in $Drones.get_children():
		drone.destroyed.connect(_on_drone_destroyed)
	$Interface.move_child($Interface/DamageFlash, 0)
	var fill: StyleBoxFlat = $Interface/Header/Health/Bar.get_theme_stylebox("fill").duplicate()
	$Interface/Header/Health/Bar.add_theme_stylebox_override("fill", fill)
	_on_health_changed(player.health, player.max_health)
	for index in range(3):
		difficulty_picker.get_node("Choices").get_child(index).pressed.connect(_select_difficulty.bind(index))
	apply_difficulty()
	show_pause()
	if OS.has_feature("web"):
		add_child(preload("res://scripts/web_support.gd").new())


func apply_difficulty() -> void:
	active_difficulty = Difficulty.selected
	var profile: Dictionary = Difficulty.PROFILES[active_difficulty]
	for drone in $Drones.get_children():
		drone.configure_difficulty(profile)
	$Drones.projectile_damage = profile.damage
	$Drones.projectile_speed = profile.bolt_speed
	$Interface/Header/Difficulty.text = "DIFFICULTÉ  /  " + str(profile.name).to_upper()


func _select_difficulty(index: int) -> void:
	Difficulty.select(index)
	update_difficulty_picker()


func is_run_finished() -> bool:
	return game_over


func update_difficulty_picker() -> void:
	var profile: Dictionary = Difficulty.PROFILES[Difficulty.selected]
	var new_game := not has_started or is_run_finished()
	difficulty_picker.get_node("Heading").text = "DIFFICULTÉ" if new_game else "DIFFICULTÉ AU REDÉMARRAGE"
	for index in range(3):
		var button: Button = difficulty_picker.get_node("Choices").get_child(index)
		var chosen := index == Difficulty.selected
		button.set_pressed_no_signal(chosen)
		button.text = ("✓ " if chosen else "") + Difficulty.PROFILES[index].name
		button.add_theme_color_override("font_color", Color(.035,.12,.15) if chosen else Color(.84,.92,.94))
		button.add_theme_color_override("font_focus_color", Color(.035,.12,.15) if chosen else Color(.84,.92,.94))
	var hint: String = profile.hint
	if not new_game:
		hint = "Reprendre conserve le mode %s." % Difficulty.PROFILES[active_difficulty].name if Difficulty.selected != active_difficulty else "Choisissez un niveau puis recommencez pour le changer."
	difficulty_picker.get_node("Description").text = profile.summary + "\n" + hint


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if game_over:
			get_viewport().set_input_as_handled()
			return
		elif get_tree().paused and has_started:
			start_exploration()
		else:
			show_pause()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and has_started:
		show_pause()


func _process(delta: float) -> void:
	var angle := fposmod(-player.rotation_degrees.y, 360.0)
	var directions := ["N", "NE", "E", "SE", "S", "SO", "O", "NO"]
	heading_label.text = "%s   /   %03d°" % [directions[int(round(angle / 45.0)) % 8], int(angle)]
	if not get_tree().paused:
		hit_feedback_time = maxf(hit_feedback_time - delta, 0.0)
	$Interface/Reticle/HitMarker.visible = hit_feedback_time > 0.0
	# Un point fin remplace la croix pendant la visée, au centre exact des tirs.
	var blend: float = player.weapon.aim_blend
	for bar in ["Left","Right","Top","Bottom"]:
		reticle.get_node(bar).modulate.a = 1.0-blend
	reticle.get_node("AimDot").visible = blend > 0.01
	reticle.get_node("AimDot").modulate.a = blend
	damage_feedback_time = maxf(0.0, damage_feedback_time - delta)
	$Interface/DamageFlash.color.a = damage_feedback_time * 1.6
	update_ammo_hud()


func update_ammo_hud() -> void:
	var weapon: Node3D = player.weapon
	var panel: Control = $Interface/Ammo
	panel.visible = has_started and not get_tree().paused and not is_run_finished()
	panel.get_node("Count").text = "%02d / %02d" % [weapon.ammo, weapon.magazine_capacity]
	var color := Color(.35,.88,.88)
	var status := "R  RECHARGER  ·  RÉSERVE ∞"
	var progress: float = float(weapon.ammo)/weapon.magazine_capacity
	if weapon.is_reloading:
		progress = 1.0-weapon.reload_remaining/weapon.reload_duration
		status = "RECHARGEMENT… %d %%" % roundi(progress*100)
		color = Color(1.0,.7,.32)
	elif weapon.ammo == 0:
		status = "CHARGEUR VIDE  ·  R RECHARGER"
		color = Color(1.0,.3,.2)
	elif weapon.ammo <= 5:
		color = Color(1.0,.7,.32)
	panel.get_node("Count").add_theme_color_override("font_color", color)
	panel.get_node("Status").add_theme_color_override("font_color", color)
	panel.get_node("Status").text = status
	panel.get_node("Progress").value = progress*100
	panel.get_node("Progress").self_modulate = color


func show_pause() -> void:
	if is_run_finished():
		player.weapon.cancel_reload()
	player.weapon.set_enabled(false)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay.show()
	reticle.hide()
	title.text = "Une pause ?" if has_started else "Prenez les commandes."
	subtitle.text = "Le secteur vous attend. Reprenez quand vous voulez." if has_started else "Deux drones et un chien robot LIMIER K-9 occupent le secteur. Neutralisez-les et surveillez votre santé."
	resume_button.text = "Reprendre le combat" if has_started else "Entrer dans l'arène  →"
	reset_button.visible = has_started
	$Interface/Overlay/Card/Content/Controls.visible = not game_over
	$Interface/Overlay/Card/Content/Kicker.text = "OPÉRATION SENTINELLES  /  03"
	$Interface/Overlay/Card/Content/Note.text = "100 points de vie. Le viseur rouge annonce un tir.\nDéplacez-vous latéralement pour esquiver !"
	if game_over:
		title.text = "Signal perdu."
		subtitle.text = "Votre santé est épuisée. Reprenez l'arène depuis le début."
		resume_button.text = "Recommencer l'arène  →"
		reset_button.hide()
		$Interface/Overlay/Card/Content/Kicker.text = "FIN DE PARTIE  /  03"
		$Interface/Overlay/Card/Content/Note.text = "Hostiles neutralisés : %d / 3\nBougez latéralement et utilisez les obstacles." % drones_destroyed
	update_difficulty_picker()
	resume_button.grab_focus()


func start_exploration() -> void:
	if game_over:
		restart_exploration()
		return
	if not has_started and active_difficulty != Difficulty.selected:
		apply_difficulty()
		$Drones.reset_encounter()
	has_started = true
	overlay.hide()
	reticle.show()
	get_tree().paused = false
	player.weapon.set_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resume_button.release_focus()


func restart_exploration() -> void:
	game_over = false
	apply_difficulty()
	player.reset_to_spawn()
	player.restore_health()
	drones_destroyed = 0
	damage_feedback_time = 0.0
	$Interface/Header/DroneCount.text = "HOSTILES NEUTRALISÉS   00 / 03"
	$Interface/ClearBanner.hide()
	$Drones.reset_encounter()
	target_hits = 0
	hit_feedback_time = 0.0
	$Interface/Header/Targets.text = "CIBLES TOUCHÉES   00"
	for target in get_tree().get_nodes_in_group("training_targets"):
		target.reset_target()
	for effect in $Effects.get_children():
		effect.queue_free()
	for wreck in $Wrecks.get_children():
		if not wreck.is_queued_for_deletion(): wreck.queue_free()
	for bolt in $Projectiles.get_children():
		bolt.queue_free()
	start_exploration()


func _on_weapon_fired(_position: Vector3, target_hit: bool) -> void:
	# Le bruit renseigne les ennemis actifs proches, sans réveiller les secteurs futurs.
	for actor in get_tree().get_nodes_in_group("enemies"):
		if is_ancestor_of(actor) and actor.alive and actor.global_position.distance_to(player.global_position)<32:
			actor.tactics.alert(player.global_position,5.0)
	if target_hit:
		hit_feedback_time = 0.16
		var collider: Object = player.weapon.last_hit.get("collider")
		if collider != null and collider.is_in_group("training_targets"):
			target_hits += 1
			$Interface/Header/Targets.text = "CIBLES TOUCHÉES   %02d" % target_hits


func _on_health_changed(current: int, maximum: int) -> void:
	var bar: ProgressBar = $Interface/Header/Health/Bar
	bar.max_value = maximum
	bar.value = current
	$Interface/Header/Health/Value.text = "SANTÉ   %d / %d" % [current, maximum]
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = Color(1.0, 0.27, 0.18) if current <= 30 else Color(0.2, 0.85, 0.8)
	if current < previous_health:
		damage_feedback_time = 0.4
	previous_health = current


func _on_player_died() -> void:
	game_over = true
	show_pause()


func _on_drone_destroyed(_drone: CharacterBody3D) -> void:
	drones_destroyed += 1
	$Interface/Header/DroneCount.text = "HOSTILES NEUTRALISÉS   %02d / 03" % drones_destroyed
	if drones_destroyed == $Drones.get_child_count():
		$Interface/ClearBanner.show()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
