extends SceneTree

var failures := 0
var checks := 0
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func capture(path: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://../output/playwright/" + path))
	return img

func compare(a: Image, b: Image, label: String) -> void:
	var error := 0.0
	var changed := 0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x,y)
			var q := b.get_pixel(x,y)
			var delta := absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b)
			error += delta / 3.0
			if delta > .15: changed += 1
	var pixels := float(a.get_width()*a.get_height())
	print("IMAGE %s: mean RGB absolute difference %.6f; changed pixels %.3f percent" % [label,error/pixels,100.0*changed/pixels])
	check(error/pixels < .002, "Reference view preserved: " + label)

func run() -> void:
	game = load("res://missions/relay_run/mission.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	check(game.get_node("Arena").visible and game.get_node("UpperArena").visible, "PC scene keeps both original visibility flags")
	var collisions: Dictionary = {}
	for shape in game.find_children("*", "CollisionShape3D", true, false):
		collisions[shape.get_instance_id()] = [shape.global_transform,shape.shape,shape.disabled]
	var nodes := game.find_children("*", "MeshInstance3D", true, false).size()
	var culling: Node = preload("res://scripts/web_floor_culling.gd").new()
	game.overlay.hide()
	var graphics := DisplayServer.get_name() != "headless"
	var lower_image: Image
	if graphics: lower_image = await capture("perf-native-lower-off.png")
	game.add_child(culling)
	check(culling.active_floor==0 and game.get_node("Arena").visible and not game.get_node("UpperArena").visible, "Initial floor hides the inaccessible upper floor")
	if graphics: compare(lower_image,await capture("perf-native-lower-on.png"),"lower")
	game.player.global_position.y = 8.0
	culling.update_floor()
	check(culling.active_floor==0, "Switch has not happened at eight metres")
	game.player.global_position.y = 8.01
	culling.update_floor()
	check(culling.active_floor==1 and game.get_node("UpperArena").visible and not game.get_node("Arena").visible, "Switch occurs inside the closed rising cabin")
	check(game.get_node("Elevator").is_visible_in_tree(), "Lift is never masked with a floor")
	check(not game.get_node("Arena/Plafonds/Extraction").visible, "Lift shaft opening retains its original state")
	for key in collisions:
		var shape: CollisionShape3D = instance_from_id(key)
		check(shape.global_transform==collisions[key][0] and shape.shape==collisions[key][1] and shape.disabled==collisions[key][2], "Physics and collision state unchanged")
	check(nodes==game.find_children("*","MeshInstance3D",true,false).size(), "No model is removed or merged")
	game.player.global_position = Vector3(0,14.05,-102)
	culling.set_process(false)
	game.get_node("Arena").show()
	game.get_node("UpperArena").show()
	var upper_image: Image
	if graphics: upper_image = await capture("perf-native-upper-off.png")
	culling.active_floor = -1
	culling.update_floor()
	if graphics: compare(upper_image,await capture("perf-native-upper-on.png"),"upper")
	game.player.reset_to_spawn()
	culling.update_floor()
	check(culling.active_floor==0 and game.get_node("Arena").visible, "Returning to spawn restores the first floor")
	print("RESULT: %d floor culling checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
