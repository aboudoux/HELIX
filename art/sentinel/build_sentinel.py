"""Modèle original HELIX S-07. Exécuter avec Blender --background --python.
Les coordonnées de conception sont celles de Godot : Y en haut, avant -Z.
Le GLB ne contient que le modèle, les matériaux et les pivots des hélices.
"""
from pathlib import Path
import json
import math
import sys

import bpy
from mathutils import Vector

WORKSPACE = Path(__file__).resolve().parents[2]
ART = Path(__file__).resolve().parent
MODEL = WORKSPACE / "DroneArena/assets/models/helix_sentinel.glb"
RENDER = "--skip-render" not in sys.argv


def xyz(v):
    return (v[0], -v[2], v[1])


def material(name, rgb, metallic=0.0, roughness=0.4, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*rgb, 1)
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Emission Color"].default_value = (*rgb, 1)
    shader.inputs["Emission Strength"].default_value = emission
    return mat


def empty(name, pos=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = xyz(pos)
    obj.parent = parent
    obj.empty_display_size = 0.12
    return obj


def finish(obj, name, mat, parent, bevel=0.0):
    obj.name = name
    obj.parent = parent
    obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("Chanfreins", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        modifier.limit_method = "ANGLE"
        modifier.harden_normals = True
        normal = obj.modifiers.new("Normales pondérées", "WEIGHTED_NORMAL")
        normal.keep_sharp = True
        normal.weight = 40
    return obj


def box(name, pos, size, mat, parent, bevel=0.008):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz(pos))
    obj = bpy.context.object
    obj.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, parent, bevel)


def cylinder(name, pos, radius, depth, mat, parent, axis=(0, 1, 0), vertices=32, bevel=0.003):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=xyz(pos))
    obj = bpy.context.object
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(xyz(axis)).normalized())
    for polygon in obj.data.polygons:
        polygon.use_smooth = len(polygon.vertices) == 4
    return finish(obj, name, mat, parent, bevel)


