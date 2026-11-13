extends Node3D
## Player-built, removable cover. All placement queries run during physics.
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const FIT := preload("res://missions/lunar_escape/block_fit.gd")
const STAIR := preload("res://missions/lunar_escape/build_stair.gd")
const TURRET := preload("res://missions/lunar_escape/build_turret.gd")
const SIZE := 1.5
const REACH := 8.0
const LIMIT := 256
const NAMES := ["Céramique ivoire","Métal graphite","Titane brossé"]
enum Piece { BLOCK, STAIR, TURRET }
const PIECE_NAMES := ["Bloc", "Escalier", "Tourelle"]
const COST := [1, 1, 3]
var game: Node3D
var active := false
var kind := 0
var piece := Piece.BLOCK
var turns := 0
var stair_mesh: ArrayMesh
var stair_shape: ConvexPolygonShape3D
var cube_mesh: BoxMesh
var turret_mesh: BoxMesh
var stock := 0
var fitted: Array[int]=[]
var fitted_mesh: Mesh
var contact := Vector3.ZERO
var contact_normal := Vector3.UP
var cached_point := Vector3.INF
var fit_clock := 0.0
var blocks: Array[StaticBody3D] = []
var preview: MeshInstance3D
var selection: MeshInstance3D
var ghost_material: StandardMaterial3D
var panel: Label
var sound: AudioStreamPlayer3D
var candidate := Vector3.INF
var target: StaticBody3D
var reason := ""
var can_place := false
var queued_place := false
var queued_remove := false
var old_third_person := false

func setup(campaign: Node3D) -> void:
	name="Construction";game=campaign;process_physics_priority=50;process_mode=Node.PROCESS_MODE_ALWAYS
	ghost_material=StandardMaterial3D.new()
	ghost_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	preview=ghost(ghost_material,SIZE)
	cube_mesh = preview.mesh
	stair_mesh = STAIR.mesh()
	stair_shape = STAIR.shape()
	turret_mesh = BoxMesh.new()
	turret_mesh.size = TURRET.FOOTPRINT
	var selected:=ghost_material.duplicate() as StandardMaterial3D
	selected.albedo_color=Color(1,.40,.10,.19)
	selection=ghost(selected,SIZE+.025)
	panel=game.hud.label(game.hud.content,"",17,Color("d6f0ea"))
	game.hud.pin(panel,Control.PRESET_CENTER_BOTTOM,Vector2(-420,-275),Vector2(840,85))
	panel.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;panel.hide()
	sound=AudioStreamPlayer3D.new();add_child(sound)
	sound.bus="LunarSuit";sound.volume_db=-14;sound.max_distance=20

func ghost(material: Material,size: float) -> MeshInstance3D:
	var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3.ONE*size
	node.mesh=mesh;node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node);node.hide();return node

func available() -> bool:
	return game.pilot.in_control and game.pilot.vehicle==null and not game.transition and not game.defeated

func _input(event: InputEvent) -> void:
	if get_tree().paused: return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int=event.keycode if event.keycode!=0 else event.physical_keycode
		if code==KEY_J and available():
			set_active(not active);get_viewport().set_input_as_handled();return
		if active and code==KEY_N:
			kind=(kind+1)%NAMES.size();get_viewport().set_input_as_handled();return
		if active and code==KEY_U:
			piece = (piece+1)%PIECE_NAMES.size() as Piece
			get_viewport().set_input_as_handled();return
		if active and code==KEY_O and piece==Piece.STAIR:
			turns = (turns+1)%4
			get_viewport().set_input_as_handled();return
	if active and available() and event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT: queued_place=true
		elif event.button_index==MOUSE_BUTTON_RIGHT: queued_remove=true
		else: return
		get_viewport().set_input_as_handled()

func set_active(value: bool) -> void:
	if value and (not available() or get_tree().paused): return
	if active==value: return
	active=value;game.pilot.building=value
	queued_place=false;queued_remove=false
	game.pilot.loadout.cancel_hand_reload()
	for gun in [game.pilot.weapon,game.pilot.loadout.offhand]:
		if not is_instance_valid(gun): continue
		gun.tool_blocked=value;gun.cancel_reload();gun.clear_aim();gun.trigger_ready=false;gun.aim_ready=false
	if value:
		old_third_person=game.pilot.third_person;game.pilot.set_third_person(false)
		game.pilot.weapon.hide();game.pilot.shield_visual.hide()
	else:
		preview.hide();selection.hide();panel.hide()
		game.pilot.weapon.visible=game.pilot.in_control and game.pilot.vehicle==null and not game.pilot.equipped.is_empty()
		if game.pilot.in_control: game.pilot.set_third_person(old_third_person)
	game.pilot.loadout.sync_control()

