extends SceneTree
## Ressources Godot sérialisées par la version locale de l'éditeur.

func _initialize() -> void:
	var sets := {
		"rifle": ["shot.wav","shot_02.wav","shot_03.wav"],
		"enemy_rifle": ["enemy_shot.wav","enemy_shot_02.wav"],
		"armor_impact": ["drone_impact_01.wav","drone_impact_02.wav","drone_impact_03.wav"],
	}
	for name in sets:
		var randomizer := AudioStreamRandomizer.new()
		randomizer.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		randomizer.random_volume_offset_db = .7
		randomizer.streams_count = sets[name].size()
		for i in range(sets[name].size()):
			var sample := load("res://audio/"+sets[name][i]) as AudioStream
			if sample == null:
				push_error("Son introuvable : " + sets[name][i])
				quit(1)
				return
			randomizer.set("stream_%d/stream" % i, sample)
		var result := ResourceSaver.save(randomizer,"res://audio/"+name+".tres")
		if result != OK:
			push_error("Impossible d'enregistrer " + name)
			quit(1)
			return
	quit()
