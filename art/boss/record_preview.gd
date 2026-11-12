extends SceneTree
## Capture d'un combat dans le vrai moteur, sans modifier les préférences.


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.get_node("Difficulty").selected = 1
	var game := load("res://missions/relay_run/boss_trial.tscn").instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	game.start_exploration()
	var player: CharacterBody3D = game.player
	var boss: CharacterBody3D = game.boss
	player.position = Vector3(-10,.05,-58)
	for frame in range(8): await physics_frame
	for frame in range(540):
		player.look_at(Vector3(boss.position.x,player.position.y,boss.position.z))
		player.head.look_at(boss.global_position)
		if frame==130: Input.action_press("fire")
		if frame==510: Input.action_release("fire")
		await physics_frame
		await process_frame
	Input.action_release("fire")
	game.process_mode = Node.PROCESS_MODE_DISABLED
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false): sound.stop()
	OS.delay_msec(50)
	game.queue_free()
	for frame in range(4):
		await physics_frame
		await process_frame
	OS.delay_msec(80)
	quit()
