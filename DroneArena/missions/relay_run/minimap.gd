extends Control

var mission: Node3D


func _ready() -> void:
	mission = get_tree().current_scene


func point(x: float, z: float) -> Vector2:
	var r: Array = active_layout().nav_bounds
	var scale_factor := minf((size.x - 14) / float(r[2]), (size.y - 14) / float(r[3]))
	return Vector2((size.x - r[2]*scale_factor)*.5 + (x-r[0])*scale_factor, 7 + (z-r[1])*scale_factor)


func _process(_delta: float) -> void:
	if mission == null:
		mission = get_tree().current_scene
	queue_redraw()


func _draw() -> void:
	if mission == null or not "layout" in mission or mission.layout.is_empty():
		return
	var plan := active_layout()
	var progress: int = mission.stage-5 if mission.player.position.y>10 else mission.stage
	for i in range(plan.floors.size()):
		var r: Array = plan.floors[i]
		var rect := Rect2(point(r[0], r[1]), point(r[0]+r[2], r[1]+r[3])-point(r[0],r[1]))
		var color := Color(.12,.24,.29) if plan.floor_sector[i] > progress else Color(.13,.36,.38)
		draw_rect(rect, color)
		draw_rect(rect, Color(.4,.65,.68), false, 1)
	for i in range(plan.relays.size()):
		var p: Array = plan.relays[i]
		var color := Color(.3,.95,.83) if i < progress else (Color(1,.55,.2) if i == progress else Color(.4,.5,.52))
		draw_circle(point(p[0],p[1]), 4, color)
	for i in range(plan.gates.size()):
		var gate: Array = plan.gates[i]
		draw_line(point(gate[0]-3,gate[1]),point(gate[0]+3,gate[1]),Color(.3,.95,.83) if (mission.upper_gates if mission.player.position.y>10 else mission.gates)[i].fully_open else Color(1,.55,.2),2)
	var exit: Array = plan.extraction
	draw_circle(point(exit[0],exit[1]), 5, Color(.3,.95,.83) if mission.stage in [4,8] else Color(.4,.5,.52), false, 1.5)
	var boss: CharacterBody3D = mission.alpha if mission.player.position.y>10 else mission.boss
	if boss.alive:
		var boss_point := point(boss.position.x,boss.position.z)
		draw_circle(boss_point,5,Color(1,.15,.05))
		draw_circle(boss_point,8,Color(1,.35,.12),false,1.5)
	var player_pos: Vector3 = mission.player.global_position
	var here := point(player_pos.x, player_pos.z)
	var forward: Vector3 = -mission.player.global_basis.z
	var direction := Vector2(forward.x,forward.z)
	var side := Vector2(-direction.y,direction.x)
	draw_colored_polygon(PackedVector2Array([here+direction*7,here-direction*4+side*4,here-direction*4-side*4]),Color.WHITE)


func active_layout() -> Dictionary:
	return mission.upper_layout if mission.player.position.y>10 else mission.layout
