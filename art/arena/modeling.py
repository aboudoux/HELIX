"""Petits outils de modélisation : coordonnées Godot, +Y vertical et mètres."""
import math
import bpy
import bmesh
from mathutils import Vector


def xyz(v):
    return Vector((v[0], -v[2], v[1]))


def material(name, rgb, metallic=0.0, roughness=.5, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*rgb, 1)
    shader = mat.node_tree.nodes.get("Principled BSDF")
    for key, value in {"Base Color": (*rgb, 1), "Metallic": metallic,
                       "Roughness": roughness, "Emission Color": (*rgb, 1),
                       "Emission Strength": emission}.items():
        shader.inputs[key].default_value = value
    return mat


def empty(name, parent=None, pos=(0, 0, 0), yaw=0):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = xyz(pos)
    obj.rotation_euler.z = yaw
    obj.empty_display_size = .3
    return obj


def finish(obj, name, mat, parent, bevel=0):
    obj.name = name
    obj.parent = parent
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Chanfreins", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        mod.harden_normals = True
        normal = obj.modifiers.new("Normales ponderees", "WEIGHTED_NORMAL")
        normal.keep_sharp = True
    return obj


def mesh(name, vertices, faces, mat, parent, bevel=0, recalc=False):
    data = bpy.data.meshes.new(name)
    data.from_pydata([xyz(v) for v in vertices], [], faces)
    data.update()
    if recalc:
        bm = bmesh.new()
        bm.from_mesh(data)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(data)
        bm.free()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat, parent, bevel)


def box(name, pos, size, mat, parent, bevel=.012):
    x,y,z = (v/2 for v in size)
    verts = [(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),
             (-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
    faces = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)]
    obj = mesh(name,verts,faces,mat,parent,bevel)
    obj.location = xyz(pos)
    return obj


def cylinder(name, pos, radius, depth, mat, parent, axis=(0,1,0), vertices=24, bevel=.004):
    data = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=vertices,
                         radius1=radius, radius2=radius, depth=depth)
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(obj)
    obj.location = xyz(pos)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0,0,1)).rotation_difference(xyz(axis).normalized())
    for face in data.polygons:
        face.use_smooth = len(face.vertices)==4
    return finish(obj,name,mat,parent,bevel)


def rod(name, a, b, radius, mat, parent, vertices=16):
    a,b = Vector(a),Vector(b)
    return cylinder(name,(a+b)/2,radius,(b-a).length,mat,parent,b-a,vertices,.002)


def arc(name, radius, inner, bottom, top, mat, parent, start=0, end=math.tau, segments=48):
    n = segments+1
    verts = [(r*math.cos(a), y, r*math.sin(a))
             for r,y in [(radius,bottom),(radius,top),(inner,top),(inner,bottom)]
             for a in [start+(end-start)*i/segments for i in range(n)]]
    faces=[]
    for k in range(4):
        for i in range(segments):
            faces.append((k*n+i,k*n+i+1,((k+1)%4)*n+i+1,((k+1)%4)*n+i))
    faces += [(0,n,2*n,3*n),(n-1,4*n-1,3*n-1,2*n-1)]
    obj=mesh(name,verts,faces,mat,parent,0,True)
    for face in obj.data.polygons:
        face.use_smooth=face.index//segments in (0,2)
    return obj


def lettering(name, value, pos, size, mat, parent, top=False):
    data=bpy.data.curves.new(name,"FONT")
    data.body=value
    data.size=size
    data.align_x="CENTER"
    data.align_y="CENTER"
    data.extrude=.0002
    data.resolution_u=5
    obj=bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(obj)
    obj.parent=parent
    obj.location=xyz(pos)
    if not top:
        obj.rotation_euler.x=math.pi/2
    data.materials.append(mat)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.convert(target="MESH")
    return bpy.context.object


def duplicate_tree(source, name, pos, parent=None):
    copy=source.copy()
    bpy.context.collection.objects.link(copy)
    copy.name=name
    copy.parent=parent
    copy.location=xyz(pos)
    def children(old,new):
        for obj in old.children:
            child=obj.copy()
            bpy.context.collection.objects.link(child)
            child.parent=new
            children(obj,child)
    children(source,copy)
    return copy
