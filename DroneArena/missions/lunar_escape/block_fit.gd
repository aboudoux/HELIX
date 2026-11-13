extends RefCounted
## Trim intersecting 30 cm sections; the visual mesh and collision share one mask.
const EDGE := 5
const CELL := .30
const HALF := .75
const TOTAL := EDGE*EDGE*EDGE

static func fit(space: PhysicsDirectSpaceState3D,point: Vector3,contact: Vector3,normal: Vector3) -> Array[int]:
	var result: Array[int]=[]
	var query:=PhysicsShapeQueryParameters3D.new();var shape:=BoxShape3D.new()
	shape.size=Vector3.ONE*1.496;query.shape=shape;query.collision_mask=1;query.transform=Transform3D(Basis.IDENTITY,point)
	if space.intersect_shape(query,1).is_empty():
		for i in range(TOTAL): result.append(i)
		return result
	shape.size=Vector3.ONE*(CELL-.004)
	for i in range(TOTAL):
		var center:=point+cell_center(i)
		# Do not grow a second disconnected half on the far side of a thin wall.
		if normal.dot(center-contact)<-.02: continue
		query.transform.origin=center
		if space.intersect_shape(query,1).is_empty(): result.append(i)
	return result

static func cell_center(id: int) -> Vector3:
	return Vector3(id%EDGE,(id/EDGE)%EDGE,id/(EDGE*EDGE))*CELL-Vector3.ONE*(HALF-CELL*.5)

static func mesh(cells: Array) -> ArrayMesh:
	var occupied: Dictionary={}
	for id in cells: occupied[int(id)]=true
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for id in cells:
		var index:=int(id);var center:=cell_center(index)
		var coordinate:=Vector3i(index%EDGE,(index/EDGE)%EDGE,index/(EDGE*EDGE))
		for normal in [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]:
			var next:=coordinate+Vector3i(normal)
			if next.x>=0 and next.x<EDGE and next.y>=0 and next.y<EDGE and next.z>=0 and next.z<EDGE and occupied.has(next.x+next.y*EDGE+next.z*EDGE*EDGE): continue
			var u:=Vector3.FORWARD if absf(normal.x)>.5 else Vector3.RIGHT
			var v: Vector3=normal.cross(u)
			for corner in [Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
				tool.set_normal(normal);tool.set_uv((corner+Vector2.ONE)*.5)
				tool.add_vertex(center+(normal+u*corner.x+v*corner.y)*CELL*.5)
	return tool.commit()

static func add_collision(body: StaticBody3D,cells: Array) -> void:
	var occupied: Dictionary={}
	for id in cells: occupied[int(id)]=true
	for z in range(EDGE):
		for y in range(EDGE):
			var x:=0
			while x<EDGE:
				if not occupied.has(x+y*EDGE+z*EDGE*EDGE): x+=1;continue
				var first:=x
				while x<EDGE and occupied.has(x+y*EDGE+z*EDGE*EDGE): x+=1
				var collider:=CollisionShape3D.new();var box:=BoxShape3D.new()
				box.size=Vector3((x-first)*CELL,CELL,CELL)
				collider.shape=box;collider.position=(cell_center(first+y*EDGE+z*EDGE*EDGE)+cell_center(x-1+y*EDGE+z*EDGE*EDGE))*.5
				body.add_child(collider)

static func valid_cells(cells: Variant) -> bool:
	if not cells is Array or cells.is_empty() or cells.size()>TOTAL: return false
	var seen: Dictionary={}
	for id in cells:
		if (not id is int and not id is float) or id!=floorf(id) or id<0 or id>=TOTAL or seen.has(int(id)): return false
		seen[int(id)]=true
	return true
