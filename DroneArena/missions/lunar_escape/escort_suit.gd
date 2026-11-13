extends "res://missions/lunar_escape/astronaut.gd"
## EVA suit with pressure joints, stitched textiles and replaceable ceramic plates.
var identity := "MAËL"
var accent := Color("87957b")
var clock := 0.0
var gait_weight := 0.0
var alert_weight := 0.0
var feet := preload("res://missions/lunar_escape/foot_placement.gd").new()
var pelvis_drop := 0.0

func build() -> void:
	super.build()
	ceramic.shader = preload("res://missions/lunar_escape/escort_suit.gdshader")
	ceramic.set_shader_parameter("tint",Color("e7e5dc"))
	cloth.shader = ceramic.shader
	cloth.set_shader_parameter("fabric",true)
	cloth.set_shader_parameter("tint",Color("f0eee3"))
	var trim := material(accent.lerp(Color("d3d0c5"),0.85),true)
	trim.shader = ceramic.shader
	for piece in find_children("*","MeshInstance3D",true,false):
		if piece.get_active_material(0)==WORLD.AMBER: piece.material_override = trim
	var rubber := material(Color("252c2c"),true)
	rubber.shader = ceramic.shader
	var pressure_torso := SphereMesh.new()
	pressure_torso.radius = 0.5; pressure_torso.height = 1.0
	pressure_torso.radial_segments = 32; pressure_torso.rings = 16
	torso.get_child(0).mesh = pressure_torso
	torso.get_child(0).scale = Vector3(0.49,0.53,0.33)
	# Replace the original flat visor; overlapping glass looked like a broken helmet.
	helmet.get_child(1).hide()
	helmet.get_child(2).hide()
	for limb in limbs:
		# Remove the old square dark cuff bars underneath the fabric bellows.
		for index in range(2,5): limb.lower.get_child(index).hide()
		var radius := 0.081 if limb.arm else 0.115
		var shoulder: MeshInstance3D = limb.upper.get_child(2)
		shoulder.scale *= Vector3(1.0,0.84,1.05)
		shoulder.material_override = cloth
		# Inflated fabric sleeves and trousers under smaller, curved protective shells.
		for segment in [limb.upper,limb.lower]:
			var sleeve: MeshInstance3D = segment.get_child(0)
			var pressure := CapsuleMesh.new()
			pressure.radius = radius*(1.0 if segment==limb.upper else 0.88)
			pressure.height = limb.length+0.035
			pressure.radial_segments = 24
			pressure.rings = 12
			sleeve.mesh = pressure
			var plating: MeshInstance3D = segment.get_child(1)
			plating.scale = Vector3(0.9,0.62,0.85)
			plating.material_override = cloth
			for fold in range(5):
				var cuff := TorusMesh.new()
				cuff.inner_radius = pressure.radius*0.83
				cuff.outer_radius = pressure.radius*0.98
				cuff.rings = 24; cuff.ring_segments = 6
				var wrinkle := MeshInstance3D.new()
				wrinkle.mesh = cuff; wrinkle.material_override = cloth
				segment.add_child(wrinkle)
				wrinkle.position.y = -0.14-fold*0.034
				wrinkle.rotation.z = sin(fold*1.7)*0.09
		# Flexible bellows at the elbow/knee and reinforced cuffs.
		for i in range(4):
			var ring := TorusMesh.new()
			ring.inner_radius = radius*0.78
			ring.outer_radius = radius
			ring.rings = 20
			ring.ring_segments = 10
			var visual := MeshInstance3D.new()
			visual.mesh = ring
			visual.material_override = cloth
			limb.lower.add_child(visual)
			visual.position.y = -0.025-i*0.025
		KIT.bevel(limb.upper,Vector3(0,-0.09,-radius),Vector3(radius*1.75,0.09,0.035),0.018,trim)
		KIT.bevel(limb.lower,Vector3(0,-limb.length*0.70,-radius*0.8),Vector3(radius*1.7,0.055,0.03),0.014,WORLD.STEEL)
		if limb.arm:
			# Separate glove fingers and knuckle guards follow the hand's IK transform.
			for finger in range(4):
				var x := -0.037+finger*0.024
				KIT.rod(limb.end,Vector3(x,-0.035,-0.025),Vector3(x,-0.084,-0.035),0.012,rubber,10)
				KIT.rod(limb.end,Vector3(x,-0.084,-0.035),Vector3(x,-0.094,-0.007),0.010,cloth,10)
				WORLD.ball(limb.end,Vector3(x,-0.030,-0.064),Vector3(0.019,0.027,0.016),ceramic)
		else:
			for tread in range(5):
				KIT.bevel(limb.end,Vector3(0,-0.074,-0.13+tread*0.06),Vector3(0.22,0.025,0.025),0.005,rubber)
	# Pressure hose, couplings and control pack are real geometry, not painted blocks.
	for side in [-1.0,1.0]:
		var previous := Vector3(side*0.14,1.13,-0.22)
		for i in range(1,15):
			var t := float(i)/14
			var p := Vector3(side*(0.14+sin(t*PI)*0.22),1.13-sin(t*PI)*0.19,-0.22+t*0.47)
			KIT.rod(torso,previous-Vector3(0,1.24,0),p-Vector3(0,1.24,0),0.022,cloth,12)
			previous = p
		WORLD.cylinder(torso,Vector3(side*0.14,-0.10,-0.20),0.039,0.039,0.045,WORLD.STEEL,Vector3(PI/2,0,0))
		KIT.bevel(torso,Vector3(side*0.12,0.13,-0.189),Vector3(0.19,0.035,0.012),0.004,trim)
		# Sewn utility pouch, stitched edge and restraint strap at each hip.
		KIT.bevel(torso,Vector3(side*0.22,-0.23,-0.10),Vector3(0.13,0.20,0.15),0.035,cloth)
		for y in [-0.17,-0.26]:
			KIT.bevel(torso,Vector3(side*0.22,y,-0.184),Vector3(0.11,0.012,0.012),0.003,rubber)
		KIT.bevel(torso,Vector3(side*0.21,-0.05,-0.178),Vector3(0.03,0.36,0.018),0.005,rubber)
	var badge := WORLD.placard(torso,identity+"\nKAREN · EVA",Vector3(0.11,0.02,-0.194),Color("233136"),PI)
	badge.pixel_size = 0.00042
	var glass := StandardMaterial3D.new()
	glass.resource_name="EVAVisor";glass.clearcoat_enabled=true;glass.clearcoat=.8;glass.clearcoat_roughness=.12
	glass.albedo_color = Color("11171b")
	glass.metallic = 0.65
	glass.roughness = 0.18
	WORLD.ball(helmet,Vector3(0,0.012,-0.105),Vector3(0.338,0.31,0.27),glass)
	for side in [-1.0,1.0]:
		KIT.bevel(helmet,Vector3(side*0.13,0.11,-0.12),Vector3(0.06,0.04,0.08),0.015,trim)
	preload("res://missions/lunar_escape/reference_eva.gd").dress(self)
	preload("res://missions/lunar_escape/eva_photo_finish.gd").dress(self)
	equip("smg")

