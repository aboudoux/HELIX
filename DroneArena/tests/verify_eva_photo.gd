extends "res://tests/verify.gd"
const SUIT := preload("res://missions/lunar_escape/escort_suit.gd")
const FINISH := preload("res://missions/lunar_escape/eva_photo_finish.gd")
const ASTRONAUT := preload("res://missions/lunar_escape/astronaut.gd")
const GLOVES := preload("res://missions/lunar_escape/view_gloves.gd")

func run() -> void:
	var suit:=SUIT.new()
	root.add_child(suit);suit.build()
	var photo: Image=FINISH.PHOTO.get_image()
	check(photo.get_size()==Vector2i(1024,1536),"La photographie originale est utilisée en pleine définition")
	var pack: MeshInstance3D=suit.torso.get_node("EVAControlPack")
	check(pack.material_override.get_shader_parameter("photograph")==FINISH.PHOTO,"Le plastron utilise directement la photo fournie")
	for limb in suit.limbs:
		for segment in [limb.upper,limb.lower]:
			var mesh: MeshInstance3D=segment.get_child(0)
			check(mesh.material_override.get_shader_parameter("photograph")==FINISH.PHOTO,"Le membre articulé conserve la texture photographique")
			var arrays:=mesh.mesh.surface_get_arrays(0)
			var outward:=true
			for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
				var v: Vector3=arrays[Mesh.ARRAY_VERTEX][i]
				var n: Vector3=arrays[Mesh.ARRAY_NORMAL][i]
				if Vector3(v.x,0,v.z).dot(n)<0: outward=false
			check(outward,"Les normales des plis sont orientées vers l'extérieur")
	var arm: Dictionary=suit.limbs[0]
	suit.solve(arm,Vector3(.3,1.4,0),Vector3(.3,1.7,-.25),Vector3.RIGHT)
	check(arm.lower.get_child(0).get_parent()==arm.lower and arm.lower.basis!=Basis.IDENTITY,"La texture et la géométrie suivent les articulations")
	var pilot:=ASTRONAUT.new()
	root.add_child(pilot);pilot.build();FINISH.dress_pilot(pilot)
	check(pilot.torso.get_child(0).material_override.get_shader_parameter("photograph")==FINISH.PHOTO,"Le pilote porte le même textile photographique")
	for left in [false,true]:
		var hand:=Node3D.new();pilot.add_child(hand);GLOVES.build(hand,left)
		var glove: ShaderMaterial=hand.get_child(0).material_override
		var sleeve: ShaderMaterial=hand.get_meta("sleeve").material_override
		check(glove.get_shader_parameter("eva_photo")==FINISH.PHOTO and sleeve.get_shader_parameter("eva_photo")==FINISH.PHOTO,"La main et la manche de chaque côté utilisent la photo en première personne")
		check(glove.get_shader_parameter("photo_origin")==FINISH.PHOTO_MATERIALS.EVA_GLOVE[0] and sleeve.get_shader_parameter("photo_origin")==FINISH.PHOTO_MATERIALS.EVA_FOREARM[0],"Les gants et les manches reprennent les zones correspondantes")
	pilot.queue_free();suit.queue_free();await frames(2)
	print("%d vérifications, %d échec(s)"%[checks,failures])
	quit(1 if failures else 0)