func _physics_process(delta: float) -> void:
	fit_clock-=delta
	if not active: return
	if get_tree().paused:
		queued_place=false;queued_remove=false;preview.hide();selection.hide();panel.hide();return
	if not available(): set_active(false);return
	game.pilot.weapon.hide();game.pilot.shield_visual.hide()
	update_target()
	if queued_remove: remove_target()
	elif queued_place: place_candidate()
	queued_place=false;queued_remove=false
	panel.show()
	panel.text="%s · %s · Coût %d · Stock %d · Posés %d / %d\nClic gauche : poser   |   Clic droit : démonter   |   J : quitter\nU : pièce   |   O : orienter l’escalier   |   N : matériau\n%s"%[PIECE_NAMES[piece],NAMES[kind],COST[piece],stock,blocks.size(),LIMIT,reason]

func update_target() -> void:
	preview.hide();selection.hide();candidate=Vector3.INF;target=null;can_place=false
	reason="Visez le sol ou un bloc posé · portée 8 m"
	var camera: Camera3D=game.camera
	var start:=camera.global_position
	var query:=PhysicsRayQueryParameters3D.create(start,start-camera.global_basis.z*REACH,31,[game.pilot.get_rid()])
	query.hit_from_inside=true
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return
	contact=hit.position;contact_normal=hit.normal
	if hit.collider is StaticBody3D and hit.collider in blocks:
		target=hit.collider
		var target_piece: int = target.get_meta("build_piece", Piece.BLOCK)
		selection.global_position = target.global_position + (TURRET.OFFSET if target_piece == Piece.TURRET else Vector3.ZERO)
		selection.mesh = target.get_meta("build_mesh",cube_mesh)
		selection.rotation.y = target.rotation.y
		selection.show()
		var normal: Vector3=hit.normal
		var axis:=normal.abs().max_axis_index()
		var face:=Vector3.ZERO;face[axis]=signf(normal[axis])
		candidate=target.global_position+face*SIZE
	else:
		var center: Vector3=hit.position+hit.normal*.45
		candidate=Vector3(snappedf(center.x,SIZE),snappedf(center.y-SIZE*.5,SIZE)+SIZE*.5,snappedf(center.z,SIZE))
	if piece != Piece.BLOCK and hit.normal.y > .75:
		# Use the actual surface height so a floor raised above the grid still works.
		var foot := Vector3(candidate.x, hit.position.y, candidate.z)
		var surface := PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.3,foot-Vector3.UP*.3,1)
		var support := get_world_3d().direct_space_state.intersect_ray(surface)
		if not support.is_empty() and support.normal.y > .75:
			candidate.y = support.position.y+SIZE*.5
	can_place=placement_allowed(candidate)
	preview.global_position = candidate + (TURRET.OFFSET if piece == Piece.TURRET else Vector3.ZERO)
	preview.rotation.y = turns*PI*.5 if piece == Piece.STAIR else 0.0
	if piece == Piece.STAIR: preview.mesh = stair_mesh
	elif piece == Piece.TURRET: preview.mesh = turret_mesh
	else: preview.mesh = fitted_mesh if fitted_mesh != null else cube_mesh
	preview.show()
	ghost_material.albedo_color=Color(.15,.95,.65,.28) if can_place else Color(1,.12,.08,.30)
	if can_place: reason="Bloc ajusté au décor · %d / %d sections"%[fitted.size(),FIT.TOTAL] if piece==Piece.BLOCK and fitted.size()<FIT.TOTAL else "Emplacement libre"
	if is_instance_valid(target):
		reason += "   |   Clic droit : récupérer %d bloc(s)" % COST[int(target.get_meta("build_piece", Piece.BLOCK))]

