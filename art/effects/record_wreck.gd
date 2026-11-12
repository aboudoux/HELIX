extends SceneTree
## Trois tirs réels, chute et épave persistante, enregistrables avec Movie Maker.


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.get_node("Difficulty").selected = 1
	var game := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	var actors: Array = game.get_node("Drones").get_children()
	for actor in actors:
		actor.attack_enabled = false
		actor.move_speed = 0
	for i in range(1,actors.size()): actors[i].hide()
	game.start_exploration()
	var player: CharacterBody3D = game.player
	var drone: CharacterBody3D = actors[0]
	player.position = Vector3(0,.05,18)
	drone.position = Vector3(0,2.4,14)
	drone.rotation.y = PI
	drone.velocity = Vector3.ZERO
	for frame in range(8): await physics_frame
	for frame in range(350):
		var target: Vector3 = drone.wreck.global_position if is_instance_valid(drone.wreck) else drone.global_position
		player.look_at(Vector3(target.x,player.position.y,target.z))
		player.head.look_at(target)
		if frame in [24,44,64]: Input.action_press("fire")
		if frame in [26,46,66]: Input.action_release("fire")
		await physics_frame
		await process_frame
	Input.action_release("fire")
	for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false):
		sound.set_process(false)
		sound.stop()
	OS.delay_msec(50)
	game.queue_free()
	for frame in range(4):
		await physics_frame
		await process_frame
	OS.delay_msec(80)
	quit()
