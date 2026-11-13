extends Node3D
## Two-link IK with planted feet. Coordinates stay in world space during stance,
## so the same gait works on the floor, walls and ceiling without foot sliding.
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const UPPER := 0.62
const LOWER := 0.70
var side := 1.0
var rest := Vector3.ZERO
var phase_offset := 0.0
var hip := Vector3.ZERO
var upper: Node3D
var lower: Node3D
var knee_joint: Node3D
var toe: Node3D
var piston: Node3D
var planted := Vector3.ZERO
var lift_start := Vector3.ZERO
var landing := Vector3.ZERO
var previous_phase := -1.0
var initialized := false
var swinging := false
var damaged := false


func build(index: int, direction: float, shell: Material) -> void:
	side = direction
	name = "Leg%d_%s" % [index,"L" if side<0 else "R"]
	hip = Vector3(side*0.37,-0.025,-0.36+index*0.23)
	rest = Vector3(side*(1.06 if index in [0,3] else 1.20),-0.55,-0.76+index*0.49)
	phase_offset = 0.5 if (index+int(side>0))%2 else 0.0
	WORLD.ball(self,hip,Vector3.ONE*0.16,WORLD.STEEL)
	upper = Node3D.new()
	upper.name = "HipLink"
	add_child(upper)
	KIT.rod(upper,Vector3.ZERO,Vector3.UP*UPPER,0.043,WORLD.FRAME)
	KIT.bevel(upper,Vector3(0,UPPER*0.49,0),Vector3(0.13,UPPER*0.64,0.105),0.022,shell)
	KIT.bevel(upper,Vector3(0,UPPER*0.49,-0.055),Vector3(0.028,UPPER*0.39,0.012),0.004,WORLD.AMBER)
	lower = Node3D.new()
	lower.name = "KneeLink"
	add_child(lower)
	KIT.rod(lower,Vector3.ZERO,Vector3.UP*LOWER,0.035,WORLD.STEEL)
	KIT.bevel(lower,Vector3(0,LOWER*0.35,0),Vector3(0.095,LOWER*0.53,0.085),0.018,shell)
	knee_joint = WORLD.ball(self,Vector3.ZERO,Vector3.ONE*0.18,WORLD.FRAME)
	knee_joint.name = "Bearing"
	WORLD.ball(knee_joint,Vector3(side*0.082,0,0),Vector3(0.025,0.09,0.09),WORLD.AMBER)
	toe = Node3D.new()
	toe.name = "MagneticClaw"
	add_child(toe)
	KIT.bevel(toe,Vector3.ZERO,Vector3(0.12,0.045,0.15),0.013,WORLD.FRAME)
	for x in [-0.04,0.04]:
		KIT.rod(toe,Vector3(x,0.015,-0.02),Vector3(x,-0.012,-0.095),0.014,WORLD.STEEL)
	piston = KIT.rod(self,Vector3.ZERO,Vector3.UP,0.018,WORLD.STEEL)
	piston.name = "Hydraulic"
	solve(rest)


func surface_point(body: CharacterBody3D, local: Vector3) -> Vector3:
	var point := global_transform*local
	var normal := body.global_basis.y
	var query := PhysicsRayQueryParameters3D.create(point+normal*0.32,point-normal*0.40,1,[body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position+normal*0.025 if not hit.is_empty() else point


func step(body: CharacterBody3D, gait: float) -> void:
	var phase := fposmod(gait+phase_offset,1.0)
	if not initialized or global_position.distance_to(planted)>3.0:
		planted = surface_point(body,rest)
		landing = planted
		lift_start = planted
		initialized = true
		previous_phase = phase
	var was_swinging := swinging
	swinging = phase<0.36
	if swinging and (not was_swinging or phase<previous_phase):
		lift_start = planted
		landing = surface_point(body,rest+Vector3.FORWARD*0.23)
	if swinging:
		var blend := phase/0.36
		planted = lift_start.lerp(landing,smoothstep(0,1,blend))+body.global_basis.y*sin(blend*PI)*(0.065 if damaged else 0.20)
	elif was_swinging:
		planted = landing
	previous_phase = phase
	solve(to_local(planted))


func solve(target: Vector3) -> void:
	var difference := target-hip
	var distance := clampf(difference.length(),0.12,UPPER+LOWER-0.012)
	var direction := difference.normalized()
	var bend := Vector3(side*0.35,1.0,0)
	bend = (bend-direction*bend.dot(direction)).normalized()
	var along := (UPPER*UPPER-LOWER*LOWER+distance*distance)/(2*distance)
	var height := sqrt(maxf(0.0,UPPER*UPPER-along*along))
	var knee := hip+direction*along+bend*height
	var foot := hip+direction*distance
	upper.position = hip
	upper.basis = Basis(Quaternion(Vector3.UP,hip.direction_to(knee)))
	lower.position = knee
	lower.basis = Basis(Quaternion(Vector3.UP,knee.direction_to(foot)))
	knee_joint.position = knee
	toe.position = foot
	var piston_start := hip+Vector3(side*0.045,0.07,0)
	var piston_end := knee.lerp(foot,0.24)
	piston.position = (piston_start+piston_end)*0.5
	piston.basis = Basis(Quaternion(Vector3.UP,piston_start.direction_to(piston_end)))
	piston.scale.y = piston_start.distance_to(piston_end)


func fold_wreck() -> void:
	# Duplicated wrecks recover their joint references; no live AI is carried over.
	upper = get_node("HipLink")
	lower = get_node("KneeLink")
	knee_joint = get_node("Bearing")
	toe = get_node("MagneticClaw")
	piston = get_node("Hydraulic")
	hip = upper.position
	side = signf(hip.x)
	create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_method(solve,toe.position,Vector3(side*0.43,-0.16,hip.z-0.12),0.52)
