extends Node
## Browser-only integration, shared by campaign and training. No gameplay shortcuts.

var game: Node3D
var was_running := false
var capture_grace := 0.0
var diagnostics := false
var report_remaining := 0.0
var floor_culling: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = get_parent()
	if game.has_node("UpperArena") and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('culling') !== 'off'")):
		floor_culling = preload("res://scripts/web_floor_culling.gd").new()
		game.add_child(floor_culling)
	# A browser tab is closed by the browser, not SceneTree.quit().
	game.get_node("Interface/Overlay/Card/Content/Quit").hide()
	# System fonts are unavailable in a browser. Bundle the missing menu symbols.
	var symbols := preload("res://assets/fonts/DejaVuSans.ttf")
	for control in game.find_children("*", "Control", true, false):
		if control.theme and control.theme.default_font:
			var font: Font = control.theme.default_font
			if not symbols in font.fallbacks:
				font.fallbacks = [symbols]
	for world in game.find_children("*", "WorldEnvironment", true, false):
		if world.environment:
			world.environment = world.environment.duplicate()
			world.environment.glow_enabled = false
			world.environment.ssao_enabled = false
	diagnostics = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('diagnostics') === '1'"))
	if diagnostics and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('profile') === '1'")):
		add_child(preload("res://scripts/web_profiler.gd").new())


func _input(event: InputEvent) -> void:
	# Ignore the browser's initial pointer recenter event, which can otherwise
	# turn the camera sharply when a menu click captures the mouse.
	if event is InputEventMouseMotion and not get_tree().paused and (not was_running or capture_grace > 0.6):
		get_viewport().set_input_as_handled()
		return
	# Escape also releases browser pointer lock. Never use it to recapture it:
	# Chromium may reject recapture immediately after its default unlock gesture.
	if event.is_action_pressed("pause") and not event.is_echo():
		if game.has_started and not game.is_run_finished():
			game.show_pause()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if get_tree().paused:
		var controls: Label = game.get_node("Interface/Overlay/Card/Content/Controls")
		controls.text = controls.text.replace("Pause / Reprendre", "Pause · Reprise par clic")
	var running: bool = game.has_started and not get_tree().paused
	if running and not was_running:
		capture_grace = 0.75
	was_running = running
	if running:
		capture_grace = maxf(0.0, capture_grace - delta)
		# Browser Escape and permission/focus changes need not emit a Godot key event.
		if capture_grace == 0.0 and not bool(JavaScriptBridge.eval("document.pointerLockElement !== null")):
			game.show_pause()
	report_remaining -= delta
	if diagnostics and report_remaining <= 0.0:
		report_remaining = 0.2
		report_state()


func report_state() -> void:
	# Read-only, opt-in QA state for this canvas; no commands or invulnerability.
	var p: CharacterBody3D = game.player
	var pos := p.global_position
	var enemies: Array = []
	for actor in get_tree().get_nodes_in_group("enemies"):
		if game.is_ancestor_of(actor) and actor.alive:
			var at: Vector3 = actor.global_position
			enemies.append({"name": str(actor.name), "position": [at.x, at.y, at.z], "health": actor.health})
	var button: Rect2 = game.resume_button.get_global_rect()
	var report := {
		"scene": game.scene_file_path, "started": game.has_started,
		"paused": get_tree().paused, "finished": game.is_run_finished(),
		"position": [pos.x, pos.y, pos.z], "yaw": p.rotation.y,
		"pitch": p.head.rotation.x, "health": p.health,
		"ammo": p.weapon.ammo, "reloading": p.weapon.is_reloading,
		"aim": p.weapon.aim_blend, "crouching": p.is_crouching,
		"sprinting": p.is_sprinting, "hits": game.target_hits,
		"destroyed": game.drones_destroyed, "enemies": enemies,
		"fps": Engine.get_frames_per_second(),
		"rendered_floor": floor_culling.active_floor if floor_culling else -1,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"audio_peak_db": AudioServer.get_bus_peak_volume_left_db(0, 0),
		"playback_type": ProjectSettings.get_setting("audio/general/default_playback_type"),
		"resume_rect": [button.position.x, button.position.y, button.size.x, button.size.y],
		"viewport": [game.get_viewport().get_visible_rect().size.x, game.get_viewport().get_visible_rect().size.y]
	}
	if "stage" in game:
		report["stage"] = game.stage
	JavaScriptBridge.eval("window.helixDiagnostics = " + JSON.stringify(report))
