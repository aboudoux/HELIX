extends Node3D
## Shared articulated suit for the player and the EVA armor stand.
const WORLD := preload("res://missions/lunar_escape/lunar_world.gd")
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const ARMORY := preload("res://missions/lunar_escape/armory.gd")
const SURFACE := preload("res://missions/lunar_escape/suit_surface.gdshader")
var torso: Node3D
var helmet: Node3D
var gun_pivot: Node3D
var gun: Node3D
var muzzle: Marker3D
var flash: MeshInstance3D
var shot_light: OmniLight3D
var limbs: Array[Dictionary] = []
var plates: Array[MeshInstance3D] = []
var reinforced := false
var gait := 0.0
var motion_weight := 0.0
var landing := 0.0
var was_grounded := true
var last_vertical_speed := 0.0
var equip_age := 1.0
var ceramic: ShaderMaterial
var cloth: ShaderMaterial
var shield: Node3D

func material(color: Color, textile: bool) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = SURFACE
	result.set_shader_parameter("tint",color)
	result.set_shader_parameter("fabric",textile)
	KIT.FINISH.PHOTO.bind_paint(result)
	KIT.FINISH.PHOTO.bind_fabric(result)
	return result

func build() -> void:
	ceramic = material(Color("e7e5dc"),false)
	cloth = material(Color("f0eee3"),true)
	torso = Node3D.new()
	add_child(torso)
	torso.position.y = 1.24
	KIT.bevel(torso,Vector3.ZERO,Vector3(0.48,0.48,0.29),0.10,cloth)
	for side in [-1.0,1.0]:
		var plate := KIT.bevel(torso,Vector3(side*0.124,0.045,-0.142),Vector3(0.24,0.28,0.075),0.035,ceramic)
		plate.rotation.z = side*0.10
		plates.append(plate)
		KIT.bevel(torso,Vector3(side*0.18,-0.16,-0.16),Vector3(0.125,0.13,0.08),0.018,WORLD.FRAME)
		KIT.bevel(torso,Vector3(side*0.23,0.15,0.025),Vector3(0.055,0.13,0.17),0.015,WORLD.AMBER)
	KIT.bevel(torso,Vector3(0,-0.21,0),Vector3(0.44,0.12,0.32),0.035,WORLD.FRAME)
	KIT.bevel(torso,Vector3(0,0.03,-0.19),Vector3(0.17,0.13,0.048),0.012,WORLD.STEEL)
	KIT.bevel(torso,Vector3(0,0.045,-0.218),Vector3(0.10,0.028,0.008),0.003,WORLD.CYAN)
	# Rear life support: separate pressure bottles, ribbed filters and straps.
	KIT.bevel(torso,Vector3(0,0.01,0.23),Vector3(0.40,0.46,0.19),0.045,ceramic)
	for side in [-1.0,1.0]:
		KIT.rod(torso,Vector3(side*0.12,-0.15,0.35),Vector3(side*0.12,0.17,0.35),0.075,WORLD.STEEL,16)
		for y in [-0.10,0.10]:
			KIT.bevel(torso,Vector3(side*0.12,y,0.40),Vector3(0.17,0.035,0.025),0.006,WORLD.FRAME)
	for i in range(4):
		KIT.bevel(torso,Vector3(0,-0.14+i*0.08,0.435),Vector3(0.06,0.023,0.025),0.004,WORLD.CYAN)
	WORLD.cylinder(torso,Vector3(0,0.29,0),0.14,0.16,0.10,WORLD.STEEL)
	build_helmet()
	for side in [-1.0,1.0]:
		limbs.append(make_limb(side,false))
		limbs.append(make_limb(side,true))
	gun_pivot = Node3D.new()
	add_child(gun_pivot)
	gun_pivot.position = Vector3(0.20,1.25,-0.14)
	shield = preload("res://missions/lunar_escape/shield.gd").new()
	add_child(shield)
	shield.build()
	shield.rotation.y = PI
	shield.hide()
	pose_rest()

