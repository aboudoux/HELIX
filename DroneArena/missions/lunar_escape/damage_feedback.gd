extends Control
## Bearings stay attached to the attack's world origin as the camera turns.
const LIFETIME := 1.25
var impacts: Array[Dictionary] = []
var camera: Camera3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func receive_hit(origin: Vector3) -> void:
	if not visible: return
	# A burst refreshes an existing bearing instead of covering the whole screen.
	for impact in impacts:
		if impact.origin.distance_to(origin) < 2.0:
			impact.life = LIFETIME
			queue_redraw()
			return
	impacts.append({"origin": origin, "life": LIFETIME})
	if impacts.size() > 8: impacts.pop_front()
	queue_redraw()

func bearing(origin: Vector3) -> float:
	var local := camera.global_basis.inverse() * (origin-camera.global_position)
	return atan2(local.x, -local.z)-PI/2.0

func _process(delta: float) -> void:
	if get_tree().paused: return
	for i in range(impacts.size()-1,-1,-1):
		impacts[i].life -= delta
		if impacts[i].life <= 0: impacts.remove_at(i)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(camera): return
	var center := size*0.5
	var radius := minf(size.x,size.y)*0.19
	for impact in impacts:
		var angle := bearing(impact.origin)
		var alpha := minf(1.0,impact.life/0.65)
		draw_arc(center,radius,angle-0.23,angle+0.23,20,Color(0.15,0.01,0.015,alpha*0.85),13.0,true)
		draw_arc(center,radius,angle-0.22,angle+0.22,20,Color(1.0,0.12,0.16,alpha),7.0,true)
		draw_arc(center,radius-5,angle-0.19,angle+0.19,16,Color(1.0,0.6,0.58,alpha*0.7),1.5,true)
