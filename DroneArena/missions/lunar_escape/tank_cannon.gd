extends Node3D
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const METAL := preload("res://materials/WeaponSilver.tres")
const DARK := preload("res://materials/Frame.tres")
var barrel: Node3D
var muzzle: Marker3D
var flash: MeshInstance3D
var light: OmniLight3D
var shot_age:=10.0
var shots:=0

func _ready() -> void:
	KIT.bevel(self,Vector3(0,0,.08),Vector3(.72,.58,.56),.1,DARK)
	KIT.rod(self,Vector3(0,0,.12),Vector3(0,0,-.34),.23,METAL,24)
	barrel=Node3D.new();barrel.name="TubeMobile";add_child(barrel)
	KIT.rod(barrel,Vector3.ZERO,Vector3(0,0,-1.55),.13,METAL,24)
	KIT.bevel(barrel,Vector3(0,0,-1.48),Vector3(.40,.32,.30),.05,DARK)
	KIT.rod(barrel,Vector3(0,0,-1.61),Vector3(0,0,-1.64),.10,DARK,24)
	muzzle=Marker3D.new();barrel.add_child(muzzle);muzzle.position=Vector3(0,0,-1.66)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color("ffdf8b");material.emission_enabled=true;material.emission=Color("ffac42");material.emission_energy_multiplier=3
	flash=MeshInstance3D.new();flash.mesh=SphereMesh.new();flash.material_override=material
	muzzle.add_child(flash);flash.position.z=-.35;flash.scale=Vector3(.48,.48,.85);flash.hide()
	light=OmniLight3D.new();muzzle.add_child(light);light.light_color=Color("ffc481");light.light_energy=4;light.omni_range=10;light.hide()

func fire() -> void:
	shot_age=0.0;shots+=1
	flash.show();light.show()

func _process(delta: float) -> void:
	shot_age+=delta
	var recoil:=.46*smoothstep(0.0,.065,shot_age)*(1.0-smoothstep(.09,.72,shot_age))
	barrel.position.z=recoil
	flash.visible=shot_age<.075;light.visible=flash.visible
