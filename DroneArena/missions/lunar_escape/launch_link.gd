extends StaticBody3D
## A repairable launch uplink. Enemy bolts hit it; friendly fire cannot disable it.
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
var health := 100
var lamp: MeshInstance3D
var label: Label3D

func _ready() -> void:
	collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5,2.3,1.0)
	shape.shape = box
	shape.position.y = 1.15
	add_child(shape)
	KIT.bevel(self,Vector3(0,1.1,0),Vector3(1.5,2.2,1.0),0.13,WORLD.STEEL)
	lamp = KIT.bevel(self,Vector3(0,1.4,0.54),Vector3(1.1,0.37,0.08),0.025,WORLD.CYAN)
	KIT.rod(self,Vector3(0,2.2,0),Vector3(0,4,0),0.05,WORLD.STEEL)
	label = WORLD.placard(self,"LIAISON LINA · 100 %",Vector3(0,2.55,0.1),Color("a2edda"))

func apply_damage(amount: int) -> bool:
	health = maxi(0,health-amount)
	lamp.material_override = WORLD.RED if health==0 else WORLD.AMBER
	label.text = "LIAISON COUPÉE · E : RÉPARER" if health==0 else "LIAISON LINA · %d %%"%health
	return true

func repair() -> void:
	health = 100
	lamp.material_override = WORLD.CYAN
	label.text = "LIAISON LINA · 100 %"
