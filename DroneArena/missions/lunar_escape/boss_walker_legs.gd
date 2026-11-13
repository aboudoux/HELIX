extends Node3D
const KIT := preload("res://missions/lunar_escape/mesh_kit.gd")
const COLLISION := preload("res://scripts/actor_collision.gd")
var legs: Array[Dictionary]=[]
var next_leg:=0
var stepping:=-1

func build(boss: Node3D, armor: Material, steel: Material, dark: Material) -> void:
	for index in range(4):
		var side: float=-1 if index<2 else 1
		var front: float=-1 if index%2==0 else 1
		var hip:=Vector3(side*2.9,-.3,front*1.7)
		var stance:=Vector3(side*4.2,0,front*2.8)
		var joints: Array[MeshInstance3D]=[]
		for joint in range(3):
			var ball:=MeshInstance3D.new();ball.mesh=SphereMesh.new();ball.scale=Vector3.ONE*.62;ball.material_override=steel;add_child(ball);joints.append(ball)
		var bones: Array[MeshInstance3D]=[]
		var hitboxes: Array[CollisionShape3D]=[]
		for bone in range(2):
			var rod:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=.19;cylinder.bottom_radius=.24;cylinder.radial_segments=16
			rod.mesh=cylinder;rod.material_override=armor;add_child(rod);bones.append(rod)
			KIT.bevel(rod,Vector3.ZERO,Vector3(.62,.9,.63),.08,armor)
			KIT.bevel(rod,Vector3(0,0,-.33),Vector3(.34,.66,.07),.025,dark)
			KIT.rod(rod,Vector3(.29,-.64,0),Vector3(.29,.62,0),.075,steel)
			var shape:=CapsuleShape3D.new();shape.radius=.45;shape.height=3.5
			COLLISION.add_shape(boss,shape,Vector3.ZERO)
			hitboxes.append(boss.get_child(boss.get_child_count()-1))
		var foot:=KIT.bevel(self,Vector3.ZERO,Vector3(1.2,.34,1.55),.12,dark)
		for tread in range(4): KIT.bevel(foot,Vector3(0,.18,-.5+tread*.33),Vector3(.95,.09,.13),.025,steel)
		var planted:=to_global(stance);planted.y=boss.WORLD.ROOF_HEIGHT+.24
		legs.append({"hip":hip,"stance":stance,"foot":foot,"joints":joints,"bones":bones,"hitboxes":hitboxes,"planted":planted,"from":planted,"to":planted,"progress":1.0})
	update_pose(boss,0)

func update_pose(boss: Node3D, delta: float) -> void:
	for i in range(legs.size()):
		var leg: Dictionary=legs[i]
		var desired:=to_global(leg.stance);desired.y=boss.WORLD.ROOF_HEIGHT+.24
		if stepping<0 and i==next_leg and leg.planted.distance_to(desired)>1.2:
			leg.from=leg.planted;leg.to=desired;leg.progress=0.0;stepping=i
		if stepping==i:
			leg.progress=minf(1.0,leg.progress+delta/.28)
			leg.planted=leg.from.lerp(leg.to,smoothstep(0,1,leg.progress))+Vector3.UP*sin(leg.progress*PI)*.65
			if leg.progress>=1:
				stepping=-1;next_leg=[3,2,0,1][i]
		var hip: Vector3=leg.hip
		var toe:=to_local(leg.planted)
		var knee: Vector3=(hip+toe)*.5+Vector3(signf(hip.x)*1.05,.35,signf(hip.z)*.35)
		var points: Array[Vector3]=[hip,knee,toe]
		leg.foot.position=toe
		for j in range(3): leg.joints[j].position=points[j]
		for j in range(2):
			var bone: MeshInstance3D=leg.bones[j]
			bone.position=(points[j]+points[j+1])*.5
			bone.basis=Basis(Quaternion(Vector3.UP,points[j].direction_to(points[j+1])))
			bone.mesh.height=points[j].distance_to(points[j+1])
			var hitbox: CollisionShape3D=leg.hitboxes[j]
			hitbox.position=boss.to_local(bone.global_position)
			hitbox.basis=boss.global_basis.inverse()*bone.global_basis.orthonormalized()
			hitbox.shape.height=maxf(.91,to_global(points[j]).distance_to(to_global(points[j+1])))
