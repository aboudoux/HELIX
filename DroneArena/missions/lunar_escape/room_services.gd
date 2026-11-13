extends RefCounted
## Connected ventilation, pipe supports and visible light sources in occupied rooms.
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")

static func dress(details: Node3D, index: int) -> void:
	var back: float=-(19.0-float(WORLD.ROOM_DIVIDERS[index][2]))*.5+.22
	var services:=Node3D.new();services.name="CircuitAir";details.add_child(services)
	for x in [-8.2,8.2]:
		# Pipe ends terminate in a pressure regulator and ceiling distribution duct.
		KIT.rod(services,Vector3(x,3.85,back+.4),Vector3(x,3.85,4.7),.075,WORLD.STEEL)
		KIT.rod(services,Vector3(x,3.85,back+.4),Vector3(x,2.9,back+.4),.075,WORLD.STEEL)
		KIT.bevel(services,Vector3(x,2.55,back+.30),Vector3(.70,.90,.38),.08,WORLD.WHITE)
		for z in [back+.8,0.0,4.5]:
			KIT.rod(services,Vector3(x,3.85,z-.06),Vector3(x,3.85,z+.06),.105,WORLD.FRAME)
			KIT.rod(services,Vector3(x,3.96,z),Vector3(x,4.48,z),.025,WORLD.STEEL)
		KIT.rod(services,Vector3(x,3.85,4.7),Vector3(x,4.4,4.7),.075,WORLD.STEEL)
		KIT.bevel(services,Vector3(x,4.39,4.7),Vector3(.45,.22,.45),.04,WORLD.FRAME)
		# Recessed louvres and gasket; they sit on the module, never over a door.
		KIT.bevel(services,Vector3(x,2.55,back+.51),Vector3(.56,.60,.04),.025,WORLD.GRIP)
		for i in range(6):
			KIT.bevel(services,Vector3(x,2.32+i*.09,back+.55),Vector3(.49,.035,.08),.008,WORLD.STEEL).rotation.x=-.3
		WORLD.placard(services,"AIR · FILTRE 02",Vector3(x,2.94,back+.515),Color("40494a")).pixel_size=.0008
	var color: Color=[Color("ffe6bd"),Color("ffdfb2"),Color("d6e8ff")][index]
	var lens:=StandardMaterial3D.new();lens.albedo_color=color;lens.roughness=.65
	lens.emission_enabled=true;lens.emission=color;lens.emission_energy_multiplier=.65
	for x in [-3.0,3.0]:
		KIT.rod(services,Vector3(x,4.48,2.3),Vector3(x,4.12,2.3),.035,WORLD.STEEL)
		KIT.bevel(services,Vector3(x,4.07,2.3),Vector3(1.2,.16,.48),.055,WORLD.FRAME)
		var diffuser:=WORLD.block(services,Vector3(x,3.98,2.3),Vector3(1.08,.025,.36),lens)
		diffuser.set_meta("base_power_fixture",true)
		var lamp:=SpotLight3D.new();services.add_child(lamp);lamp.name="EclairageHabitat"
		lamp.position=Vector3(x,3.93,2.3);lamp.rotation.x=-PI/2
		lamp.light_color=color;lamp.light_energy=1.3;lamp.spot_range=5.6;lamp.spot_angle=67
		lamp.light_size=.45;lamp.shadow_enabled=true;lamp.set_meta("base_power_fixture",true)
	# Low intensity local bounce keeps fabric legible without brightening lunar nights.
	var bounce:=OmniLight3D.new();services.add_child(bounce);bounce.name="RebondHabitat"
	bounce.position=Vector3(0,2.5,1);bounce.light_color=color;bounce.light_energy=.24
	bounce.omni_range=8;bounce.shadow_enabled=true;bounce.set_meta("base_power_fixture",true)
	var probe:=ReflectionProbe.new();services.add_child(probe);probe.name="RefletsInterieurs"
	probe.position=Vector3(0,2.25,0);probe.size=Vector3(18,4.4,(19.0-float(WORLD.ROOM_DIVIDERS[index][2]))-.2)
	probe.interior=true;probe.box_projection=true;probe.intensity=.55
	probe.update_mode=ReflectionProbe.UPDATE_ONCE;probe.max_distance=20
	probe.set_meta("base_power_fixture",true)
