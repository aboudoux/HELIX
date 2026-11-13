extends Node3D
const ACTOR := preload("res://missions/lunar_escape/escort.gd")
const NAV := preload("res://missions/lunar_escape/escort_navigation.gd")
const TERRAIN := preload("res://missions/lunar_escape/regolith.gd")
var game: Node3D
var members: Array[CharacterBody3D] = []
var enemies: Array[Node3D] = []
var navigation: Dictionary = {}
var trail := PackedVector3Array()
var update_clock := 0.0
var warning_clock := 0.0
var rear_warning_left := 0.0
var rear_warning_cooldown := 0.0
var rear_warning := ""
var confirmed_hits := 0
var difficulty_active := false
var panel: Label
var riding: Node3D
var pad_locked := false
var commands: Node

func setup(campaign: Node3D) -> void:
	game = campaign
	panel = game.hud.label(game.hud.content,"",16,Color("b8dfd4"))
	game.hud.pin(panel,Control.PRESET_TOP_RIGHT,Vector2(-285,28),Vector2(260,112))
	panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	commands = preload("res://missions/lunar_escape/squad_commands.gd").new()
	add_child(commands); commands.setup(self)
	game.pilot.weapon.fired.connect(func(_point, _hit): hear_shot(game.pilot.get_aim_point()))

func create_member(identity: String, parent: Node3D, point: Vector3, slot: int) -> CharacterBody3D:
	var actor := ACTOR.new()
	actor.identity = identity; actor.slot = slot; actor.squad = self
	parent.add_child(actor)
	actor.name = ["Mael","Noor","LinaCompagne"][slot]
	actor.position = point
	actor.refuge_origin = actor.global_position
	actor.refuge_goal = actor.global_position
	actor.refuge_wait += slot*0.35
	members.append(actor)
	actor.avatar.gun.hide()
	return actor

func recruit(slot: int) -> void:
	for actor in members:
		if actor.slot==slot and not actor.recruited: actor.recruit()
	if not difficulty_active:
		difficulty_active = true
		game.speak("ÉQUIPE FORMÉE · Protégez vos compagnons. Leur mort fait échouer la mission. Les renforts ennemis passent en alerte.",8)
	update_enemies()

func hostile_alive(enemy) -> bool:
	return is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.is_visible_in_tree() and enemy.can_process() and enemy.is_physics_processing() and enemy.get("health")!=null and enemy.health>0 and (enemy.get("active")==null or enemy.active)

func aim_point(enemy) -> Vector3:
	if not is_instance_valid(enemy): return Vector3.ZERO
	if enemy.get("core")!=null and enemy.core.visible: return enemy.core.global_position
	if enemy.has_method("get_aim_point"): return enemy.get_aim_point()
	return enemy.global_position+Vector3.UP*(0.9 if enemy.get("burst_remaining")!=null else 0.15)

func update_enemies() -> void:
	enemies.clear()
	for actor in game.find_children("*","CharacterBody3D",true,false)+game.find_children("*","AnimatableBody3D",true,false):
		if not actor.has_method("receive_hit_at") or actor.is_in_group("escorts"): continue
		enemies.append(actor)
		if not difficulty_active or actor.has_meta("escort_scaled"): continue
		actor.set_meta("escort_scaled",true)
		if actor.get("health")!=null and actor.health>0:
			var hp := ceili(actor.health*1.4)
			if actor.get("max_health")!=null: actor.max_health = ceili(actor.max_health*1.4)
			actor.health = hp
		if actor.get("move_speed")!=null: actor.move_speed *= 1.12
		if actor.get("fire_interval")!=null: actor.fire_interval *= 0.82
		if actor.get("subsystem_hp")!=null:
			actor.subsystem_hp.assign([16,16])

func pick_target(enemy: Node3D, fallback: CharacterBody3D) -> CharacterBody3D:
	var chosen: CharacterBody3D = game.pilot
	if not difficulty_active or not game.pilot.in_control: return chosen
	var distance := enemy.global_position.distance_to(chosen.global_position)*0.95
	for actor in members:
		if not actor.recruited or not actor.alive or actor.downed or actor.embarked: continue
		var d := enemy.global_position.distance_to(actor.global_position)
		if d>28 or d>=distance: continue
		var hit := game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(enemy.global_position+Vector3.UP*0.4,actor.get_aim_point(),17,[enemy.get_rid()]))
		if hit.get("collider")==actor: chosen = actor; distance = d
	return chosen

