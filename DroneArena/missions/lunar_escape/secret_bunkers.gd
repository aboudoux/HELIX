extends Node3D
## Optional, pre-populated vaults. Rewards never unlock campaign gates.
const SITES := preload("res://missions/lunar_escape/bunker_sites.gd")
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
var game: Node3D
var entries: Array[Dictionary] = []
var prompt: Label
var health_bar: ProgressBar
var boss_caption: Label
var armor_tier := 0
var equipment_stamp := ""

func setup(campaign: Node3D) -> void:
	game=campaign;name="SecretBunkers"
	for i in range(3): build_bunker(i)
	prompt=game.hud.label(game.hud.content,"",17,Color("efcea0"))
	game.hud.pin(prompt,Control.PRESET_CENTER_BOTTOM,Vector2(-330,-270),Vector2(660,48))
	prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	health_bar=ProgressBar.new();game.hud.content.add_child(health_bar)
	game.hud.pin(health_bar,Control.PRESET_CENTER_TOP,Vector2(-200,100),Vector2(400,14))
	health_bar.show_percentage=false
	var fill:=StyleBoxFlat.new();fill.bg_color=Color("e05846");fill.corner_radius_top_left=4;fill.corner_radius_bottom_right=4
	health_bar.add_theme_stylebox_override("fill",fill)
	boss_caption=game.hud.label(game.hud.content,"",15,Color("efcea0"))
	game.hud.pin(boss_caption,Control.PRESET_CENTER_TOP,Vector2(-240,118),Vector2(480,28))
	boss_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;boss_caption.hide()
	prompt.hide();health_bar.hide()
	game.pilot.died.connect(reset_unfinished)