func animate_escort(actor: CharacterBody3D, delta: float, aim: Vector3, reload_progress: float, firing: bool) -> void:
	clock += delta
	var speed := Vector2(actor.velocity.x,actor.velocity.z).length()
	var local_velocity := global_basis.inverse()*Vector3(actor.velocity.x,0,actor.velocity.z)
	var walk_direction := local_velocity.normalized()
	var alert: bool = is_instance_valid(actor.get("target")) or firing or reload_progress>0
	alert_weight = lerpf(alert_weight,1.0 if alert else 0.0,1-exp(-delta*8))
	var greeting: float = sin(clampf(float(actor.get("greeting_left"))/2.2,0,1)*PI) if not alert else 0.0
	var hurt: float = clampf(float(actor.get("hurt_left"))/0.22,0,1)
	gait_weight = lerpf(gait_weight,clampf(speed/4.5,0,1.3),1-exp(-delta*9))
	# Step length grows while running; breathing and weight shifts remain at rest.
	gait += speed*delta*lerpf(5.8,2.5,clampf(speed/5.0,0,1))
	var foot_contacts: Dictionary={}
	var required_drop:=0.0
	for limb in limbs:
		if limb.arm: continue
		var contact: Dictionary=feet.sample(self,limb.side,gait+(PI if limb.side<0 else 0),speed,walk_direction)
		foot_contacts[limb.side]=contact
		if contact.stance:
			var horizontal:=Vector2(limb.side*.15-contact.position.x,contact.position.z).length_squared()
			var vertical:=sqrt(maxf(.01,pow(limb.length*2-.006,2)-horizontal))
			required_drop=maxf(required_drop,.84-.035*gait_weight-contact.position.y-vertical)
	# Lower the pelvis when a planted boot would otherwise exceed the leg's reach.
	# Recover smoothly after toe-off; moving the torso keeps the shoulders connected.
	pelvis_drop=maxf(clampf(required_drop,0,.18),move_toward(pelvis_drop,0,delta*.4))
	torso.position.y = 1.24-.035*gait_weight-pelvis_drop+sin(clock*2.1+actor.slot)*0.006+cos(gait*2)*0.014*gait_weight
	torso.position.x = sin(gait)*0.012*gait_weight+sin(clock*0.8)*0.004*(1-alert_weight)
	torso.rotation.z = lerpf(torso.rotation.z,-local_velocity.x*0.008+sin(gait)*0.016*gait_weight,1-exp(-delta*8))
	torso.rotation.x = lerpf(torso.rotation.x,local_velocity.z*0.010-hurt*0.13,1-exp(-delta*12))
	var local_aim := to_local(aim)-Vector3(0,1.65,0)
	var heard_shot: bool = not alert and float(actor.get("listen_left")) > 0.0
	var listening: bool = not alert and not heard_shot and actor.squad.game.voice!=null and actor.squad.game.voice.playing and actor.global_position.distance_to(actor.squad.game.pilot.global_position)<7
	if listening: local_aim=to_local(actor.squad.game.pilot.get_aim_point())-Vector3(0,1.65,0)
	var scan := sin(clock*0.67+actor.slot*1.7)*0.28*(1-alert_weight)
	var attention := maxf(alert_weight,0.9 if actor.get("visitor_visible")==true and not actor.recruited else 0.0)
	if listening: attention=maxf(attention,.85)
	if heard_shot: attention = 1.0
	helmet.rotation.y = lerp_angle(helmet.rotation.y,clampf(atan2(-local_aim.x,-local_aim.z),-0.65,0.65)*attention+scan*(1-attention),1-exp(-delta*5))
	helmet.rotation.x = lerpf(helmet.rotation.x,-atan2(local_aim.y,maxf(0.1,Vector2(local_aim.x,local_aim.z).length()))*attention+sin(clock*1.1)*0.035-hurt*0.1,1-exp(-delta*7))
	gun_pivot.position = Vector3(0.17,1.17+alert_weight*0.08+sin(clock*2.1)*0.003,-0.12)
	if gun_pivot.global_position.distance_to(aim)>0.2: gun_pivot.look_at(aim)
	gun_pivot.rotate_object_local(Vector3.RIGHT,-0.42*(1-alert_weight)+(0.5*sin(reload_progress*PI) if reload_progress>0 else 0.0)-(0.045 if firing else 0.0))
	gun.shot_age += delta
	gun.pose_reload(reload_progress,0.4 if firing else 0.0)
	flash.visible = firing
	shot_light.visible = firing
	for limb in limbs:
		var side: float = limb.side
		if limb.arm:
			var grip := Vector3(0,-0.1,0.025) if side>0 else Vector3(-0.06,-0.07,-0.32)
			if side<0 and reload_progress>0: grip = grip.lerp(gun.magazine.position+Vector3(-0.04,-0.04,0),sin(reload_progress*PI))
			var hand := to_local(gun.to_global(grip))
			if not gun.visible:
				hand = Vector3(side*0.34,0.93+sin(clock*1.2+side)*0.012,-0.08+sin(gait+(PI if side>0 else 0))*gait_weight*0.14)
				if side<0:
					var radio_gesture := pow(maxf(0,sin(clock*0.55+actor.slot)),8.0)
					hand = hand.lerp(Vector3(-0.22,1.64,-0.06),radio_gesture)
					hand = hand.lerp(Vector3(-0.44,1.89,-0.13+sin(clock*9)*0.10),greeting)
			elif side<0:
				hand = hand.lerp(Vector3(-0.39,1.65+sin(clock*7)*0.035,-0.18),greeting)
			solve(limb,Vector3(side*0.30,1.40,0)+Vector3(torso.position.x,torso.position.y-1.24,0),hand,Vector3(side,0,0.5))
			if gun.visible and greeting<.05:
				var grip_basis: Basis = global_basis.inverse()*gun.global_basis
				limb.end.basis=grip_basis*Basis.from_euler(Vector3(0,0,-.10) if side>0 else Vector3(PI*.43,0,-.20))
		else:
			var contact: Dictionary=foot_contacts[side]
			solve(limb,Vector3(side*.15,.84-.035*gait_weight-pelvis_drop,0),contact.position,Vector3.FORWARD)
			limb.end.basis=Basis(Quaternion(Vector3.UP,contact.normal))
		var flex:=acos(clampf(limb.upper.basis.y.dot(limb.lower.basis.y),-1,1))
		for segment in [limb.upper,limb.lower]:
			var sleeve: MeshInstance3D=segment.get_child(0)
			if sleeve.material_override is ShaderMaterial: sleeve.material_override.set_shader_parameter("joint_flex",flex)