func placement_allowed(point: Vector3) -> bool:
	if not point.is_finite() or game.camera.global_position.distance_to(point)>REACH+.8: reason="Trop loin";return false
	if stock<COST[piece]: reason="Il faut %d bloc(s) · Ouvrez les placards avec E"%COST[piece];return false
	if blocks.size()>=LIMIT: reason="Limite atteinte : retirez un bloc";return false
	var dimensions := TURRET.FOOTPRINT if piece == Piece.TURRET else Vector3.ONE*(SIZE-.04)
	var center := point + (TURRET.OFFSET if piece == Piece.TURRET else Vector3.ZERO)
	var bounds:=AABB(center-dimensions*.5,dimensions)
	var player_bounds:=AABB(game.pilot.global_position+Vector3(-.36,0,-.36),Vector3(.72,1.85,.72))
	if bounds.intersects(player_bounds): reason="Le joueur occupe cet emplacement";return false
	for block in blocks:
		if block.global_position.distance_squared_to(point)<.01:
			reason="Un bloc est déjà présent";return false
	var query:=PhysicsShapeQueryParameters3D.new();var shape:=BoxShape3D.new();shape.size=dimensions-Vector3.ONE*.004
	query.shape=shape;query.transform=Transform3D(Basis.IDENTITY,center);query.collision_mask=30
	if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): reason="Un personnage occupe cet emplacement";return false
	if piece != Piece.BLOCK:
		query.collision_mask = 1
		query.transform.origin += Vector3.UP*.012
		if piece == Piece.STAIR:
			query.shape = stair_shape
			query.transform.basis = Basis(Vector3.UP, turns*PI*.5).scaled(Vector3.ONE*.996)
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): reason="Le décor bloque cette pièce";return false
		if piece == Piece.TURRET:
			var bottom := point - Vector3.UP*SIZE*.5
			var ground := PhysicsRayQueryParameters3D.create(bottom+Vector3.UP*.06,bottom-Vector3.UP*.16,1)
			var support := get_world_3d().direct_space_state.intersect_ray(ground)
			if support.is_empty() or support.normal.y < .75: reason="La tourelle a besoin d'un appui au sol";return false
			if support.collider.get_meta("build_piece", Piece.BLOCK) == Piece.TURRET: reason="Choisissez un appui sans tourelle";return false
		return true
	if point!=cached_point or fit_clock<=0:
		fitted=FIT.fit(get_world_3d().direct_space_state,point,contact,contact_normal)
		cached_point=point;fit_clock=.20
		fitted_mesh = FIT.mesh(fitted) if not fitted.is_empty() and fitted.size()<FIT.TOTAL else cube_mesh
	if fitted.is_empty(): reason="Aucun espace libre dans le décor";return false
	return true