func build_helmet() -> void:
	helmet = Node3D.new()
	torso.add_child(helmet)
	helmet.position.y = 0.42
	WORLD.ball(helmet,Vector3.ZERO,Vector3(0.36,0.38,0.34),ceramic)
	var glass := StandardMaterial3D.new()
	glass.resource_name="EVAVisor";glass.clearcoat_enabled=true;glass.clearcoat=.8;glass.clearcoat_roughness=.12
	glass.albedo_color = Color("bf954b")
	glass.metallic = 0.88
	glass.roughness = 0.20
	KIT.bevel(helmet,Vector3(0,0,-0.151),Vector3(0.30,0.17,0.075),0.055,glass)
	KIT.bevel(helmet,Vector3(0,0.085,-0.171),Vector3(0.24,0.012,0.02),0.004,WORLD.STEEL)
	for side in [-1.0,1.0]:
		WORLD.ball(helmet,Vector3(side*0.18,0,0),Vector3(0.08,0.13,0.13),WORLD.FRAME)
		KIT.bevel(helmet,Vector3(side*0.13,-0.07,-0.13),Vector3(0.035,0.025,0.028),0.006,WORLD.AMBER)

func make_limb(side: float, arm: bool) -> Dictionary:
	var upper := Node3D.new()
	var lower := Node3D.new()
	add_child(upper)
	add_child(lower)
	var length := 0.36 if arm else 0.42
	var width := 0.15 if arm else 0.21
	KIT.bevel(upper,Vector3(0,-length*0.5,0),Vector3(width,length,width),width*0.30,cloth)
	var armor := KIT.bevel(upper,Vector3(0,-length*0.42,-width*0.36),Vector3(width*1.08,length*0.65,width*0.57),0.03,ceramic)
	plates.append(armor)
	WORLD.ball(upper,Vector3.ZERO,Vector3.ONE*width*1.25,ceramic)
	KIT.bevel(lower,Vector3(0,-length*0.5,0),Vector3(width*0.85,length,width*0.85),0.04,cloth)
	KIT.bevel(lower,Vector3(0,-length*0.55,-width*0.38),Vector3(width*0.85,length*0.73,width*0.54),0.022,ceramic)
	for i in range(3):
		KIT.bevel(lower,Vector3(0,-0.025-i*0.026,0),Vector3(width,0.014,width),0.004,WORLD.FRAME)
	var end := KIT.bevel(self,Vector3.ZERO,Vector3(0.105,0.13,0.15) if arm else Vector3(0.23,0.16,0.35),0.035,cloth)
	return {"upper":upper,"lower":lower,"end":end,"side":side,"arm":arm,"length":length}

func solve(limb: Dictionary, origin: Vector3, target: Vector3, bend: Vector3) -> void:
	var length: float = limb.length
	var delta := target-origin
	var distance := clampf(delta.length(),0.04,length*2.0-0.002)
	var direction := delta.normalized()
	var knee_direction := (bend-direction*bend.dot(direction)).normalized()
	var joint := origin+direction*distance*0.5+knee_direction*sqrt(maxf(0,length*length-distance*distance*0.25))
	var foot := origin+direction*distance
	limb.upper.position = origin
	limb.upper.basis = Basis(Quaternion(Vector3.DOWN,origin.direction_to(joint)))
	limb.lower.position = joint
	limb.lower.basis = Basis(Quaternion(Vector3.DOWN,joint.direction_to(foot)))
	limb.end.position = foot
	if limb.arm: limb.end.basis = limb.lower.basis

func pose_rest() -> void:
	for limb in limbs:
		var side: float = limb.side
		if limb.arm:
			solve(limb,Vector3(side*0.30,1.40,0),Vector3(side*0.34,0.88,-0.08),Vector3(side,0,1))
		else:
			solve(limb,Vector3(side*0.15,0.88,0),Vector3(side*0.16,0.09,-0.03),Vector3.FORWARD)

func set_reinforced(value: bool) -> void:
	reinforced = value
	ceramic.set_shader_parameter("tint",Color("e9e8e0") if value else Color("e7e5dc"))
	for plate in plates: plate.scale = Vector3.ONE*(1.13 if value else 1.0)

func equip(key: String) -> void:
	equip_age = 0.0
	if is_instance_valid(gun):
		gun.hide()
		gun.queue_free()
	gun = ARMORY.new()
	gun_pivot.add_child(gun)
	gun.build(key,false)
	muzzle = Marker3D.new()
	gun.add_child(muzzle)
	muzzle.position = gun.muzzle
	flash = WORLD.ball(muzzle,Vector3(0,0,-0.03),Vector3(0.085,0.085,0.14),preload("res://materials/WhiteLight.tres"))
	flash.hide()
	shot_light = OmniLight3D.new()
	muzzle.add_child(shot_light)
	shot_light.light_color = Color("ffe6bc")
	shot_light.light_energy = 1.2
	shot_light.omni_range = 2.8
	shot_light.hide()