def sphere(name, pos, scale, mat, parent):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1, location=xyz(pos))
    obj = bpy.context.object
    obj.scale = (scale[0], scale[2], scale[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for face in obj.data.polygons:
        face.use_smooth = True
    return finish(obj, name, mat, parent)


def mesh(name, vertices, faces, mat, parent, bevel=0.0):
    data = bpy.data.meshes.new(name)
    data.from_pydata([xyz(v) for v in vertices], [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat, parent, bevel)


def plate(name, outline, bottom, top, mat, parent, bevel=0.01):
    n = len(outline)
    vertices = [(x, y, z) for y in (bottom, top) for x, z in outline]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, n * 2))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    obj = mesh(name, vertices, faces, mat, parent, bevel)
    # Le contour est donné vu du dessus ; recalculer garantit des faces extérieures.
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def rod(name, start, end, radius, mat, parent, vertices=12):
    a, b = Vector(start), Vector(end)
    return cylinder(name, (a + b) / 2, radius, (b - a).length, mat, parent, (b - a), vertices, 0.001)


def wire(name, points, radius, mat, parent):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for point, position in zip(spline.bezier_points, points):
        point.co = xyz(position)
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    curve.materials.append(mat)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    return bpy.context.object


def ring(name, profile, mat, parent, segments=48):
    # Profil radial : (rayon, hauteur). L'axe de l'anneau est Y dans Godot.
    n = len(profile)
    vertices = [(r * math.cos(a * math.tau / segments), y, r * math.sin(a * math.tau / segments)) for a in range(segments) for r, y in profile]
    faces = []
    for a in range(segments):
        for j in range(n):
            faces.append((a * n + j, ((a + 1) % segments) * n + j, ((a + 1) % segments) * n + (j + 1) % n, a * n + (j + 1) % n))
    obj = mesh(name, vertices, faces, mat, parent)
    for face in obj.data.polygons:
        face.use_smooth = True
    return obj


def lettering(name, text, pos, size, mat, parent, front=False):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = text
    curve.size = size
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.extrude = 0.0004
    curve.bevel_depth = 0.0001
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = xyz(pos)
    if front:
        obj.rotation_euler = (math.pi / 2, 0, math.pi)
    else:
        obj.rotation_euler.z = math.pi
    curve.materials.append(mat)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    return bpy.context.object


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for old in list(bpy.data.materials):
    bpy.data.materials.remove(old)

armor = material("HX_Ceramique_Ivoire", (0.66, 0.70, 0.63), 0.28, 0.38)
dark = material("HX_Chassis_Graphite", (0.035, 0.055, 0.068), 0.72, 0.40)
metal = material("HX_Aluminium_Brosse", (0.32, 0.39, 0.42), 0.83, 0.32)
rubber = material("HX_Caoutchouc", (0.012, 0.018, 0.022), 0.05, 0.86)
orange = material("HX_Orange_Industriel", (0.92, 0.22, 0.035), 0.30, 0.42)
red = material("HX_Optique_Rouge", (1.0, 0.018, 0.005), 0.12, 0.18, 3.0)
lens = material("HX_Verre_Optique", (0.08, 0.003, 0.004), 0.50, 0.10)
amber = material("HX_Balisage_Ambre", (1.0, 0.28, 0.015), 0.10, 0.30, 1.5)
white = material("HX_Marquage", (0.86, 0.89, 0.83), 0.10, 0.60)
copper = material("HX_Cuivre", (0.48, 0.19, 0.07), 0.75, 0.35)

root = empty("SentinelModel")
root["asset"] = "HELIX S-07"
root["forward"] = "-Z in glTF / Godot"
root["role"] = "visual_only"
body = empty("Chassis", parent=root)
rotors = empty("Rotors", parent=root)

outline = [(-.27,-.37),(.27,-.37),(.405,-.22),(.405,.22),(.25,.37),(-.25,.37),(-.405,.22),(-.405,-.22)]
plate("CoqueInferieure", outline, -.17, .12, dark, body, .025)
top_outline = [(x * .93, z * .91) for x,z in outline]
plate("BlindageSuperieur", top_outline, .13, .19, armor, body, .018)
plate("ModuleBatterie", [(-.20,-.16),(.20,-.16),(.22,.21),(.15,.28),(-.15,.28),(-.22,.21)], -.245, -.17, metal, body, .015)
box("BatterieJoint", (0,-.248,.05), (.30,.018,.29), rubber, body, .004)
box("ModuleCentral", (0,.214,.07), (.18,.052,.26), dark, body, .012)
box("ArceauCentral", (0,.245,.08), (.075,.023,.17), metal, body, .006)
lettering("LogoHELIX", "H E L I X", (0,.193,-.18), .043, dark, body)
lettering("Serie", "S - 0 7", (0,.194,.245), .030, dark, body)

for sign in [-1, 1]:
    shoulder = [(sign*.24,-.31),(sign*.35,-.23),(sign*.35,.20),(sign*.23,.28)]
    plate(f'PlaqueLaterale{sign}', shoulder, .10, .145, orange, body, .008)
    for i in range(6):
        box(f'Ouie_{sign}_{i}', (sign*.405,.006,-.145+i*.051), (.018,.078,.025), rubber, body, .003)
        box(f'Ailette_{sign}_{i}', (sign*.416,-.05,-.145+i*.051), (.022,.015,.032), metal, body, .002)
    for z in [-.24,.23]:
        cylinder(f'VisBlindage_{sign}_{z}', (sign*.31,.195,z), .014,.008,metal,body,vertices=6,bevel=.001)
        box(f'FenteVis_{sign}_{z}', (sign*.31,.2,z), (.016,.002,.003), rubber,body,.0)
    for i in range(3):
        box(f'RepereAvant_{sign}_{i}', (sign*(.22+i*.025),.193,-.26), (.012,.003,.046), dark,body,.0)
    sphere(f'CapteurLaterale{sign}', (sign*.375,.07,-.24), (.018,.024,.032), amber,body)

# Capteur optique protégé et canon : la sortie correspond au Marker3D existant.
cylinder("SupportOptique", (0,.025,-.37), .152,.09,dark,body,(0,0,-1),48,.008)
cylinder("BagueOptique", (0,.025,-.421), .137,.025,metal,body,(0,0,-1),48,.004)
cylinder("JointOptique", (0,.025,-.441), .113,.018,rubber,body,(0,0,-1),48,.002)
sphere("Lentille", (0,.025,-.457), (.109,.109,.035),lens,body)
cylinder("IrisLumineux", (0,.025,-.49), .055,.009,red,body,(0,0,-1),32,.001)
cylinder("CentreOptique", (0,.025,-.496), .024,.003,white,body,(0,0,-1),24,.0)
for sign in [-1,1]:
    box(f'JoueOptique{sign}', (sign*.155,.015,-.38), (.042,.13,.12),armor,body,.01)
    rod(f'ArceauOptique{sign}', (sign*.12,.14,-.39), (sign*.12,-.06,-.43), .009,metal,body)
box("BerceauCanon", (0,-.13,-.325), (.17,.11,.19),metal,body,.015)
cylinder("TubeCanon", (0,-.11,-.47), .047,.24,dark,body,(0,0,-1),32,.004)
for z in [-.39,-.44,-.49]:
    cylinder(f'CanonBague_{z}', (0,-.11,z), .057,.018,metal,body,(0,0,-1),32,.002)
cylinder("FreinBouche", (0,-.11,-.59), .064,.06,dark,body,(0,0,-1),8,.004)
cylinder("InterieurCanon", (0,-.11,-.622), .037,.005,rubber,body,(0,0,-1),32,.0)
cylinder("EnergieCanon", (0,-.11,-.626), .019,.003,red,body,(0,0,-1),24,.0)
lettering("MarquageAvant", "07", (.245,.025,-.385), .065,white,body,front=True)

# Pieds, arrière de refroidissement et connectique.
for x in [-.24,.24]:
    for z in [-.18,.20]:
        rod(f'Pied_{x}_{z}', (x,-.16,z), (x*1.12,-.29,z), .014,metal,body)
        box(f'Patin_{x}_{z}', (x*1.12,-.304,z), (.09,.03,.075),rubber,body,.009)
for i in range(5):
    box(f'GrilleArriere_{i}', (-.12+i*.06,-.02,.374), (.035,.11,.018),metal,body,.003)
cylinder("ConnecteurArriere", (0,-.13,.376), .035,.02,copper,body,(0,0,1),16,.002)

for index,(x,z) in enumerate([(-.62,-.43),(.62,-.43),(-.62,.43),(.62,.43)]):
    rotor = empty(f'Rotor{index}', (x,.02,z),rotors)
    sx,sz = (-1 if x<0 else 1),(-1 if z<0 else 1)
    start = (sx*.30,-.015,sz*.22)
    end = (x,-.015,z)
    rod(f'BrasStructure{index}', start, end,.055,dark,body,8)
    rod(f'BrasRenfort{index}', (start[0],.04,start[2]), (x,.04,z),.026,metal,body,8)
    wire(f'CableAlimentation{index}', [(sx*.30,.09,sz*.20),(sx*.43,.11,sz*.29),(x,.085,z)], .008,orange,body)
    ring("CarterTurbine", [(.266,-.048),(.280,-.025),(.280,.026),(.267,.056),(.231,.056),(.217,.032),(.217,-.032),(.232,-.048)],dark,rotor)
    ring("BlindageTurbine", [(.267,.034),(.277,.03),(.277,.044),(.267,.063),(.235,.063),(.228,.05),(.235,.034)],armor,rotor)
    ring("LiseretInferieur", [(.270,-.04),(.275,-.025),(.275,-.013),(.269,-.02)],orange,rotor)
    cylinder("Moteur", (0,-.028,0),.056,.10,metal,rotor,vertices=24)
    for j in range(4):
        a=j*math.pi/2
        rod(f'SupportMoteur{j}', (.05*math.cos(a),-.037,.05*math.sin(a)), (.222*math.cos(a),-.037,.222*math.sin(a)), .009,metal,rotor,8)
    for j in range(8):
        a=j*math.pi/4
        cylinder(f'Rivet{j}', (.251*math.cos(a),.067,.251*math.sin(a)),.007,.006,metal,rotor,vertices=6,bevel=.0)
    blades=empty(f"Blades{index}",parent=rotor)
    for j in range(3):
        angle=j*math.tau/3
        vertices=[]
        for side in [-1,1]:
            for step in range(8):
                t=step/7
                radius=.047+t*.158
                sweep=angle+.3*t
                width=(.012+.018*math.sin(t*math.pi*.82))*side
                xx=radius*math.cos(sweep)-width*math.sin(sweep)
                zz=radius*math.sin(sweep)+width*math.cos(sweep)
                yy=.015+width*.32
                vertices.append((xx,yy,zz))
        faces=[(i,i+1,9+i,8+i) for i in range(7)]
        blade=mesh(f'Pale{j}',vertices,faces,metal,blades)
        solid=blade.modifiers.new("Epaisseur", "SOLIDIFY")
        solid.thickness=.004
        bevel=blade.modifiers.new("BordArrondi","BEVEL")
        bevel.width=.002
        bevel.segments=2
    cylinder("EcrouRotor", (0,.037,0),.044,.035,orange,blades,vertices=12)
    cylinder("AxeRotor", (0,.058,0),.018,.008,metal,blades,vertices=12,bevel=.001)
    sphere("FeuPosition", (sx*.267,.02,0), (.012,.017,.038),amber,rotor)

# Appliquer les modificateurs seulement aux maillages : le GLB est autonome.
asset_objects=[root,*root.children_recursive]
for obj in asset_objects:
    if obj.type=='MESH':
        bpy.context.view_layer.objects.active=obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

# Grouper les pièces statiques par matériau réduit le nombre de draw calls.
# Les pivots Rotor0..3 et Blades sont conservés pour l'animation en jeu.
parents=[body]+[obj for obj in rotors.children_recursive if obj.type=='EMPTY']
for parent in parents:
    groups={}
    for child in list(parent.children):
        if child.type=='MESH':
            groups.setdefault(child.data.materials[0].name,[]).append(child)
    for mat_name,objects in groups.items():
        if len(objects)<2:
            continue
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join()
        objects[0].name=parent.name+'_'+mat_name

asset_objects=[root,*root.children_recursive]
bpy.ops.object.select_all(action='DESELECT')
for obj in asset_objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.context.view_layer.update()
MODEL.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(MODEL),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_materials='EXPORT',export_extras=True)