func create_block(point: Vector3,material_index: int,animate := false,cells: Array=[],piece_type: int=Piece.BLOCK,orientation: int=0) -> StaticBody3D:
	var body:=StaticBody3D.new();body.name="BlocConstruit";body.collision_layer=1;body.collision_mask=0
	body.set_meta("build_kind",material_index);body.set_meta("build_piece",piece_type);body.set_meta("build_turns",orientation)
	body.set_meta("impact_surface","metal")
	add_child(body);body.global_position=point
	blocks.append(body)
	var material: Material=[WORLD.WHITE,WORLD.FRAME,WORLD.STEEL][material_index]
	if piece_type == Piece.STAIR:
		body.name = "EscalierConstruit"
		body.rotation.y = orientation*PI*.5
		var collider := CollisionShape3D.new()
		collider.shape = stair_shape
		body.add_child(collider)
		var tread := MeshInstance3D.new()
		tread.mesh = stair_mesh
		tread.material_override = KIT.FINISH.architecture(material,KIT.FINISH.Detail.TREAD)
		body.add_child(tread)
		body.set_meta("build_mesh", stair_mesh)
		for index in STAIR.STEPS:
			var height := STAIR.RISE*(index+.5)/STAIR.STEPS-SIZE*.5
			var z := SIZE*.5-(index+1.0)*SIZE/STAIR.STEPS+.018
			KIT.bevel(tread,Vector3(0,height+.006,z),Vector3(1.43,.018,.032),.006,WORLD.FRAME)
		return body
	if piece_type == Piece.TURRET:
		body.name = "TourelleConstruite"
		var turret := TURRET.new()
		body.add_child(turret)
		turret.build(body,game,material)
		body.set_meta("build_mesh", turret_mesh)
		return body
	if not cells.is_empty() and cells.size()<FIT.TOTAL:
		body.set_meta("fit_cells",cells.duplicate());FIT.add_collision(body,cells)
		var cut:=MeshInstance3D.new();body.add_child(cut);cut.mesh=FIT.mesh(cells);cut.material_override=KIT.FINISH.material(material)
		body.set_meta("build_mesh", cut.mesh)
		return body
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3.ONE*SIZE;shape.shape=box;body.add_child(shape)
	var visual:=KIT.bevel(body,Vector3.ZERO,Vector3.ONE*SIZE,.045,material)
	# Recessed faces and corner fasteners match the station's manufactured panels.
	for side in [-1.0,1.0]:
		KIT.bevel(visual,Vector3(0,0,side*.752),Vector3(1.18,1.18,.012),.03,material)
		for x in [-.61,.61]:
			for y in [-.61,.61]: KIT.bevel(visual,Vector3(x,y,side*.757),Vector3(.045,.045,.018),.009,WORLD.STEEL)
	if animate:
		visual.scale=Vector3.ONE*.88
		create_tween().tween_property(visual,"scale",Vector3.ONE,.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return body

func place_candidate() -> bool:
	fit_clock=0
	if not active or not available() or get_tree().paused or not can_place or not placement_allowed(candidate): return false
	stock -= COST[piece]
	create_block(candidate,kind,true,fitted if piece==Piece.BLOCK else [],piece,turns if piece==Piece.STAIR else 0)
	sound.global_position=candidate;sound.stream=preload("res://audio/repair_pickup.wav");sound.pitch_scale=.85;sound.play()
	changed(candidate);return true

func remove_target() -> bool:
	if not active or not available() or get_tree().paused or not is_instance_valid(target) or target not in blocks: return false
	if game.camera.global_position.distance_to(target.global_position)>REACH+1: return false
	var point:=target.global_position
	stock += COST[int(target.get_meta("build_piece", Piece.BLOCK))]
	var material: Material=[WORLD.WHITE,WORLD.FRAME,WORLD.STEEL][int(target.get_meta("build_kind"))]
	blocks.erase(target);target.collision_layer=0;target.hide();target.queue_free();target=null;selection.hide()
	for i in range(6):
		var chip:=KIT.bevel(self,point,Vector3(.15,.1,.18),.02,material)
		var tween:=create_tween().set_parallel(true)
		tween.tween_property(chip,"position",point+Vector3(cos(i*TAU/6),-.5,sin(i*TAU/6))*.65,.32)
		tween.tween_property(chip,"scale",Vector3.ZERO,.32)
		tween.chain().tween_callback(chip.queue_free)
	sound.global_position=point;sound.stream=preload("res://audio/lunar_armor_hit.wav");sound.pitch_scale=1.15;sound.play()
	changed(point);return true

func changed(point: Vector3) -> void:
	cached_point=Vector3.INF
	game.rebuild_navigation(point)
	if game.has_node("SecretBunkers"):
		for entry in game.get_node("SecretBunkers").entries:
			if entry.root.global_position.distance_to(point)<25: entry.director.navigation_ready=false
	game.saver.write_save(game)

func snapshot() -> Array:
	return blocks.map(func(block):return {"position":[block.position.x,block.position.y,block.position.z],"kind":int(block.get_meta("build_kind")),"cells":block.get_meta("fit_cells",[]),"piece":int(block.get_meta("build_piece")),"turns":int(block.get_meta("build_turns"))})

static func valid_snapshot(data: Variant) -> bool:
	if not data is Array or data.size()>LIMIT: return false
	var occupied: Dictionary={}
	for item in data:
		if not item is Dictionary or not item.get("position") is Array or item.position.size()!=3: return false
		for value in item.position:
			if (not value is int and not value is float) or not is_finite(float(value)) or absf(value)>10000: return false
		var type: Variant=item.get("kind")
		if (not type is int and not type is float) or type!=floorf(type) or type<0 or type>=3: return false
		if item.has("cells") and (not item.cells is Array or (not item.cells.is_empty() and not FIT.valid_cells(item.cells))): return false
		var piece_type: Variant = item.get("piece", Piece.BLOCK)
		var orientation: Variant = item.get("turns", 0)
		if (not piece_type is int and not piece_type is float) or piece_type!=floorf(piece_type) or piece_type<0 or piece_type>=PIECE_NAMES.size(): return false
		if (not orientation is int and not orientation is float) or orientation!=floorf(orientation) or orientation<0 or orientation>=4: return false
		var key:=Vector3(item.position[0],item.position[1],item.position[2])
		if occupied.has(key): return false
		occupied[key]=true
	return true

func restore(data: Array) -> void:
	if not valid_snapshot(data): return
	set_active(false)
	for block in blocks: block.collision_layer=0;block.hide();block.queue_free()
	blocks.clear()
	cached_point=Vector3.INF
	for item in data:
		create_block(Vector3(item.position[0],item.position[1],item.position[2]),int(item.kind),false,
			item.get("cells",[]),int(item.get("piece",Piece.BLOCK)),int(item.get("turns",0)))
