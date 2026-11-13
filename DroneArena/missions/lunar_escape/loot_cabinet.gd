extends Node3D
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const WHITE := preload("res://materials/Ivory.tres")
const FRAME := preload("res://materials/Frame.tres")
const STEEL := preload("res://materials/WeaponSilver.tres")
const AMBER := preload("res://materials/Amber.tres")
var doors: Array[Node3D]=[]
var handle: Marker3D
var contents: Node3D
var opened := false
var moving := false
var taken := false
var loot: Dictionary={}
var initial_loot: Dictionary={}
var width := 1.0
var height := 1.0
var depth := 1.0
var sound: AudioStreamPlayer3D

func build(w: float,h: float,d: float) -> void:
	width=w;height=h;depth=d
	name="Placard";add_to_group("loot_cabinets")
	var finish := KIT.FINISH
	var casing := finish.architecture(FRAME, finish.Detail.PAINTED_PANEL)
	var enamel := finish.architecture(WHITE, finish.Detail.PAINTED_PANEL)
	var liner := finish.architecture(preload("res://materials/Inset.tres"), finish.Detail.LAMINATE)
	# Hollow housing, with a real back, side walls and shelves.
	KIT.bevel(self,Vector3(0,h*.5,-d*.45),Vector3(w,h,.10),.025,casing,true)
	for side in [-1.0,1.0]:
		KIT.bevel(self,Vector3(side*(w*.5-.045),h*.5,0),Vector3(.09,h,d),.022,casing,true)
	for y in [.055,h*.48,h-.055]:
		KIT.bevel(self,Vector3(0,y,0),Vector3(w-.10,.10,d),.025,liner,true)
	for side in [-1.0,1.0]:
		var hinge:=Node3D.new();add_child(hinge);hinge.position=Vector3(side*(w*.5-.04),h*.5,d*.5)
		var panel:=KIT.bevel(hinge,Vector3(-side*w*.245,0,0),Vector3(w*.49-.035,h-.15,.075),.025,enamel)
		KIT.bevel(panel,Vector3(0,-(h-.15)*.39,.039),Vector3(w*.38,.024,.008),.003,casing)
		KIT.rod(panel,Vector3(-side*w*.16,-.11,.065),Vector3(-side*w*.16,.11,.065),.018,STEEL)
		var body:=AnimatableBody3D.new();hinge.add_child(body);body.position=panel.position
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(w*.49-.035,h-.15,.075);shape.shape=box;body.add_child(shape)
		doors.append(hinge)
	handle=Marker3D.new();add_child(handle);handle.position=Vector3(0,minf(h*.6,1.35),d*.5+.20)
	contents=Node3D.new();add_child(contents)
	sound=AudioStreamPlayer3D.new();add_child(sound);sound.stream=preload("res://audio/door_open.wav");sound.volume_db=-20;sound.max_distance=10

func stock(items: Dictionary) -> void:
	loot=items.duplicate(true);initial_loot=loot.duplicate(true)
	refresh_contents()

func refresh_contents() -> void:
	for child in contents.get_children(): child.hide();child.queue_free()
	contents.visible=not taken
	var size:=minf(1.0,width/1.4)
	var packs:=Node3D.new();contents.add_child(packs);packs.scale=Vector3.ONE*size
	packs.position=Vector3(0,.13,0)
	for i in range(3):
		var box:=KIT.bevel(packs,Vector3((i-1)*.31,.14,0),Vector3(.25,.27,.30),.025,WHITE if i==0 else FRAME)
		KIT.bevel(box,Vector3(0,0,.155),Vector3(.18,.04,.012),.004,AMBER)
	if int(loot.get("food",0))>0:
		var ration:=KIT.bevel(contents,Vector3(width*.28,height*.48+.14,0),Vector3(.25,.18,.22)*size,.025,WHITE)
		var label:=Label3D.new();ration.add_child(label);label.text="RATION";label.font_size=20;label.pixel_size=.00075*size;label.position=Vector3(0,0,.112*size);label.modulate=Color("364945");label.outline_size=0
	var key: String=loot.get("weapon","")
	if not key.is_empty():
		var gun:=preload("res://missions/lunar_escape/armory.gd").new();contents.add_child(gun);gun.build(key,false)
		gun.position=Vector3(-width*.17,height*.48+.18,.04);gun.rotation.y=PI/2;gun.scale=Vector3.ONE*minf(1.0,width*.70)

func clear_swing() -> bool:
	var query:=PhysicsShapeQueryParameters3D.new();var box:=BoxShape3D.new()
	box.size=Vector3(width+.08,height,width*.52);query.shape=box;query.collision_mask=30
	query.transform=global_transform*Transform3D(Basis.IDENTITY,Vector3(0,height*.5,depth*.5+width*.26))
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func toggle() -> bool:
	if moving or not clear_swing(): return false
	moving=true;opened=not opened;sound.play()
	var tween:=create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	for i in range(2): tween.tween_property(doors[i],"rotation:y",(-1 if i==0 else 1)*PI*.5 if opened else 0.0,.42).set_trans(Tween.TRANS_SINE)
	await tween.finished;moving=false
	return true

func restore(state: Dictionary) -> void:
	opened=state.get("opened",false);taken=state.get("taken",false);moving=false
	loot=state.get("loot",initial_loot).duplicate(true)
	for i in range(2): doors[i].rotation.y=(-1 if i==0 else 1)*PI*.5 if opened else 0
	refresh_contents()