func clear_walk(from: Vector3, to: Vector3) -> bool:
	if absf(from.y-to.y)>0.35: return false
	var shape := CapsuleShape3D.new()
	shape.radius = 0.30; shape.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape; query.collision_mask = 1
	query.transform = Transform3D(Basis.IDENTITY,from+Vector3.UP*0.90)
	query.motion = to-from
	return game.get_world_3d().direct_space_state.cast_motion(query)[0]>0.99

func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	to = TERRAIN.nearest_image(to,from)
	for base in range(3):
		if absf(from.x)<74 and absf(to.x)<74 and absf(from.z-game.WORLD.BASE_Z[base])<64 and absf(to.z-game.WORLD.BASE_Z[base])<64:
			if not navigation.has(base):
				var nav := NAV.new()
				nav.build(game,base)
				navigation[base] = nav
			return navigation[base].route(from,to)
	if clear_walk(from,to): return PackedVector3Array([from,to])
	for i in range(trail.size()-1,-1,-1):
		var waypoint := TERRAIN.nearest_image(trail[i],from)
		if from.distance_to(waypoint)<12 and clear_walk(from,waypoint): return PackedVector3Array([from,waypoint])
	# Short grounded steps let companions follow the new rolling terrain safely.
	if absf(from.x)>80 or from.z>80 or from.z<-860:
		for length in [2.0,1.0,0.6]:
			var next: Vector3 = from+Vector3(to.x-from.x,0,to.z-from.z).normalized()*length
			var hit := game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(next+Vector3.UP*2,next-Vector3.UP*3,1))
			if not hit.is_empty() and hit.normal.y>0.72:
				next.y = hit.position.y+0.04
				if clear_walk(from,next): return PackedVector3Array([from,next])
	return PackedVector3Array()

func can_board() -> bool:
	for actor in members:
		if actor.recruited and (actor.downed or not actor.alive or actor.global_position.distance_to(TERRAIN.nearest_image(game.pilot.global_position,actor.global_position))>12): return false
	return true

func relocate() -> void:
	commands.follow()
	trail.clear()
	for actor in members:
		if not actor.recruited: continue
		actor.reset_at(safe_position(game.pilot.global_position,actor))
	riding = null

func safe_position(anchor: Vector3, actor: CharacterBody3D) -> Vector3:
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.30; capsule.height = 1.78
	query.shape = capsule; query.collision_mask = 27; query.exclude = [actor.get_rid()]
	var space := game.get_world_3d().direct_space_state
	for radius in [1.4,2.2,3.2,4.5]:
		for i in range(16):
			var angle: float = (i+actor.slot*5)*TAU/16
			var point: Vector3 = anchor+Vector3(sin(angle),0,cos(angle))*radius
			var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.6,point-Vector3.UP*1.2,1))
			if floor_hit.is_empty() or floor_hit.normal.y<0.7: continue
			point.y = floor_hit.position.y+0.04
			query.transform = Transform3D(Basis.IDENTITY,point+Vector3.UP*0.91)
			if space.intersect_shape(query,1).is_empty() and clear_walk(anchor,point): return point
	return anchor

func avoid_blast(actor: CharacterBody3D) -> Vector3:
	if not is_instance_valid(game.mothership) or not game.mothership.active: return Vector3.ZERO
	for marker in game.mothership.strike_marks:
		if not marker.visible: continue
		var away: Vector3 = actor.global_position-marker.global_position
		away.y = 0
		if away.length()<game.mothership.strike_radius+0.8:
			return away.normalized() if away.length()>0.1 else Vector3.RIGHT
	return Vector3.ZERO

func wave_near(actor: CharacterBody3D) -> bool:
	if not is_instance_valid(game.mothership) or not game.mothership.wave_active: return false
	var delta_position: Vector3 = actor.global_position-game.mothership.wave_origin
	var gap: float = Vector2(delta_position.x,delta_position.z).length()-game.mothership.wave_radius
	# Allow time to clear the wave with the slower lunar jump impulse.
	return gap>0.5 and gap<5.0

