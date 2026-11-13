extends CanvasLayer
const TERRAIN := preload("res://missions/lunar_escape/regolith.gd")
const ROUTES := preload("res://missions/lunar_escape/lunar_routes.gd")
const COLS := 60
const ROWS := 180
const CELL := 20.0
const MAP_REVISION := 2
var game: Node3D
var discovered: Dictionary = {}
var shades: Dictionary = {}
var chart: Control
var opened := false
var tick := 0.0
var view := Rect2()

func setup(campaign: Node3D) -> void:
	game = campaign; layer = 50; process_mode = Node.PROCESS_MODE_ALWAYS
	chart = Control.new()
	chart.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chart.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(chart); chart.hide()
	chart.draw.connect(draw_chart)
	chart.resized.connect(chart.queue_redraw)

func reveal(point: Vector3) -> void:
	var center := cell_of(point)
	for dx in range(-4,5):
		for dz in range(-4,5):
			if dx*dx+dz*dz>16: continue
			var x := posmod(center.x+dx,COLS); var z := posmod(center.y+dz,ROWS)
			discovered[z*COLS+x] = true

func cell_of(point: Vector3) -> Vector2i:
	point = TERRAIN.wrapped(point)
	return Vector2i(floori((point.x-TERRAIN.LOOP_MIN.x)/CELL),floori((point.z-TERRAIN.LOOP_MIN.y)/CELL))

func known(point: Vector3) -> bool:
	var cell := cell_of(point)
	return discovered.has(cell.y*COLS+cell.x)

func _process(delta: float) -> void:
	if game==null or get_tree().paused or not game.pilot.in_control: return
	tick -= delta
	if tick<=0: tick = 0.3; reveal(game.pilot.global_position)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode==KEY_TAB or (opened and event.is_action_pressed("pause"))):
		if opened: close()
		elif game.pilot.in_control and not get_tree().paused: open()
		else: return
		get_viewport().set_input_as_handled()

func open() -> void:
	if get_tree().paused or not game.pilot.in_control: return
	reveal(game.pilot.global_position)
	opened = true; chart.show(); chart.queue_redraw()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	if not opened: return
	opened = false; chart.hide(); get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func map_point(point: Vector3) -> Vector2:
	point = TERRAIN.wrapped(point)
	return view.position+(Vector2(point.x,point.z)-TERRAIN.LOOP_MIN)/TERRAIN.LOOP_SIZE*view.size

