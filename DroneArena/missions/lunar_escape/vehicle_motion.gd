extends Node3D
## Visual suspension is independent of the stable driving collision hull.
var ride: Node3D
var world: Node3D
var chassis: Node3D
var wheels: Array[Dictionary]=[]
var dust: Array[CPUParticles3D]=[]
var last_position: Vector3
var last_yaw:=0.0
var last_speed:=0.0
var pitch:=0.0
var roll:=0.0
var lift:=0.0
var travel:=0.0
var cannon: Node3D
var cannon_rest: Vector3
const TRACK_LENGTH:=7.6+TAU*.47

static func track_pose(link: Node3D, distance: float, x: float) -> void:
	var d:=fposmod(distance,TRACK_LENGTH)
	if d<3.8:
		link.position=Vector3(x,.995,-1.9+d);link.rotation.x=0
	elif d<3.8+PI*.47:
		var a: float=(d-3.8)/.47
		link.position=Vector3(x,.525+cos(a)*.47,1.9+sin(a)*.47);link.rotation.x=a
	elif d<7.6+PI*.47:
		link.position=Vector3(x,.055,1.9-(d-3.8-PI*.47));link.rotation.x=PI
	else:
		var a: float=(d-7.6-PI*.47)/.47
		link.position=Vector3(x,.525-cos(a)*.47,-1.9-sin(a)*.47);link.rotation.x=PI+a

func setup(vehicle: Node3D, surface: Node3D) -> void:
	ride=vehicle;world=surface;name="Suspension"
	chassis=Node3D.new();chassis.name="ChassisVisuel";ride.add_child(chassis)
	for node in ride.get_children():
		if node==self or node==chassis or node.name in ["ParkedCollision","Canon"]: continue
		if node is Node3D: node.reparent(chassis,false)
	for wheel in ride.get_meta("wheels"):
		wheels.append({"node":wheel,"rest":wheel.position})
	cannon=ride.get_node_or_null("Canon")
	if cannon!=null: cannon_rest=cannon.position
	last_position=ride.global_position;last_yaw=ride.rotation.y
	var material:=StandardMaterial3D.new();material.albedo_color=Color("77766f");material.roughness=1
	var grain:=SphereMesh.new();grain.radius=.015;grain.height=.03;grain.radial_segments=6;grain.rings=3
	for x in ([0.0] if ride.get_meta("motorcycle",false) else [-1.68,1.68]):
		var particles:=CPUParticles3D.new();particles.name="PoussiereBalistique";ride.add_child(particles)
		particles.position=Vector3(x,.13,.96 if ride.get_meta("motorcycle",false) else 1.9)
		particles.amount=32;particles.lifetime=.85;particles.emitting=false;particles.local_coords=false
		particles.mesh=grain;particles.material_override=material
		particles.direction=Vector3(0,.45,1);particles.spread=18
		particles.initial_velocity_min=.6;particles.initial_velocity_max=1.4
		particles.gravity=Vector3(0,-1.62,0);particles.scale_amount_min=.6;particles.scale_amount_max=2
		particles.visibility_aabb=AABB(Vector3(-6,-3,-6),Vector3(12,6,12))
		dust.append(particles)

func ground_at(point: Vector3) -> Dictionary:
	var exclusions: Array[RID]=[ride.get_node("ParkedCollision").get_rid()]
	var pilot: CharacterBody3D=world.get_parent().pilot
	if is_instance_valid(pilot): exclusions.append(pilot.get_rid())
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.65,point-Vector3.UP*.85,1,exclusions))

func _physics_process(delta: float) -> void:
	var displacement:=ride.global_position-last_position
	var teleported:=displacement.length()>3.0
	var speed:=0.0 if teleported else displacement.dot(-ride.global_basis.z)/maxf(delta,.001)
	var yaw_speed:=0.0 if teleported else angle_difference(last_yaw,ride.rotation.y)/maxf(delta,.001)
	last_position=ride.global_position;last_yaw=ride.rotation.y
	if teleported: pitch=0;roll=0;lift=0;last_speed=0
	var front:=0.0;var back:=0.0;var left:=0.0;var right:=0.0
	var ground_count:=0;var front_count:=0;var back_count:=0;var left_count:=0;var right_count:=0
	for entry in wheels:
		var rest: Vector3=entry.rest
		var query_point:=ride.to_global(Vector3(rest.x,.12,rest.z))
		var hit:=ground_at(query_point)
		entry["height"]=0.0
		if hit.is_empty(): continue
		var height: float=hit.position.y-ride.global_position.y
		entry.height=height;ground_count+=1
		if rest.z<0: front+=height;front_count+=1
		elif rest.z>0: back+=height;back_count+=1
		if rest.x<0: left+=height;left_count+=1
		elif rest.x>0: right+=height;right_count+=1
	front/=maxi(1,front_count);back/=maxi(1,back_count)
	left/=maxi(1,left_count);right/=maxi(1,right_count)
	var bike: bool=ride.get_meta("motorcycle",false)
	var slope_pitch:=atan2(front-back,1.96 if bike else 3.8)
	var slope_roll:=0.0 if bike else atan2(right-left,3.36)
	var acceleration:=clampf((speed-last_speed)/maxf(delta,.001),-12,12);last_speed=speed
	var lean:=clampf(-yaw_speed*speed*.012,-.20,.20) if bike else clampf(-yaw_speed*speed*.002,-.04,.04)
	var weight:=1-exp(-delta*8)
	pitch=lerpf(pitch,clampf(slope_pitch-acceleration*.002,-.20,.20),weight)
	roll=lerpf(roll,clampf(slope_roll+lean,-.22,.22),weight)
	lift=lerpf(lift,clampf((front+back)*.5,-.12,.12),weight)
	chassis.rotation=Vector3(pitch,0,roll);chassis.position.y=lift
	for entry in wheels:
		var rest: Vector3=entry.rest
		var predicted: float=(chassis.transform*rest).y-rest.y
		entry.node.position.y=lerpf(entry.node.position.y,rest.y+clampf(entry.height-predicted,-.12,.12),weight)
	# The turret keeps independent aim; only its base follows suspension travel.
	if cannon!=null: cannon.position=chassis.transform*cannon_rest
	travel+=speed*delta
	for entry in ride.get_meta("track_links",[]): track_pose(entry.node,entry.phase+travel,entry.x)
	var moving_on_dust: bool=absf(speed)>1 and ground_count>0 and not world.air_at(ride.global_position)
	for particles in dust:
		var hit:=ground_at(particles.global_position)
		particles.emitting=moving_on_dust and not hit.is_empty() and hit.collider.get_meta("impact_surface","")=="dust"
		particles.direction=Vector3(0,.45,signf(speed))