func build_bunker(index: int) -> void:
	var point: Vector3=SITES.POINTS[index]
	var root:=Node3D.new();root.name="BunkerSecret%d"%index
	game.world.add_child(root);root.position=point
	var wall:=WORLD.FINISH.architecture(WORLD.WHITE,WORLD.FINISH.Detail.USER_WALL_PHOTO)
	var metal:=WORLD.FINISH.create(Color("535f65"),.72,.44,.09)
	var accent: Material=[WORLD.AMBER,WORLD.CYAN,WORLD.RED][index]
	WORLD.block(root,Vector3(0,-.14,0),Vector3(12.8,.28,14.8),WORLD.FLOOR,true)
	WORLD.block(root,Vector3(0,3.65,0),Vector3(13,.38,15),metal,true)
	# Soil blankets the roof, while the excavated pocket below stays physically empty.
	var soil: Material=game.world.get_node("ReliefLunaire").material_override
	KIT.bevel(root,Vector3(0,3.98,-.5),Vector3(13.3,.46,14),.2,soil)
	for side in [-1.0,1.0]:
		build_berm(root,Vector3(side*6.5,0,-7.5),Vector3(side*6.5,0,7.5),Vector3(side*6.5,0,0),soil)
	build_berm(root,Vector3(-6.5,0,-7.5),Vector3(6.5,0,-7.5),Vector3(0,0,-7),soil)
	for side in [-1,1]:
		WORLD.block(root,Vector3(side*6.2,1.8,0),Vector3(.4,3.6,14.6),metal,true)
		WORLD.block(root,Vector3(side*4.05,1.8,7),Vector3(4.4,3.6,.4),wall,true)
		for z in [-5.4,-2.7,0,2.7,5.4]:
			KIT.bevel(root,Vector3(side*5.98,1.85,z),Vector3(.07,3.3,2.48),.025,wall)
			KIT.rod(root,Vector3(side*5.91,.18,z-1.3),Vector3(side*5.91,3.45,z-1.3),.035,WORLD.STEEL)
			KIT.bevel(root,Vector3(side*5.88,2.85,z),Vector3(.055,.08,.8),.014,accent)
	WORLD.block(root,Vector3(0,1.8,-7),Vector3(12.8,3.6,.4),wall,true)
	WORLD.block(root,Vector3(0,3.42,7),Vector3(3.7,.44,.45),metal,true)
	var key:="bunker_%d"%index
	game.world.build_door(game.world,key,point+Vector3(0,0,7),3.4,SITES.TITLES[index],false)
	game.world.add_airlock(key,point+Vector3(0,0,13))
	# A broad walkable descent: no ladder, jump or teleport required.
	var ramp:=WORLD.block(root,Vector3(0,.94,19.5),Vector3(3.7,.24,13.19),WORLD.FLOOR,true)
	ramp.rotation.x=-atan2(2.2,13)
	# Feather the upper edge into the triangulated regolith, avoiding a 30 cm curb.
	var apron:=WORLD.block(root,Vector3(0,1.8,29),Vector3(3.7,.16,6.1),WORLD.FLOOR,true)
	apron.rotation.x=atan2(.46,6)
	for side in [-1,1]:
		KIT.rod(root,Vector3(side*1.9,1.0,13),Vector3(side*1.9,3.2,26),.045,WORLD.STEEL)
		for z in [13.0,19.5,26.0]:
			var y: float=(z-13)/13*2.2
			KIT.rod(root,Vector3(side*1.9,y,z),Vector3(side*1.9,y+1,z),.035,WORLD.STEEL)
	for z in [-3.8,3.2]:
		game.world.ceiling_light(root,Vector3(0,3.39,z),WORLD.AMBER)
		var light:=OmniLight3D.new();root.add_child(light);light.position=Vector3(0,2.9,z)
		light.light_color=Color("d4e0e8");light.light_energy=1.1;light.omni_range=8;light.shadow_enabled=true
	# Two low cover pieces leave the middle and the retreat route unobstructed.
	for offset in [Vector3(-3.4,0,1.3),Vector3(3.7,0,-3.5)]:
		game.get_node("CampaignPolish").cover(root,offset,"",accent)
	game.world.furnishings.gear_shelf(root,Vector3(-4.8,0,-5.4))
	var locker:=Node3D.new();root.add_child(locker);locker.position=Vector3(-2,0,-5.85)
	KIT.bevel(locker,Vector3(0,.58,0),Vector3(2.5,1.16,1.1),.10,metal,true)
	var lid:=KIT.bevel(locker,Vector3(0,1.2,0),Vector3(2.6,.12,1.16),.04,WORLD.STEEL)
	var lamp:=KIT.bevel(locker,Vector3(0,.7,.57),Vector3(.3,.09,.025),.02,WORLD.RED)
	for x in [-1.0,1.0]: KIT.rod(locker,Vector3(x,.2,.58),Vector3(x,.96,.58),.025,WORLD.STEEL)
	var prize:=WORLD.gun(locker,SITES.WEAPONS[index],false)
	prize.position=Vector3(0,1.4,0);prize.rotation.y=PI/2
	dress_weapon(prize);prize.hide()
	# Physical armor display: layered breastplate, shoulder caps, textile joints and belt.
	var armor:=Node3D.new();locker.add_child(armor);armor.position=Vector3(.7,1.55,-.1)
	KIT.bevel(armor,Vector3.ZERO,Vector3(.45,.52,.15),.08,metal)
	for side in [-1,1]:
		KIT.bevel(armor,Vector3(side*.27,.12,0),Vector3(.20,.23,.20),.07,WORLD.WHITE)
		KIT.rod(armor,Vector3(side*.15,-.22,.1),Vector3(side*.15,.20,.1),.022,WORLD.GRIP)
	KIT.bevel(armor,Vector3(0,.04,.09),Vector3(.29,.3,.04),.04,WORLD.WHITE)
	KIT.bevel(armor,Vector3(0,-.16,.1),Vector3(.24,.035,.025),.012,accent)
	armor.hide()
	var director: Node3D=game.DIRECTOR.new();director.name="GardienBunker%d"%index
	director.floor_height=point.y;director.flight_height=point.y+1.95
	director.navigation_region=Rect2i(int(point.x)-5,int(point.z)-6,11,13)
	director.projectile_damage=14+index*5;director.projectile_speed=16+index*3
	director.process_mode=Node.PROCESS_MODE_DISABLED;game.add_child(director)
	var guard:=game.DRONE.instantiate() as CharacterBody3D
	guard.campaign_combat=true;guard.drone_name=["CERBÈRE · GARDIEN HÉLIOS","ARGOS · GARDIEN NÉRÉIDE","TALOS · GARDIEN OBSIDIENNE"][index]
	guard.max_health=[18,30,44][index];guard.move_speed=2.4+index*.35
	guard.fire_interval=1.55-index*.18;guard.charge_duration=.65-index*.06
	guard.position=point+Vector3(2.2,1.95,-1.8);guard.rotation.y=PI
	director.add_child(guard)
	dress_guard(guard,index)
	preload("res://missions/lunar_escape/enemy_roles.gd").install(guard,false,index)
	guard.destroyed.connect(guard_destroyed.bind(index))
	entries.append({"root":root,"guard":guard,"director":director,"discovered":false,"defeated":false,"claimed":false,"locker":locker,"lid":lid,"lamp":lamp,"prize":prize,"armor":armor})
	WORLD.FINISH.apply_tree(root)

