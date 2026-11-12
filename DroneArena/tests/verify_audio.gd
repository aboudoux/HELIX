extends "res://tests/verify.gd"
## Déclenchements réels des nouveaux sons ; --record capture le mix natif en temps réel.

var director: Node3D
var drone: CharacterBody3D


func shoot() -> void:
	mouse_button(true)
	await frames(2)
	mouse_button(false)
	await frames(15)


func record_demo() -> void:
	game.restart_exploration()
	for actor in director.get_children():
		actor.move_speed = 0.0
		actor.attack_enabled = false
	await put_player(Vector3(0,.05,18))
	var recorder := AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	var effect_index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0,recorder)
	recorder.set_recording_active(true)
	# Deux tirs libres, puis deux drones détruits en trois coups, et une riposte.
	player.head.rotation.x = deg_to_rad(65)
	await create_timer(.25).timeout
	await shoot()
	await create_timer(.28).timeout
	await shoot()
	for index in range(2):
		drone = director.get_child(index)
		drone.position = Vector3(-2 if index == 0 else 3,2.4,11)
		drone.velocity = Vector3.ZERO
		await aim_at(drone.position)
		await create_timer(.32).timeout
		Input.action_press("fire")
		await create_timer(.48).timeout
		Input.action_release("fire")
		await create_timer(.72).timeout
		check(not drone.alive,"Rafale enregistrée : drone neutralisé")
	drone = director.get_child(0)
	drone.reset_drone()
	drone.position = Vector3(0,2.4,12)
	drone.move_speed = 0.0
	drone.rotation.y = PI
	drone.cooldown = 0.0
	drone.attack_enabled = true
	await aim_at(drone.position)
	await create_timer(1.65).timeout
	drone.attack_enabled = false
	await create_timer(.8).timeout
	recorder.set_recording_active(false)
	var recording := recorder.get_recording()
	check(recording != null and recording.get_length() > 6,"Mix natif enregistré avec tirs et impacts")
	var destination := ProjectSettings.globalize_path("res://../art/audio/preview_combat.wav").simplify_path()
	check(recording.save_to_wav(destination) == OK,"Extrait sonore enregistré dans art/audio/preview_combat.wav")
	AudioServer.remove_bus_effect(0,effect_index)


func check_resources() -> void:
	for name in ["rifle","enemy_rifle","armor_impact"]:
		var resource := load("res://audio/"+name+".tres") as AudioStreamRandomizer
		check(resource != null and resource.streams_count >= 2,"Variantes importées pour "+name)
		var valid := resource.playback_mode == AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		for index in range(resource.streams_count):
			var sample := resource.get_stream(index) as AudioStreamWAV
			valid = valid and sample != null and sample.get_length() > .25 and sample.get_length() < .6 and sample.loop_mode == AudioStreamWAV.LOOP_DISABLED
		check(valid,"Variantes courtes, sans boucle ni répétition immédiate pour "+name)
	check(AudioServer.get_bus_effect_count(0) == 1 and AudioServer.get_bus_effect(0,0) is AudioEffectHardLimiter,"Limiteur chargé sur le mix principal")
	check(is_equal_approx(AudioServer.get_bus_effect(0,0).ceiling_db,-1.0),"Marge du mix réglée à -1 dB")


func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	director = game.get_node("Drones")
	drone = director.get_child(0)
	await frames(5)
	check_resources()
	check(drone.impact_sound is AudioStreamPlayer3D and drone.impact_sound.max_polyphony == 3,"Impacts attachés au drone dans le monde 3D")
	for actor in director.get_children():
		actor.attack_enabled = false
		actor.move_speed = 0.0
	game.resume_button.pressed.emit()
	await frames(8)
	await put_player(Vector3(0,.05,18))
	drone.position = Vector3(0,2.4,12)
	drone.velocity = Vector3.ZERO
	await aim_at(drone.position)
	await shoot()
	check(drone.health == 2 and drone.impact_sound.playing,"Un tir réel déclenche l'impact métallique sur le drone")
	check(player.weapon.shot_sound.playing,"Le tir de carabine utilise son nouveau son")
	await tap(KEY_ESCAPE)
	check(drone.impact_sound.stream_paused,"La pause suspend l'impact en cours")
	mouse_button(true)
	await frames(15)
	mouse_button(false)
	await frames(3)
	check(drone.health == 2,"Le menu ne déclenche aucun nouvel impact")
	game.resume_button.pressed.emit()
	await frames(3)
	await shoot()
	check(drone.health == 1 and drone.impact_sound.playing,"Le deuxième tir déclenche un nouvel impact après la reprise")
	await shoot()
	check(not drone.alive and is_instance_valid(drone.wreck) and drone.get_node_or_null("DestructionSound")==null,"Le dernier impact déclenche la chute sans son d'explosion")
	await frames(40)
	check(drone.wreck.impact_count==1 and drone.wreck.crash_sound.playing,"Le contact avec le sol déclenche le choc métallique")
	check(not drone.receive_hit() and game.drones_destroyed == 1,"Un drone détruit ne produit plus de nouvelles touches")
	game.show_pause()
	game.reset_button.pressed.emit()
	await frames(3)
	check(not drone.impact_sound.playing and drone.wreck==null,"Recommencer arrête les sons et retire l'ancienne épave")
	await put_player(Vector3(0,.05,18))
	drone.position = Vector3(0,2.4,12)
	drone.velocity = Vector3.ZERO
	await aim_at(drone.position)
	var wall := make_blocker(Vector3(0,1.5,15),Vector3(3,3,.4))
	await frames(3)
	await shoot()
	check(drone.health == 3 and not drone.impact_sound.playing,"Un obstacle protège le drone et ne produit pas de faux impact")
	wall.queue_free()
	await frames(3)
	if "--record" in OS.get_cmdline_user_args():
		await record_demo()
	print("RESULT: %d audio checks, %d failures" % [checks,failures])
	paused = false
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false):
		sound.stop()
	OS.delay_msec(50)
	game.queue_free()
	await frames(3)
	OS.delay_msec(80)
	quit(1 if failures else 0)
