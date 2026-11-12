extends SceneTree
## Démonstration des vrais tirs et débris, enregistrable avec --write-movie.

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.get_node("Difficulty").selected = 1
	var game := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	for actor in game.get_node("Drones").get_children():
		actor.attack_enabled = false
		actor.move_speed = 0.0
	game.start_exploration()
	var player: CharacterBody3D = game.get_node("Player")
	var drone: CharacterBody3D = game.get_node("Drones").get_child(0)
	player.position = Vector3(0,.05,18)
	drone.position = Vector3(0,2.4,14)
	drone.velocity = Vector3.ZERO
	for frame in range(8):
		await physics_frame
	player.look_at(Vector3(drone.position.x,player.position.y,drone.position.z))
	player.head.look_at(drone.position)
	# Trois clics normaux, puis le temps de voir tomber et disparaître les fragments.
	for frame in range(286):
		if frame in [24,54,84]:
			Input.action_press("fire")
		if frame in [26,56,86]:
			Input.action_release("fire")
		await physics_frame
		await process_frame
	quit()
