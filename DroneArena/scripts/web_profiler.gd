extends Node
## Opt-in measurements of completed Godot draw frames, never browser rAF ticks.

var last_draw_usec: int = 0
var batch: Array = []
var flush_remaining := 0.5
var game: Node3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = get_parent().game
	JavaScriptBridge.eval("window.helixFrameSamples = []")
	RenderingServer.frame_post_draw.connect(_after_draw)

func _input(event: InputEvent) -> void:
	# Profiling is deliberately a fixed-view experiment. Physical mouse movement
	# must not change the workload while comparing two renderer configurations.
	if game.has_started and not get_tree().paused:
		if event is InputEventMouseMotion or (event is InputEventKey and not event.is_action("pause")):
			get_viewport().set_input_as_handled()

func _after_draw() -> void:
	var now := Time.get_ticks_usec()
	if last_draw_usec != 0:
		batch.append([
			now, (now - last_draw_usec) / 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		])
	last_draw_usec = now

func _process(delta: float) -> void:
	flush_remaining -= delta
	if flush_remaining <= 0.0:
		flush_remaining = 0.5
		if not batch.is_empty():
			JavaScriptBridge.eval("window.helixFrameSamples.push(..." + JSON.stringify(batch) + "); if (window.helixFrameSamples.length > 12000) window.helixFrameSamples.splice(0,window.helixFrameSamples.length-12000)")
			batch.clear()