func build_berm(parent: Node3D,a: Vector3,b: Vector3,outward: Vector3,soil: Material) -> void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices: Array[Vector3]=[]
	for row in range(9):
		for column in range(5):
			var t:=column/4.0
			var p:=a.lerp(b,row/8.0)+outward*t
			var global:=parent.position+p
			var ground: float=game.world.surface_profile.elevation(global.x,global.z)-parent.position.y
			p.y=lerpf(4.12,ground,smoothstep(0,1,t))+sin(row*2.7+column*1.9)*.14*sin(t*PI)
			vertices.append(p)
	for row in range(8):
		for col in range(4):
			var k:=row*5+col
			for ids in [[k,k+1,k+5],[k+1,k+6,k+5]]:
				var triangle: Array[Vector3]=[vertices[ids[0]],vertices[ids[1]],vertices[ids[2]]]
				# Godot front faces use clockwise winding.
				if (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).y>0: triangle.reverse()
				for p in triangle: surface.add_vertex(p)
	surface.generate_normals()
	var mesh:=MeshInstance3D.new();mesh.name="RemblaiLunaire";mesh.mesh=surface.commit();mesh.material_override=soil;parent.add_child(mesh)
	mesh.create_trimesh_collision()

func dress_guard(guard: CharacterBody3D,index: int) -> void:
	var model: Node3D=guard.get_node("Hull/VisualModel")
	var enamel:=WORLD.FINISH.create([Color("777c72"),Color("517575"),Color("554e66")][index],.18,.52,.06)
	var alloy:=WORLD.FINISH.create(Color("71818a"),.78,.34,.05)
	WORLD.FINISH.apply_tree(model)
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		if mesh.material_override is ShaderMaterial:
			mesh.material_override=enamel if mesh.get_aabb().size.length()>.25 else alloy
	for side in [-1,1]:
		var plate:=KIT.bevel(model,Vector3(side*.43,.15,0),Vector3(.3,.28,.72),.08,enamel)
		for z in [-.24,.24]:
			KIT.bevel(plate,Vector3(0,.15,z),Vector3(.16,.04,.05),.012,alloy)
		KIT.rod(model,Vector3(side*.35,.30,-.31),Vector3(side*.35,.30,.34),.024,alloy)
		for j in range(4): KIT.bevel(model,Vector3(side*.51,.12,-.22+j*.14),Vector3(.025,.13,.035),.008,WORLD.FRAME)

func dress_weapon(model: Node3D) -> void:
	if model.has_meta("vault_finish"): return
	model.set_meta("vault_finish",true)
	var alloy:=WORLD.FINISH.create(Color("a6b9bd"),.74,.33,.045)
	var dark:=WORLD.FINISH.create(Color("29383c"),.2,.53,.06)
	for side in [-1,1]:
		KIT.bevel(model,Vector3(side*.069,.025,-.12),Vector3(.012,.043,.11),.004,dark)
		for i in range(3): KIT.bevel(model,Vector3(side*.077,.03,-.16+i*.035),Vector3(.008,.023,.013),.003,alloy)
		KIT.bevel(model,Vector3(side*.077,.005,-.12),Vector3(.006,.008,.075),.002,WORLD.AMBER)
	for mesh in model.find_children("*","GeometryInstance3D",true,false):
		if model.get("grip")!=null: mesh.layers=2;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func guard_destroyed(_guard: CharacterBody3D,index: int) -> void:
	var entry: Dictionary=entries[index]
	entry.defeated=true;entry.lamp.material_override=WORLD.CYAN
	var tween:=create_tween();tween.tween_property(entry.lid,"position:z",-.9,.55)
	entry.prize.show();entry.armor.show()
	game.speak(SITES.TITLES[index]+" · Gardien neutralisé. Le coffre renforcé est déverrouillé.",4)

func claim(index: int) -> bool:
	var entry: Dictionary=entries[index]
	if not entry.defeated or entry.claimed: return false
	if not game.task_in_reach(entry.locker.global_position+Vector3(0,1.25,.4),2.8): return false
	entry.claimed=true;entry.prize.hide();entry.armor.hide()
	game.pilot.unlock_weapon(SITES.WEAPONS[index])
	game.pilot.add_ammo(SITES.WEAPONS[index],[36,12,60][index])
	apply_upgrades()
	game.pilot.health_changed.emit(game.pilot.health,game.pilot.max_health)
	game.speak("ÉQUIPEMENT RARE · "+["Pistolet Hélios","Pompe Néréide","Fusil Obsidienne"][index]+" Mk II : dégâts ×2. Armure renforcée : dégâts reçus −%d %% et +%d PV maximum."%[15+index*10,(index+1)*25],7)
	game.saver.write_save(game)
	return true

