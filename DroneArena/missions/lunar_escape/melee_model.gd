extends Node3D
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
var glove: Node3D
var hand_side := 1.0

func build(kind: String, held := false, left := false) -> void:
	var blade := KIT.FINISH.create(Color("a9b4b8"),.88,.28,.12)
	var grip := KIT.FINISH.create(Color("20262a"),0,.91,.08)
	if kind=="sabre":
		# A tapered steel blade with a bevelled spine, guard and wrapped grip.
		KIT.rod(self,Vector3(0,-.11,.16),Vector3(0,.10,.16),.024,grip,16)
		KIT.bevel(self,Vector3(0,.11,.16),Vector3(.22,.025,.055),.008,WORLD.STEEL)
		var mesh := SurfaceTool.new(); mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
		var a:=Vector3(-.027,.12,.16);var b:=Vector3(.027,.12,.16)
		var c:=Vector3(.018,.88,.12);var d:=Vector3(.0,1.08,.09)
		var e:=Vector3(-.022,.84,.12)
		for side in [-1,1]:
			var ridge := Vector3(0,.48,.16+side*.012)
			var edge := [a,b,c,d,e]
			for i in range(5):
				for point in ([edge[i],edge[(i+1)%5],ridge] if side>0 else [ridge,edge[(i+1)%5],edge[i]]): mesh.add_vertex(point)
		mesh.generate_normals()
		var visual := MeshInstance3D.new();visual.mesh=mesh.commit();visual.material_override=blade;add_child(visual)
	else:
		KIT.rod(self,Vector3(0,-.48,.22),Vector3(0,.95,-.20),.022,WORLD.FRAME,16)
		KIT.rod(self,Vector3(0,-.08,.10),Vector3(0,.12,.04),.030,grip,16)
		WORLD.cylinder(self,Vector3(0,1.09,-.24),0,.09,.40,blade,Vector3(-.28,0,0))
		KIT.bevel(self,Vector3(0,.87,-.17),Vector3(.12,.08,.08),.016,WORLD.STEEL)
	for i in range(7):
		KIT.rod(self,Vector3(-.024,-.085+i*.025,.16),Vector3(.024,-.085+i*.025,.16),.0025,WORLD.STEEL,6)
	if held:
		glove = Node3D.new();add_child(glove)
		preload("res://missions/lunar_escape/view_gloves.gd").build(glove,false)
		glove.position.y=.10
		if left: scale.x=-1;hand_side=-1
		for node in find_children("*","GeometryInstance3D",true,false):
			node.layers=2;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func align_forearms(camera: Camera3D) -> void:
	if glove!=null: preload("res://missions/lunar_escape/view_gloves.gd").align_forearm(glove,camera,hand_side)