func restore_members() -> void:
	if game.mechanic_rescued: recruit(2)
	if game.story.flags.survivors: recruit(0); recruit(1)
	for actor in members:
		if actor.recruited:
			actor.avatar.show()
			actor.avatar.gun.show()

func escort_lost(actor: CharacterBody3D) -> void:
	if game.defeated: return
	game.on_death()
	game.hud.card_title.text = actor.identity+" est mort"
	game.hud.card_copy.text = "Mission de secours échouée. Toute l'équipe doit survivre. Reprenez au checkpoint pour la protéger."

func warn_wounded(actor: CharacterBody3D) -> void:
	if warning_clock>0: return
	warning_clock = 7
	game.speak(actor.identity+" · Je suis blessé ! Mettez-nous à couvert !",5)


func hear_shot(origin: Vector3, hostile := false) -> void:
	if not difficulty_active:
		return
	for actor in members:
		if not actor.recruited or not actor.alive or actor.embarked or actor.downed:
			continue
		var ear: Vector3 = actor.get_aim_point()
		var distance := ear.distance_to(origin)
		if distance > 20.0 or distance < .15:
			continue
		var ray := PhysicsRayQueryParameters3D.create(ear, origin, 1)
		if distance > 7.0 and not actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		actor.heard_point = origin
		actor.listen_left = 1.5 if hostile else .85


func warn_behind(actor: CharacterBody3D, enemy: Node3D) -> void:
	if rear_warning_cooldown > 0.0 or game.pilot.vehicle != null:
		return
	var offset: Vector3 = enemy.global_position - game.pilot.global_position
	if offset.length_squared() > 16.0*16.0 or game.pilot.global_basis.z.dot(offset.normalized()) < .55:
		return
	rear_warning = actor.identity + " · Derrière toi !"
	rear_warning_left = 3.5
	rear_warning_cooldown = 10.0

func blast(origin: Vector3, radius: float, damage: int) -> void:
	for actor in members:
		if not actor.recruited or actor.embarked or not actor.alive: continue
		var offset: Vector3 = actor.global_position-origin
		if absf(offset.y)>2.2 or Vector2(offset.x,offset.z).length()>radius: continue
		if game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin+Vector3.UP*0.3,actor.get_aim_point(),1)).is_empty(): actor.apply_damage(damage)

func _physics_process(delta: float) -> void:
	if game==null: return
	panel.visible = difficulty_active and not game.hud.film_bars.visible and not game.hud.title_card.visible
	var rows := PackedStringArray(["ESCOUADE · TOUS DOIVENT SURVIVRE"])
	for actor in members:
		if actor.recruited: rows.append("%s  %d %% · %s"%[actor.identity,roundi(100.0*actor.health/actor.max_health),"AU SOL · %d s"%ceili(actor.bleed_left) if actor.downed else ("À BORD" if actor.embarked else ("VOUS ATTEND" if actor.waiting else ("RECHARGE" if actor.reload_left>0 else "AVEC VOUS")))])
	rear_warning_left = maxf(0.0, rear_warning_left-delta)
	rear_warning_cooldown = maxf(0.0, rear_warning_cooldown-delta)
	if rear_warning_left > 0.0: rows.append(rear_warning)
	panel.text = "\n".join(rows)
	if not game.pilot.in_control: return
	if game.world.pad_barriers[0].visible!=pad_locked:
		pad_locked = game.world.pad_barriers[0].visible
		navigation.erase(2)
	warning_clock = maxf(0,warning_clock-delta)
	if trail.is_empty() or trail[-1].distance_to(game.pilot.global_position)>0.8:
		trail.append(game.pilot.global_position)
		if trail.size()>1000: trail.remove_at(0)
	if game.pilot.vehicle!=null:
		riding = game.pilot.vehicle
		for actor in members:
			if actor.recruited: actor.embarked = true; actor.hide(); actor.collision_layer = 0; actor.global_position = riding.global_position
	elif riding!=null:
		# Disembark only at free capsule positions around the stopped vehicle.
		for actor in members:
			if not actor.recruited: continue
			actor.reset_at(safe_position(game.pilot.global_position,actor),false)
		riding = null
	update_clock -= delta
	if update_clock<=0: update_clock = 1.0; update_enemies()