func label(text: String, point: Vector2, color := Color("c7dae1"), size := 17) -> void:
	chart.draw_string(ThemeDB.fallback_font,point,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func draw_chart() -> void:
	var size := chart.size
	chart.draw_rect(Rect2(Vector2.ZERO,size),Color("08111bef"))
	var height := minf(size.y-140,790)
	var width := height*TERRAIN.LOOP_SIZE.x/TERRAIN.LOOP_SIZE.y
	view = Rect2(Vector2((size.x-width)*0.5,76),Vector2(width,height))
	chart.draw_rect(view.grow(2),Color("67bcc5"))
	chart.draw_rect(view,Color("101925"))
	var cell_size := view.size/Vector2(COLS,ROWS)
	for id in discovered:
		var x := int(id)%COLS; var z := int(id)/COLS
		if not shades.has(id):
			var elevation: float = game.world.surface_profile.elevation(TERRAIN.LOOP_MIN.x+(x+0.5)*CELL,TERRAIN.LOOP_MIN.y+(z+0.5)*CELL)
			shades[id] = Color("677982").lightened(clampf(elevation/35,-0.2,0.25))
		chart.draw_rect(Rect2(view.position+Vector2(x,z)*cell_size,cell_size+Vector2.ONE*0.3),shades[id])
	for leg in range(2):
		for i in range(100):
			var a := ROUTES.point(leg,lerpf(ROUTES.start(leg),ROUTES.finish(leg),float(i)/100))
			var b := ROUTES.point(leg,lerpf(ROUTES.start(leg),ROUTES.finish(leg),float(i+1)/100))
			if known(a) and known(b): chart.draw_line(map_point(a),map_point(b),Color("dfbd73"),1.6,true)
	for i in range(3):
		var p := Vector3(0,0,ROUTES.BASE_Z[i])
		if known(p):
			var site := map_point(p)
			chart.draw_rect(Rect2(site-Vector2(7,4),Vector2(14,8)),Color("aacdd2"))
			label(["KAREN","TYCHO","COPERNIC"][i],site+Vector2(12,4),Color.WHITE,14)
	# Secret sites appear only after their entrance was actually approached.
	if game.has_node("SecretBunkers"):
		for entry in game.get_node("SecretBunkers").entries:
			if entry.discovered:
				var p := map_point(entry.root.global_position)
				chart.draw_rect(Rect2(p-Vector2(3,3),Vector2(6,6)),Color("96d9aa") if entry.claimed else Color("c9a0ef"))
	for ride in [game.world.bike,game.world.transport,game.world.scout]:
		if known(ride.global_position): chart.draw_circle(map_point(ride.global_position),3,Color("edbc70"))
	for ally in game.squad.members:
		if ally.recruited and ally.alive: chart.draw_circle(map_point(ally.global_position),2.5,Color("8ae6a4"))
	var player := map_point(game.pilot.global_position)
	var heading: float = game.pilot.rotation.y
	var direction := Vector2(-sin(heading),-cos(heading))
	chart.draw_colored_polygon(PackedVector2Array([player+direction*9,player-direction*5+direction.orthogonal()*5,player-direction*5-direction.orthogonal()*5]),Color("67f4ff"))
	label("CARTE D'EXPLORATION · LUNE",Vector2(28,38),Color.WHITE,24)
	label("TAB / ÉCHAP : fermer · Partie en pause",Vector2(28,size.y-24))
	var left := Vector2(28,110)
	label("Terrain découvert",left,Color("c7dae1"),18)
	label("%0.1f %%"%(discovered.size()*100.0/(COLS*ROWS)),left+Vector2(0,30),Color("67f4ff"),22)
	label("Sombre : zone inconnue",left+Vector2(0,78))
	label("Cyan : vous",left+Vector2(0,108),Color("67f4ff"))
	label("Vert : équipage",left+Vector2(0,138),Color("8ae6a4"))
	label("Orange : véhicules / routes",left+Vector2(0,168),Color("edbc70"))
	label("1,2 × 3,6 km · Bords reliés",Vector2(view.position.x,view.end.y+27),Color("c7dae1"),16)
	label("N",Vector2(view.get_center().x-6,64),Color.WHITE,18)
	if game.story.flags.access:
		label("Code Copernic : "+game.access_codes.copernic,left+Vector2(0,225),Color("edbc70"))

func snapshot() -> Array:
	return discovered.keys()

func restore(cells: Array, revision := MAP_REVISION) -> void:
	discovered.clear()
	shades.clear()
	for id in cells:
		if (not id is int and not id is float) or float(id)!=floorf(float(id)) or int(id)<0 or int(id)>=COLS*ROWS: continue
		if revision<MAP_REVISION:
			# Preserve old explored places relative to their relocated habitat.
			var z := -1200.0+(int(id)/COLS+.5)*CELL
			if z< -680: z=ROUTES.BASE_Z[2]+z+680
			elif z< -320: z=lerpf(ROUTES.BASE_Z[1],ROUTES.BASE_Z[2],(-z-320)/360)
			elif z<0: z=lerpf(0,ROUTES.BASE_Z[1],-z/320)
			var cell := cell_of(Vector3(-600+(int(id)%COLS+.5)*CELL,0,z))
			discovered[cell.y*COLS+cell.x]=true
		else: discovered[int(id)] = true