func animate(pilot: CharacterBody3D, delta: float, target: Vector3) -> void:
	var speed := Vector2(pilot.velocity.x,pilot.velocity.z).length()
	gait += speed*delta*1.75
	motion_weight = lerpf(motion_weight,minf(speed/6.0,1.4),1.0-exp(-delta*10.0))
	var moving := motion_weight
	var grounded := pilot.is_on_floor()
	if grounded and not was_grounded: landing = clampf(-last_vertical_speed*0.016,0.0,0.16)
	landing = move_toward(landing,0.0,delta*0.6)
	was_grounded = grounded
	last_vertical_speed = pilot.velocity.y
	var crouch: float = 1.0-pilot.capsule.height/pilot.STANDING_HEIGHT
	torso.position.y = 1.24-crouch*0.80+sin(gait*2)*0.018*moving-landing
	var local_velocity := global_basis.inverse()*pilot.velocity
	torso.rotation.x = lerpf(torso.rotation.x,-clampf(-local_velocity.z/9.5, -1.0,1.0)*0.09,1.0-exp(-delta*9.0))
	torso.rotation.z = lerpf(torso.rotation.z,-local_velocity.x*0.008,1.0-exp(-delta*9.0))
	helmet.rotation.x = pilot.head.rotation.x*0.6
	if gun==null: return
	var pose: float = pilot.weapon.reload_pose()
	equip_age += delta
	var draw := 1.0-smoothstep(0.0,0.30,equip_age)
	gun_pivot.position = Vector3(0.20,1.25-crouch*0.80-landing,-0.14)
	gun_pivot.look_at(target,Vector3.UP)
	gun_pivot.rotate_object_local(Vector3.BACK,-pose*0.25)
	gun_pivot.rotate_object_local(Vector3.RIGHT,pose*0.18-pilot.weapon.recoil*0.06)
	gun_pivot.rotate_object_local(Vector3.RIGHT,-draw*0.45)
	gun.shot_age += delta
	gun.pose_reload(1.0-pilot.weapon.reload_remaining/pilot.weapon.reload_duration if pilot.weapon.is_reloading else 0.0,pilot.weapon.recoil)
	flash.visible = pilot.weapon.flash_time>0
	shot_light.visible = flash.visible
	var walk_direction := global_basis.inverse()*Vector3(pilot.velocity.x,0,pilot.velocity.z).normalized()
	for limb in limbs:
		var side: float = limb.side
		if limb.arm:
			var grip := Vector3(0,-0.10,0.025) if side>0 else (Vector3(-0.06,-0.10,-0.03) if pilot.equipped=="pistol" else Vector3(-0.06,-0.07,-0.40 if pilot.equipped=="shotgun" else -0.32))
			if side<0:
				if pilot.equipped=="shotgun": grip.z += gun.action.position.z-gun.action_seat.z
				grip = grip.lerp(gun.magazine.position+Vector3(-0.045,-0.035,0.025),pose)
			if side<0 and pilot.shielding:
				solve(limb,Vector3(-0.30,torso.position.y+0.16,0),Vector3(-0.32,1.05-crouch*0.8,-0.43),Vector3.LEFT)
				continue
			solve(limb,Vector3(side*0.30,torso.position.y+0.16,-0.05 if side<0 else 0.0),to_local(gun.to_global(grip)),Vector3(side,0,0.5))
		else:
			var phase: float = gait+(PI if side<0 else 0.0)
			var ground := pilot.is_on_floor()
			var step := sin(phase)*moving if ground else 0.0
			var target_foot := Vector3(side*0.16+walk_direction.x*step*0.13,0.09+maxf(0,step)*0.14,walk_direction.z*step*0.25)
			if not ground:
				target_foot += Vector3(0,0.10+clampf(pilot.velocity.y*0.018,0,0.13),0.12*side)
			else:
				var foot_world := to_global(target_foot)
				var floor_hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(foot_world+Vector3.UP*0.35,foot_world-Vector3.UP*0.35,1,[pilot.get_rid()]))
				if not floor_hit.is_empty(): target_foot.y += clampf(to_local(floor_hit.position).y,-0.20,0.23)
			solve(limb,Vector3(side*0.15,0.88-crouch*0.65-landing,0),target_foot,Vector3.FORWARD)
	shield.position = Vector3(-0.32,1.1-crouch*0.8,-0.53)
	shield.visible = pilot.shielding
	shield.set_charge(pilot.shield_charge)
