extends Node3D
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
var bars: Array[MeshInstance3D] = []
var plate: MeshInstance3D
var impact := 0.0
var surface: ShaderMaterial

func build() -> void:
	surface = ShaderMaterial.new()
	surface.shader = preload("res://missions/lunar_escape/shield_surface.gdshader")
	WORLD.FINISH.RESEARCH.bind(surface,WORLD.FINISH.RESEARCH.Kind.POLYMER)
	plate = polygon_plate(1.0,0.10,WORLD.STEEL)
	polygon_plate(0.91,0.13,surface)
	# Reinforced rim, segmented armor and a rear grip make a tangible shield.
	for side in [-1.0,1.0]:
		KIT.bevel(self,Vector3(side*0.22,0.10,0.072),Vector3(0.05,0.57,0.025),0.012,WORLD.FRAME)
		KIT.bevel(self,Vector3(side*0.235,0.15,0.088),Vector3(0.014,0.37,0.012),0.004,WORLD.CYAN)
		for y in [-0.23,0.31]:
			WORLD.cylinder(self,Vector3(side*0.19,y,0.083),0.014,0.014,0.012,WORLD.STEEL,Vector3(PI/2,0,0))
	KIT.bevel(self,Vector3(0,0.20,0.083),Vector3(0.27,0.17,0.032),0.025,WORLD.FRAME)
	var inset := StandardMaterial3D.new()
	inset.albedo_color = Color("355a64")
	inset.metallic = 0.0
	inset.roughness = 0.18
	KIT.bevel(self,Vector3(0,0.20,0.104),Vector3(0.22,0.11,0.013),0.015,inset)
	for i in range(5):
		bars.append(KIT.bevel(self,Vector3(-0.076+i*0.038,-0.21,0.081),Vector3(0.026,0.045,0.015),0.005,WORLD.CYAN))
	KIT.rod(self,Vector3(-0.10,-0.10,-0.10),Vector3(0.10,-0.10,-0.10),0.033,WORLD.GRIP)
	for x in [-0.11,0.11]: KIT.rod(self,Vector3(x,-0.10,-0.10),Vector3(x,-0.10,-0.035),0.025,WORLD.STEEL)
	var badge := WORLD.placard(self,"EVA\nA-07",Vector3(0,-0.03,0.089),Color("d5e0dd"))
	badge.pixel_size = 0.0009

func polygon_plate(size: float, depth: float, material: Material) -> MeshInstance3D:
	var outline := PackedVector2Array([Vector2(-0.19,0.47),Vector2(0.19,0.47),Vector2(0.30,0.30),Vector2(0.28,-0.23),Vector2(0.12,-0.44),Vector2(-0.12,-0.44),Vector2(-0.28,-0.23),Vector2(-0.30,0.30)])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		for i in range(outline.size()):
			var a := outline[i]*size
			var b := outline[(i+1)%outline.size()]*size
			var points := [Vector3(0,0,side*depth*0.5),Vector3(a.x,a.y,side*depth*0.5),Vector3(b.x,b.y,side*depth*0.5)]
			for j in [0,2,1] if side<0 else [0,1,2]:
				tool.set_normal(Vector3(0,0,side))
				tool.add_vertex(points[j])
	for i in range(outline.size()):
		var a := outline[i]*size
		var b := outline[(i+1)%outline.size()]*size
		var normal := Vector3(a.y-b.y,b.x-a.x,0).normalized()
		var points := [Vector3(a.x,a.y,-depth/2),Vector3(b.x,b.y,-depth/2),Vector3(b.x,b.y,depth/2),Vector3(a.x,a.y,depth/2)]
		for j in [0,1,2,0,2,3]:
			tool.set_normal(normal)
			tool.add_vertex(points[j])
	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	mesh.material_override = material
	add_child(mesh)
	return mesh

func set_charge(charge: float) -> void:
	for i in range(bars.size()): bars[i].material_override = WORLD.CYAN if charge>i*20 else WORLD.FRAME

func hit() -> void:
	impact = 1.0

func _process(delta: float) -> void:
	impact = move_toward(impact,0.0,delta*3.5)
	if surface!=null: surface.set_shader_parameter("impact",impact)
