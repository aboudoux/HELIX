extends RefCounted
const COLLISION := preload("res://scripts/actor_collision.gd")

static func build(rocket: Node3D) -> void:
	var body:=StaticBody3D.new();body.name="CoqueSolide";rocket.add_child(body)
	var hull:=CylinderShape3D.new();hull.radius=2.09;hull.height=9
	COLLISION.add_shape(body,hull,Vector3(0,6.5,0))
	var nose:=ConvexPolygonShape3D.new();var points:=PackedVector3Array()
	for row in range(5):
		var t:=float(row)/4
		for j in range(24):
			var angle:=TAU*j/24
			points.append(Vector3(cos(angle)*lerpf(2.03,.18,t),11+t*3.6,sin(angle)*lerpf(2.03,.18,t)))
	nose.points=points;COLLISION.add_shape(body,nose,Vector3.ZERO)
	var engine:=CylinderShape3D.new();engine.radius=1.51;engine.height=2.2
	COLLISION.add_shape(body,engine,Vector3(0,1.1,0))
	for x in [-3.1,3.1]:
		COLLISION.add_box(body,Vector3(.32,3.0,.66),Vector3(x,1.4,-.15)).rotation.z=signf(x)*.39
		COLLISION.add_box(body,Vector3(1.1,.3,.83),Vector3(x*1.13,.15,-.15))