triangles=0
coords=[]
for obj in asset_objects:
    if obj.type=='MESH':
        obj.data.calc_loop_triangles()
        triangles+=len(obj.data.loop_triangles)
        coords.extend(obj.matrix_world@vertex.co for vertex in obj.data.vertices)
bounds_b=[list(map(min,zip(*coords))),list(map(max,zip(*coords)))]
manifest={'name':'HELIX S-07','blender':bpy.app.version_string,'triangles':triangles,'meshes':sum(o.type=='MESH' for o in asset_objects),'materials':len(bpy.data.materials),'bounds_blender':bounds_b,'game_forward':'-Z','rotors':[f'Rotors/Rotor{i}/Blades{i}' for i in range(4)],'glb':str(MODEL.relative_to(WORKSPACE))}
(ART/'asset-info.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')

# Studio enregistré dans le .blend mais exclu de l'export du modèle.
studio=bpy.data.collections.new('Studio_Preview_Not_Exported')
bpy.context.scene.collection.children.link(studio)

def studio_object(obj):
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    studio.objects.link(obj)
    return obj

floor_mat=material('Studio_Slate',(.025,.042,.058),.12,.45)
bpy.ops.mesh.primitive_plane_add(size=200,location=xyz((0,-.34,0)))
floor=bpy.context.object
floor.name='Studio_Ground'
floor.data.materials.append(floor_mat)
studio_object(floor)

