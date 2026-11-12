extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node3D = load("res://missions/relay_run/mission.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	var summary: Dictionary = {}
	var repeated: Dictionary = {}
	var counts: Dictionary = {}
	for mesh: MeshInstance3D in game.find_children("*", "MeshInstance3D", true, false):
		var parts := str(game.get_path_to(mesh)).split("/")
		var path := parts[0] + "/" + parts[1] if parts.size() > 1 else parts[0]
		summary[path] = summary.get(path, 0) + 1
		if mesh.mesh:
			var key := str(mesh.mesh.get_rid()) + str(mesh.material_override.get_rid() if mesh.material_override else "none")
			counts[key] = counts.get(key, 0) + 1
			repeated[key] = str(game.get_path_to(mesh))
	var repeats: Array = []
	for key in counts:
		if counts[key] >= 4: repeats.append({"count":counts[key], "example":repeated[key]})
	repeats.sort_custom(func(a,b): return a.count > b.count)
	print(JSON.stringify({"by_root":summary,"repeats":repeats.slice(0,30)},"  "))
	quit()