func apply_upgrades() -> void:
	armor_tier=0
	var improved: Array[String]=[]
	for i in range(entries.size()):
		if entries[i].claimed: armor_tier=maxi(armor_tier,i+1);improved.append(SITES.WEAPONS[i])
	var pilot: CharacterBody3D=game.pilot
	var stamp:="%s/%s/%d/%d/%d/%d"%[str(improved),pilot.equipped,armor_tier,pilot.max_health,pilot.gun_visual.get_instance_id() if is_instance_valid(pilot.gun_visual) else 0,pilot.loadout.offhand.get_instance_id() if is_instance_valid(pilot.loadout.offhand) else 0]
	if stamp==equipment_stamp: return
	equipment_stamp=stamp
	pilot.set_meta("bunker_armor",armor_tier)
	var previous_max: int=pilot.max_health
	pilot.max_health=maxi(pilot.max_health,100+25*armor_tier)
	if pilot.max_health!=previous_max: pilot.health_changed.emit(pilot.health,pilot.max_health)
	for gun in [pilot.weapon,pilot.loadout.offhand]:
		if not is_instance_valid(gun): continue
		var key: String=pilot.equipped if gun==pilot.weapon else pilot.loadout.left
		gun.damage_per_hit=2 if key in improved else 1
		if key in improved and is_instance_valid(gun.reload_visual): dress_weapon(gun.reload_visual)
	if armor_tier>0: pilot.avatar.set_reinforced(true)

func _physics_process(_delta: float) -> void:
	if game==null: return
	prompt.hide();health_bar.hide();boss_caption.hide()
	apply_upgrades()
	for i in range(entries.size()):
		var entry: Dictionary=entries[i]
		var point: Vector3=entry.root.to_local(game.pilot.global_position)
		var nearby:=absf(point.x)<18 and absf(point.z)<30 and absf(point.y)<6
		entry.director.process_mode=Node.PROCESS_MODE_INHERIT if nearby and game.pilot.in_control and not game.defeated else Node.PROCESS_MODE_DISABLED
		if not nearby or not game.pilot.in_control or game.pilot.vehicle!=null: continue
		if not entry.discovered:
			entry.discovered=true
			game.speak("ABRI SECRET DÉCOUVERT · "+SITES.TITLES[i]+". Un gardien protège de l'équipement expérimental.",5)
		if point.z<7 and absf(point.x)<6 and not entry.defeated:
			health_bar.show();health_bar.max_value=entry.guard.max_health;health_bar.value=entry.guard.health
			boss_caption.text="%s · Gardien %d / %d"%[SITES.TITLES[i],entry.guard.health,entry.guard.max_health];boss_caption.show()
		if not entry.claimed and game.task_in_reach(entry.locker.global_position+Vector3(0,1.25,.4),2.8):
			prompt.text="E · Récupérer l’arme Mk II et l’armure renforcée" if entry.defeated else "COFFRE VERROUILLÉ · Neutralisez le gardien"
			prompt.show()
			if Input.is_action_just_pressed("interact"): claim(i)

func reset_unfinished() -> void:
	for entry in entries:
		if not entry.defeated: entry.guard.reset_drone()

func snapshot() -> Array:
	return entries.map(func(e):return {"discovered":e.discovered,"defeated":e.defeated,"claimed":e.claimed})

static func valid_snapshot(data: Variant) -> bool:
	if not data is Array or data.size()!=3: return false
	for entry in data:
		if not entry is Dictionary: return false
		for flag in ["discovered","defeated","claimed"]:
			if not entry.get(flag) is bool: return false
		if entry.claimed and not entry.defeated: return false
	return true

func restore(data: Array) -> void:
	if not valid_snapshot(data): return
	for i in range(3):
		var entry: Dictionary=entries[i]
		for flag in ["discovered","defeated","claimed"]: entry[flag]=data[i][flag]
		entry.guard.reset_drone()
		if entry.defeated:
			entry.guard.alive=false;entry.guard.health=0;entry.guard.hull.hide();entry.guard.warning.hide()
			entry.guard.hit_shape.set_deferred("disabled",true)
			preload("res://scripts/actor_collision.gd").set_enabled(entry.guard.extra_colliders,false)
		entry.lid.position.z=-.9 if entry.defeated else 0
		entry.prize.visible=entry.defeated and not entry.claimed;entry.armor.visible=entry.prize.visible
		entry.lamp.material_override=WORLD.CYAN if entry.defeated else WORLD.RED
	apply_upgrades()
