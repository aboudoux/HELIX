extends Node3D
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const LOADOUT := preload("res://missions/lunar_escape/dual_loadout.gd")
const MELEE := preload("res://missions/lunar_escape/melee_model.gd")
var game: Node3D
var terminal: Node3D
var window: PanelContainer
var overlay: Control
var main_choice: OptionButton
var left_choice: OptionButton
var armor_choice: OptionButton
var equipment_points: Array[Node3D]=[]
var preset_buttons: Array[Button]=[]
var main_keys := ["pistol","shotgun","smg","sabre","lance"]
var left_keys := ["none","pistol","shotgun","smg","sabre","lance","shield"]
var armor_names := ["EVA · 125 PV · Polyvalente","Assaut · 150 PV · Protection renforcée","Bastion · 175 PV · Blindage lourd"]

func setup(campaign: Node3D) -> void:
	game=campaign;name="ArmurerieCopernic"
	process_mode=Node.PROCESS_MODE_ALWAYS
	position=WORLD.at(2,0,WORLD.UPPER_HEIGHT,0)
	var light:=OmniLight3D.new();add_child(light)
	light.position=Vector3(29.5,3.7,7);light.omni_range=9;light.light_energy=2.2
	light.light_color=Color("e3edf0");light.shadow_enabled=true;light.omni_attenuation=1.4
	var reflections:=ReflectionProbe.new();add_child(reflections)
	reflections.position=Vector3(29.5,2.2,7);reflections.size=Vector3(12,5,14)
	reflections.interior=true;reflections.box_projection=true;reflections.cull_mask=1
	terminal=Node3D.new();add_child(terminal);terminal.position=Vector3(28.5,0,4)
	KIT.bevel(terminal,Vector3(0,.6,0),Vector3(1.35,1.2,.72),.08,WORLD.FRAME,true)
	game.world.furnishings.screen(terminal,Vector3(0,1.5,0),1.0,"ARSENAL EVA\nDEUX MAINS",1.2)
	WORLD.placard(self,"ARMURERIE · ÉQUIPEMENT EVA",Vector3(29,3,2.1),Color("b6e4df"))
	for i in range(main_keys.size()):
		var rack:=Node3D.new();add_child(rack);rack.position=Vector3(25.4+i*1.85,1.3,2.4)
		equipment_points.append(rack)
		KIT.bevel(rack,Vector3(0,0,-.2),Vector3(1.6,2.3,.16),.035,WORLD.FRAME)
		var key: String=main_keys[i]
		if key in LOADOUT.GUNS:
			var gun:=WORLD.gun(rack,key);gun.rotation=Vector3(0,PI/2,.15);gun.scale=Vector3.ONE*1.4
		else:
			var blade:=MELEE.new();rack.add_child(blade);blade.build(key);blade.rotation.z=-.25
		WORLD.placard(rack,LOADOUT.NAMES[key].to_upper(),Vector3(0,-.83,.08),Color("d9e3df")).pixel_size=.0014
	for i in range(2):
		var stand:=Node3D.new();add_child(stand);stand.position=Vector3(31+i*2.2,0,11.7)
		KIT.bevel(stand,Vector3(0,.15,0),Vector3(1.6,.3,1.35),.06,WORLD.FRAME,true)
		var suit:=preload("res://missions/lunar_escape/escort_suit.gd").new();stand.add_child(suit)
		suit.identity="ASSAUT" if i==0 else "BASTION";suit.position.y=.32;suit.build();suit.gun.hide();suit.set_reinforced(true)
		suit.ceramic.set_shader_parameter("tint",Color("869b98") if i==0 else Color("495b64"))
		var nameplate:=WORLD.placard(stand,suit.identity,Vector3(0,2.55,-.3),Color("cee6df"))
		nameplate.pixel_size=.002;nameplate.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	for i in range(3):
		var shield:=preload("res://missions/lunar_escape/shield.gd").new();add_child(shield);shield.build()
		shield.position=Vector3(34.35,1.25,5+i*1.6);shield.rotation.y=-PI/2
		shield.scale=Vector3.ONE*1.25
		equipment_points.append(shield)
		KIT.bevel(self,Vector3(34.65,1.35,5+i*1.6),Vector3(.16,2.1,1.35),.035,WORLD.FRAME)
	build_menu()

