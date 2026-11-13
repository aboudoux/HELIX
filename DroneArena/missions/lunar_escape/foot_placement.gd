extends RefCounted
## Foot contacts are retained in world space during stance, then lifted for swing.
var contacts: Dictionary = {}
var previous_origin := Vector3.INF

func sample(suit: Node3D, side: float, phase: float, speed: float, direction: Vector3) -> Dictionary:
	if previous_origin.is_finite() and previous_origin.distance_to(suit.global_position)>2.0: contacts.clear()
	previous_origin=suit.global_position
	var cycle:=fposmod(phase,TAU)/TAU
	# Running shortens ground contact instead of cycling the legs unnaturally fast.
	var contact_fraction:=lerpf(.43,.24,clampf(speed/5.0,0,1))
	var stance:=speed<.08 or cycle<contact_fraction
	var rest:=Vector3(side*.16,.09,0)
	var reach:=lerpf(.23,.36,clampf(speed/5.0,0,1))
	var ahead:=suit.to_global(rest+direction*reach)
	var hit:=suit.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ahead+Vector3.UP*.48,ahead-Vector3.UP*.65,1))
	var normal: Vector3=hit.get("normal",Vector3.UP)
	if hit.is_empty():
		contacts.erase(side)
		return {"position":rest+Vector3.UP*.07,"normal":Vector3.UP,"stance":false}
	ahead.y=hit.position.y+.085
	if not contacts.has(side): contacts[side]={"point":ahead,"start":ahead,"stance":stance,"normal":normal}
	var foot: Dictionary=contacts[side]
	# Also reset when turning on the spot or after a scripted reposition.
	if foot.point.distance_to(suit.to_global(rest))>.72:
		foot.point=ahead;foot.start=ahead
	if stance:
		if not foot.stance: foot.point=ahead;foot.normal=normal
	else:
		if foot.stance: foot.start=foot.point
		var u:=clampf((cycle-contact_fraction)/(1.0-contact_fraction),0,1)
		foot.point=foot.start.lerp(ahead,smoothstep(0,1,u))+Vector3.UP*sin(u*PI)*.14
		foot.normal=normal
	foot.stance=stance
	return {"position":suit.to_local(foot.point),"normal":(suit.global_basis.inverse()*foot.normal).normalized(),"stance":stance}