def light(name,pos,energy,colour,size):
    data=bpy.data.lights.new(name,'AREA')
    data.energy=energy
    data.color=colour
    data.shape='DISK'
    data.size=size
    obj=bpy.data.objects.new(name,data)
    studio.objects.link(obj)
    obj.location=xyz(pos)
    obj.rotation_euler=(Vector(xyz((0,0,0)))-obj.location).to_track_quat('-Z','Y').to_euler()

light('Key',(1.0,3.2,-2),330,(1,.88,.74),3)
light('Fill',(-2.5,1.4,-.5),220,(.55,.78,1),2.5)
light('Rim',(1.5,2.0,2),450,(.40,.80,1),2)
camera_data=bpy.data.cameras.new('Camera_Asset')
camera=bpy.data.objects.new('Camera_Asset',camera_data)
studio.objects.link(camera)
camera.location=xyz((2.8,2.1,-3.2))
camera.rotation_euler=(Vector(xyz((0,.02,0)))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO'
camera_data.ortho_scale=2.6
scene=bpy.context.scene
scene.camera=camera
scene.render.engine='CYCLES'
scene.cycles.samples=48
scene.cycles.use_denoising=True
scene.render.resolution_x=1400
scene.render.resolution_y=1000
scene.render.resolution_percentage=100
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.04,.065,.09,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(ART/'preview.png')
bpy.ops.object.select_all(action='DESELECT')
root.select_set(True)
bpy.context.view_layer.objects.active=root
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_distance=2.8
        area.spaces.active.region_3d.view_location=(0,0,0)
        area.spaces.active.region_3d.view_perspective='CAMERA'
        area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'helix_sentinel.blend'))
if RENDER:
    bpy.ops.render.render(write_still=True)
print('HELIX_ASSET',json.dumps(manifest))
