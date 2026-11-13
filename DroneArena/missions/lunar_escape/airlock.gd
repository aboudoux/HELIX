extends Node3D
## Two physical doors, one pressure volume. No door can bypass the interlock.
var inner: Node3D
var outer: Node3D
var pressure := 1.0
var cycling := false
var chamber := AABB()
var display: Label3D
var pump: AudioStreamPlayer3D
var cycles := 0
var power_available := true

func set_power_available(value: bool) -> void:
	power_available=value
	if is_instance_valid(display): display.visible=value

func setup(inside: Node3D, outside: Node3D, bounds: AABB) -> void:
	inner = inside; outer = outside; chamber = bounds
	inner.airlock = self; outer.airlock = self
	pump = AudioStreamPlayer3D.new()
	pump.stream = preload("res://audio/airlock_pressure.wav")
	pump.volume_db = -12; pump.max_distance = 16
	pump.position = chamber.get_center()+Vector3.UP
	add_child(pump)
	display = Label3D.new()
	display.position = chamber.get_center()+Vector3(2.7,1,0)
	display.rotation.y = -PI/2
	display.font_size = 40; display.pixel_size = 0.004
	add_child(display)
	update_display()

func contains(point: Vector3) -> bool:
	return chamber.has_point(point+Vector3.UP*0.1)

func can_open(door: Node3D) -> bool:
	var other: Node3D = outer if door==inner else inner
	return not cycling and not inner.secured and not other.is_open and not other.opening and absf(pressure-(1.0 if door==inner else 0.0))<0.01

func hint(door: Node3D) -> String:
	if inner.secured: return "SAS VERROUILLÉ · "+inner.title
	if cycling: return "SAS · Équilibrage de pression %d %%"%roundi(pressure*100)
	if inner.opening or outer.opening: return "SAS · Porte en mouvement"
	if door==inner and door.is_open and contains(get_tree().current_scene.pilot.global_position) and get_tree().current_scene.pilot.oxygen<95:
		return "COMBINAISON · Recharge d’air en cours · %d %%"%ceili(get_tree().current_scene.pilot.oxygen)
	if door.is_open: return "E   Refermer la porte · Cycle de pression"
	var other: Node3D = outer if door==inner else inner
	if other.is_open or other.opening: return "Refermez l’autre porte du sas [E]"
	return "E   Ouvrir · "+("Intérieur pressurisé" if door==inner else "Surface lunaire")

func operate(door: Node3D) -> bool:
	if cycling or inner.secured or inner.opening or outer.opening: return false
	if door.is_open:
		if door==inner and contains(get_tree().current_scene.pilot.global_position) and get_tree().current_scene.pilot.oxygen<95: return false
		if not await door.close(): return false
		await equalize(0.0 if door==inner else 1.0)
		return true
	var other: Node3D = outer if door==inner else inner
	if other.is_open: return false
	await equalize(1.0 if door==inner else 0.0)
	return await door.open()

func equalize(target: float) -> void:
	if is_equal_approx(pressure,target): return
	if inner.is_open or outer.is_open or inner.opening or outer.opening: return
	cycling = true; cycles += 1
	pump.pitch_scale = 0.75 if target>pressure else 1.15
	pump.play()
	var tween := create_tween()
	tween.tween_method(set_pressure,pressure,target,3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	pump.stop(); cycling = false; update_display()

func set_pressure(value: float) -> void:
	pressure = value; update_display()

func update_display() -> void:
	display.text = "SAS · %d kPa\n%s"%[roundi(pressure*101),"ÉQUILIBRAGE…" if cycling else ("AIR RESPIRABLE" if pressure>0.95 else "VIDE · COMBINAISON")]
	display.modulate = Color("ffbe67") if cycling else (Color("80e9dc") if pressure>0.95 else Color("ff815d"))

func escort_request(actor: Node3D, door: Node3D) -> void:
	# Companions may operate the same cycle after the player has passed through.
	var pilot: Node3D = get_tree().current_scene.pilot
	if cycling or inner.opening or outer.opening or inner.secured or contains(pilot.global_position): return
	if contains(actor.global_position):
		var other: Node3D = outer if door==inner else inner
		if other.is_open: operate(other)
		else: operate(door)
	else:
		var other: Node3D = outer if door==inner else inner
		if other.is_open: operate(other)
		else: operate(door)