func build_menu() -> void:
	overlay=Control.new();overlay.process_mode=Node.PROCESS_MODE_ALWAYS;game.hud.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade:=ColorRect.new();shade.color=Color(0.01,.025,.035,.92);overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window=PanelContainer.new();overlay.add_child(window);window.custom_minimum_size=Vector2(720,580)
	window.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	window.position-=window.custom_minimum_size*.5
	window.add_theme_stylebox_override("panel",game.hud.panel_style(Color("14232b"),Color("438c9a")))
	var margin:=MarginContainer.new();window.add_child(margin)
	for side in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	var form:=VBoxContainer.new();form.add_theme_constant_override("separation",16);margin.add_child(form)
	var title:=Label.new();title.text="INVENTAIRE · MAIN DROITE ET MAIN GAUCHE";title.add_theme_font_size_override("font_size",23);form.add_child(title)
	var intro:=Label.new();intro.text="Choisis une arme ou un bouclier pour chaque main.\nClic gauche : main droite · Clic droit : main gauche\nR : recharger · F : bouclier · I : ouvrir ou fermer l’inventaire";form.add_child(intro)
	main_choice=choice(form,"Main droite",main_keys.map(func(key): return LOADOUT.NAMES[key]))
	left_choice=choice(form,"Main gauche",left_keys.map(func(key): return LOADOUT.NAMES[key]))
	armor_choice=choice(form,"Combinaison",armor_names)
	var presets:=HBoxContainer.new();form.add_child(presets)
	for secondary in ["shield","pistol","sabre"]:
		var button:=Button.new();button.text={"shield":"Pistolet + bouclier","pistol":"Deux pistolets","sabre":"Pistolet + sabre"}[secondary]
		presets.add_child(button);preset_buttons.append(button)
		button.pressed.connect(func():
			main_choice.select(main_keys.find("pistol"));left_choice.select(left_keys.find(secondary));equip_selected()
		)
	var actions:=HBoxContainer.new();form.add_child(actions)
	var equip:=Button.new();equip.text="Équiper et repartir";equip.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(equip);equip.pressed.connect(equip_selected)
	var cancel:=Button.new();cancel.text="Fermer";actions.add_child(cancel);cancel.pressed.connect(close)
	window.hide();overlay.hide()

func in_reach() -> bool:
	if game.step < game.Step.CONTROL: return false
	if game.task_in_reach(terminal.global_position+Vector3.UP*1.4,2.5): return true
	for point in equipment_points:
		if game.task_in_reach(point.global_position,2.5): return true
	return false

func choice(form: VBoxContainer, title: String, values: Array) -> OptionButton:
	var label:=Label.new();label.text=title;form.add_child(label)
	var selector:=OptionButton.new();form.add_child(selector)
	for value in values: selector.add_item(value)
	return selector

func open() -> void:
	if window.visible or get_tree().paused or not game.pilot.in_control: return
	if not game.pilot.loadout.unlocked and not in_reach(): return
	if game.has_node("Construction"): game.get_node("Construction").set_active(false)
	game.pilot.loadout.unlocked=true
	var primary: String=game.pilot.loadout.right if game.pilot.loadout.active else game.pilot.equipped
	main_choice.select(maxi(0,main_keys.find(primary)))
	left_choice.select(maxi(0,left_keys.find(game.pilot.loadout.left)))
	armor_choice.select(game.pilot.loadout.armor)
	game.pilot.set_control(false);get_tree().paused=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;overlay.show();window.show();preset_buttons[0].grab_focus()

func equip_selected() -> void:
	game.pilot.loadout.configure(main_keys[main_choice.selected],left_keys[left_choice.selected],armor_choice.selected)
	if in_reach():
		game.armor_taken=true;game.armor_worn=true;game.clearance[2]=true;game.update_clearance(2)
	close()
	game.speak("ÉQUIPEMENT PRÊT · Clic gauche : main droite. Clic droit : main gauche. R : recharger.",6)

func close() -> void:
	window.hide();overlay.hide();get_tree().paused=false;game.pilot.set_control(true);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode!=KEY_I and event.physical_keycode!=KEY_I: return
	if window.visible:
		close();get_viewport().set_input_as_handled();return
	if get_tree().paused or not game.pilot.in_control or game.pilot.vehicle!=null or game.transition or game.defeated: return
	get_viewport().set_input_as_handled()
	if game.pilot.loadout.unlocked or in_reach(): open()
	else: game.speak("INVENTAIRE · Les équipements pour les deux mains se débloquent à l'armurerie de Copernic.",5)
