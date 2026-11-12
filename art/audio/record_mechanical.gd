extends SceneTree
## Enregistrement du vrai mix, en temps réel (--max-fps 60, sans --fixed-fps).

var game: Node3D
var player: CharacterBody3D
var recorder: AudioEffectRecord
var started: int
var events: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame


func note(name: String) -> void:
	events.append({"name":name,"seconds":float(Time.get_ticks_msec()-started)/1000})


func open_scene(path: String) -> void:
	game = load(path).instantiate()
	root.add_child(game)
	current_scene = game
	player = game.player
	for drone in game.get_node("Drones").get_children():
		drone.attack_enabled = false
		drone.move_speed = 0
	game.start_exploration()


func place(position: Vector3) -> void:
	player.position = position
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	await frames(8)


func close_scene() -> void:
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false):
		sound.set_process(false)
		sound.stop()
	game.queue_free()
	paused = false
	await frames(4)
	OS.delay_msec(50)


func run() -> void:
	root.get_node("Difficulty").selected = 1
	await open_scene("res://scenes/main.tscn")
	var drones: Array = game.get_node("Drones").get_children()
	for index in range(1,drones.size()): drones[index].hide()
	var actor: CharacterBody3D = drones[0]
	actor.set_physics_process(false)
	actor.position = Vector3(0,2.4,12)
	await place(Vector3(0,.05,18))
	recorder = AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	var slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0,recorder)
	recorder.set_recording_active(true)
	started = Time.get_ticks_msec()
	note("drone_front")
	await create_timer(1.2).timeout
	actor.position = Vector3(5,2.4,15)
	note("drone_right")
	await create_timer(1.2).timeout
	actor.position = Vector3(-5,2.4,15)
	note("drone_left")
	await create_timer(1.2).timeout
	actor.position = Vector3(0,2.4,12)
	note("drone_front_loop")
	await create_timer(1.2).timeout
	actor.alive = false
	actor.rotor_sound.silence()
	note("silence")
	await create_timer(.25).timeout
	await close_scene()
	await open_scene("res://missions/relay_run/mission.tscn")
	game.director.engage_sector(0)
	for guard in game.director.get_children():
		guard.alive = false
		guard.hide()
		guard.rotor_sound.silence()
		guard.set_physics_process(false)
		guard.set_process(false)
	await place(game.relays[0].position+Vector3(0,.05,2))
	note("relay_activation")
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await create_timer(1.55).timeout
	game.gates[0].reset_gate()
	await place(Vector3(14,.05,23))
	note("door_near")
	game.gates[0].unlock()
	await create_timer(1.7).timeout
	player.health = 60
	note("repair_pickup")
	await place(game.get_node("Arena/Medical").get_child(0).position+Vector3(0,.05,0))
	await create_timer(.55).timeout
	await close_scene()
	await open_scene("res://missions/relay_run/boss_trial.tscn")
	game.boss.attack_enabled = false
	game.boss.move_speed = 0
	await place(Vector3(-10,.05,-59))
	player.look_at(Vector3(game.boss.position.x,player.position.y,game.boss.position.z))
	note("boss_rotor")
	await create_timer(2.0).timeout
	game.boss.alive = false
	game.boss.rotor_sound.silence()
	await create_timer(.25).timeout
	recorder.set_recording_active(false)
	var mix := recorder.get_recording()
	var destination := ProjectSettings.globalize_path("res://../art/audio/preview_mechanical.wav").simplify_path()
	var result := mix.save_to_wav(destination)
	var info := {"length_seconds":mix.get_length(),"events":events}
	var file := FileAccess.open(destination.get_basename()+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(info,"  "))
	file.close()
	AudioServer.remove_bus_effect(0,slot)
	await close_scene()
	OS.delay_msec(100)
	print("MECHANICAL_RECORDING ",JSON.stringify(info)," save=",result)
	quit(0 if result==OK and mix.get_length()>10 else 1)
