extends Node
var squad: Node3D
var holding := false
var hold_points: Dictionary = {}
var focus: Node3D
var rescue: CharacterBody3D
var rescue_progress := 0.0
var panel: Label

func setup(team: Node3D) -> void:
	squad = team
	panel = squad.game.hud.label(squad.game.hud.content,"",14,Color("d6e9df"))
	squad.game.hud.pin(panel,Control.PRESET_TOP_RIGHT,Vector2(-330,165),Vector2(305,110))
	panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or not available(): return
	match event.keycode:
		KEY_C: follow()
		KEY_H: take_cover()
		KEY_T:
			var camera: Camera3D = squad.game.camera
			var hit: Dictionary = squad.game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*90,9))
			if squad.hostile_alive(hit.get("collider")): focus = hit.collider
			else: focus = null

func available() -> bool:
	return squad.difficulty_active and squad.game.pilot.in_control and not get_tree().paused and not squad.game.defeated and not squad.game.hud.title_card.visible

func follow() -> void:
	holding = false; hold_points.clear(); focus = null
	for actor in squad.members: actor.route_clock = 0

func take_cover() -> void:
	holding = true; hold_points.clear()
	for actor in squad.members:
		if not actor.recruited or actor.downed or actor.embarked: continue
		var destination: Vector3 = actor.global_position
		var threat: Node3D = focus if squad.hostile_alive(focus) else actor.target
		if squad.hostile_alive(threat):
			for i in range(12):
				var candidate: Vector3 = actor.global_position+Vector3(cos(i*TAU/12),0,sin(i*TAU/12))*3.2
				var floor_hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*.5,candidate-Vector3.UP*.7,1))
				if floor_hit.is_empty() or floor_hit.normal.y<.72: continue
				candidate.y = floor_hit.position.y+.04
				if not squad.clear_walk(actor.global_position,candidate): continue
				var blocked: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(squad.aim_point(threat),candidate+Vector3.UP*1.25,1))
				if not blocked.is_empty(): destination = candidate; break
		hold_points[actor.get_instance_id()] = destination
		actor.route_clock = 0

func _physics_process(delta: float) -> void:
	panel.visible = available()
	if not available(): return
	if not squad.hostile_alive(focus): focus = null
	panel.text = "C · Suivez-moi   H · À couvert\nT · Visez une cible et donnez l'ordre\n"+("POSITION TENUE" if holding else "FORMATION EN MOUVEMENT")+(" · TIR CONCENTRÉ" if focus!=null else "")
	var nearest: CharacterBody3D
	var distance := 2.4
	for actor in squad.members:
		if not actor.downed: continue
		var d: float = actor.global_position.distance_to(squad.game.pilot.global_position)
		if d < distance and actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(squad.game.pilot.get_aim_point(),actor.global_position+Vector3.UP*.45,1)).is_empty():
			nearest = actor; distance = d
	if nearest != rescue: rescue_progress = 0
	rescue = nearest
	if rescue == null: rescue_progress = 0; return
	if Input.is_physical_key_pressed(KEY_G) and squad.game.pilot.hurt_cooldown<=0:
		rescue_progress += delta
	else: rescue_progress = 0
	panel.text += "\nMaintenir G · Secourir %s · %d %%" % [rescue.identity,mini(100,int(rescue_progress/2.2*100))]
	if rescue_progress>=2.2:
		rescue.revive(); rescue = null; rescue_progress = 0
