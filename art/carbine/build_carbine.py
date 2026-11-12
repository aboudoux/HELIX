"""HELIX H-01 : carabine originale pour le prototype DroneArena.
Blender 4.5 LTS --background --factory-startup --python-exit-code 1 --python ...
Conception en coordonnées Godot : +Y vertical, canon dirigé vers -Z, mètres.
La source garde les pièces éditables ; les copies exportées sont regroupées.
"""
from pathlib import Path
import json
import math
import sys

import bpy
import bmesh
from mathutils import Vector, Matrix

ART = Path(__file__).resolve().parent
WORKSPACE = ART.parents[1]
MODEL = WORKSPACE / "DroneArena/assets/models/helix_carbine.glb"
RENDER = "--skip-render" not in sys.argv


def xyz(v):
    return Vector((v[0], -v[2], v[1]))


def material(name, rgb, metallic=0.0, roughness=0.4, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*rgb, 1)
    shader = mat.node_tree.nodes.get("Principled BSDF")
    for key, value in {"Base Color": (*rgb, 1), "Metallic": metallic,
                       "Roughness": roughness, "Emission Color": (*rgb, 1),
                       "Emission Strength": emission}.items():
        shader.inputs[key].default_value = value
    return mat


def empty(name, parent=None, pos=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = xyz(pos)
    obj.empty_display_size = .025
    return obj


def finish(obj, name, mat, parent, bevel=0.0):
    obj.name = name
    obj.parent = parent
    obj.data.materials.append(mat)
    if bevel:
        edge = obj.modifiers.new("Chanfreins", "BEVEL")
        edge.width = bevel
        edge.segments = 3
        edge.limit_method = "ANGLE"
        edge.harden_normals = True
        normal = obj.modifiers.new("Normales pondérées", "WEIGHTED_NORMAL")
        normal.keep_sharp = True
    return obj


def box(name, pos, size, mat, parent, bevel=.003):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz(pos))
    obj = bpy.context.object
    obj.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, parent, bevel)


def cylinder(name, pos, radius, depth, mat, parent, axis=(0, 0, -1), vertices=32, bevel=.001):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=xyz(pos))
    obj = bpy.context.object
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(xyz(axis).normalized())
    for polygon in obj.data.polygons:
        polygon.use_smooth = len(polygon.vertices) == 4
    return finish(obj, name, mat, parent, bevel)


def rod(name, start, end, radius, mat, parent, vertices=16):
    a, b = Vector(start), Vector(end)
    return cylinder(name, (a+b)/2, radius, (b-a).length, mat, parent, b-a, vertices)


def ellipsoid(name, pos, size, mat, parent):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=1, location=xyz(pos))
    obj = bpy.context.object
    obj.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return finish(obj, name, mat, parent)


def mesh(name, vertices, faces, mat, parent, bevel=.001):
    data = bpy.data.meshes.new(name)
    data.from_pydata([xyz(v) for v in vertices], [], faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat, parent, bevel)


def profile(name, outline, x0, x1, mat, parent, bevel=.003):
    # Extrusion d'une silhouette (Z, Y) sur la largeur X de l'arme.
    n = len(outline)
    vertices = [(x,y,z) for x in (x0,x1) for z,y in outline]
    faces = [tuple(range(n-1,-1,-1)), tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name, vertices, faces, mat, parent, bevel)


def tube(name, z0, z1, outer, inner, mat, parent, y=.025, segments=48):
    vertices = []
    for z,r in [(z0,outer),(z1,outer),(z1,inner),(z0,inner)]:
        vertices += [(r*math.cos(a*math.tau/segments),y+r*math.sin(a*math.tau/segments),z) for a in range(segments)]
    faces=[]
    for layer in range(4):
        for i in range(segments):
            faces.append((layer*segments+i,layer*segments+(i+1)%segments,((layer+1)%4)*segments+(i+1)%segments,((layer+1)%4)*segments+i))
    obj=mesh(name,vertices,faces,mat,parent,.0006)
    for face in obj.data.polygons:
        face.use_smooth = face.index//segments in (0,2)
    return obj


def wire(name, points, radius, mat, parent):
    curve=bpy.data.curves.new(name,"CURVE")
    curve.dimensions="3D"
    curve.bevel_depth=radius
    curve.bevel_resolution=2
    curve.resolution_u=12
    spline=curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points)-1)
    for point,pos in zip(spline.bezier_points,points):
        point.co=xyz(pos)
        point.handle_left_type="AUTO"
        point.handle_right_type="AUTO"
    obj=bpy.data.objects.new(name,curve)
    bpy.context.collection.objects.link(obj)
    obj.parent=parent
    curve.materials.append(mat)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.convert(target="MESH")
    return bpy.context.object


def text(name, value, pos, size, mat, parent, side="left"):
    curve=bpy.data.curves.new(name,"FONT")
    curve.body=value
    curve.size=size
    curve.align_x="CENTER"
    curve.align_y="CENTER"
    curve.extrude=.00008
    obj=bpy.data.objects.new(name,curve)
    bpy.context.collection.objects.link(obj)
    obj.parent=parent
    obj.location=xyz(pos)
    # Ligne de texte de l'avant vers l'arrière, lisible côté gauche et en FPS.
    right=xyz((0,0,1)) if side=="left" else xyz((0,0,-1))
    up=xyz((0,1,0))
    normal=right.cross(up)
    obj.rotation_euler=Matrix((right,up,normal)).transposed().to_euler()
    curve.materials.append(mat)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.convert(target="MESH")
    return bpy.context.object


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for mat in list(bpy.data.materials):
    bpy.data.materials.remove(mat)
bpy.context.preferences.filepaths.save_version=0

armor=material("H01_Ceramique_Ivoire",(.67,.71,.65),.26,.34)
dark=material("H01_Titane_Graphite",(.028,.044,.054),.78,.33)
metal=material("H01_Aluminium",(.29,.37,.41),.88,.27)
rubber=material("H01_Polymere",(.012,.019,.024),.02,.78)
orange=material("H01_Orange",(.93,.20,.027),.32,.35)
cyan=material("H01_Plasma_Cyan",(.015,.70,.85),.16,.24,2.2)
glass=material("H01_Cellule_Sombre",(.008,.072,.088),.65,.19)
copper=material("H01_Cuivre",(.48,.20,.072),.83,.29)
fabric=material("H01_Tissu_Nuit",(.023,.040,.056),.0,.95)

root=empty("CarbineModel")
root["asset"]="HELIX H-01 / CARABINE A IMPULSION"
root["role"]="visual_only"
root["forward"]="-Z in Godot"
receiver=empty("Receiver",root)
barrel=empty("Barrel",root)
power=empty("PowerCell",root)
stock=empty("StockGrip",root)
sight=empty("Sight",root)
hands=empty("Hands",root)
socket=empty("MuzzleReference",root,(0,.025,-.555))

# Boîtier anguleux, joint de coque et panneaux en céramique démontables.
profile("ChassisInterne",[(-.25,-.06),(-.25,.064),(-.17,.10),(.17,.10),(.22,.052),(.22,-.055),(.08,-.088),(-.14,-.088)],-.082,.082,dark,receiver,.009)
profile("CapotSuperieur",[(-.205,.078),(-.18,.112),(.155,.112),(.192,.082),(.155,.068),(-.18,.068)],-.091,.091,armor,receiver,.004)
panel=[(-.205,-.047),(-.205,.055),(-.16,.077),(.145,.077),(.176,.045),(.153,-.049),(-.10,-.067)]
for side in [-1,1]:
    profile(f"JointCoque_{side}",panel,side*.084,side*.096,rubber,receiver,.003)
    profile(f"FlancCeramique_{side}",panel,side*.096,side*.105,armor,receiver,.003)
    # Fenêtre du condensateur sur l'avant du boîtier.
    box(f"CadreCellule_{side}",(side*.109,.009,-.125),(.010,.049,.097),dark,receiver,.004)
    box(f"VerreCellule_{side}",(side*.115,.009,-.125),(.003,.032,.079),glass,receiver,.002)
    for j in range(4):
        box(f"IndicateurCharge_{side}_{j}",(side*.117,.009,-.152+j*.018),(.002,.021,.006),cyan,receiver,.0008)
    profile(f"BandeOrange_{side}",[(-.06,.045),(-.045,.062),(.142,.062),(.154,.045)],side*.106,side*.108,orange,receiver,.0006)
    for y,z in [(.058,-.182),(-.036,-.178),(.053,.151),(-.032,.139)]:
        cylinder(f"VisTorx_{side}_{y}_{z}",(side*.109,y,z),.0053,.006,metal,receiver,(side,0,0),6,.0004)
        box(f"FenteVis_{side}_{y}_{z}",(side*.113,y,z),(.001,.0014,.005),rubber,receiver,.0002)
    text(f"Marque_{side}","H E L I X",(side*.110,.020,.050),.021,dark,receiver,"left" if side<0 else "right")
    text(f"Modele_{side}","H-01  /  PULSE SYSTEM",(side*.110,-.008,.051),.009,dark,receiver,"left" if side<0 else "right")
    text(f"Serie_{side}","SN  07-001   //   5 Hz",(side*.110,-.036,.053),.0065,dark,receiver,"left" if side<0 else "right")
    box(f"SelecteurBase_{side}",(side*.112,-.038,.112),(.012,.018,.024),dark,receiver,.003)
    cylinder(f"PivotSelecteur_{side}",(side*.121,-.038,.112),.006,.005,metal,receiver,(side,0,0),16,.0004)
    rod(f"Selecteur_{side}",(side*.125,-.038,.112),(side*.125,-.025,.092),.003,orange,receiver,8)

# Canon réellement ouvert : bagues, bobines et garde-main ventilé.
tube("AmeCanon",-.23,-.526,.031,.019,metal,barrel)
tube("ChambreAvant",-.224,-.31,.048,.033,dark,barrel)
for j in range(7):
    z=-.258-j*.021
    tube(f"BobineCuivre_{j}",z-.004,z+.004,.043,.034,copper,barrel)
for j in range(3):
    z=-.283-j*.049
    tube(f"AnneauEnergie_{j}",z-.0017,z+.0017,.044,.041,cyan,barrel)
for side in [-1,1]:
    profile(f"CarterAvant_{side}",[(-.252,-.040),(-.25,.069),(-.414,.069),(-.444,.034),(-.43,-.038)],side*.054,side*.070,armor,barrel,.004)
    box(f"InsertRefroidissement_{side}",(side*.072,.024,-.344),(.006,.051,.126),rubber,barrel,.003)
    for j in range(6):
        z=-.291-j*.020
        fin=box(f"Ailette_{side}_{j}",(side*.078,.024,z),(.011,.042,.007),metal,barrel,.001)
        fin.rotation_euler.x=.18
    box(f"LiseretCanon_{side}",(side*.073,.058,-.337),(.005,.007,.145),orange,barrel,.001)
    for z in [-.26,-.416]:
        cylinder(f"VisCanon_{side}_{z}",(side*.074,-.026,z),.0048,.005,dark,barrel,(side,0,0),6,.0004)
box("GardeMainInferieur",(0,-.049,-.311),(.106,.035,.187),dark,barrel,.004)
for j in range(8):
    box(f"StrieGardeMain_{j}",(0,-.069,-.238-j*.022),(.105,.009,.008),rubber,barrel,.002)
tube("CollierAvant",-.429,-.454,.052,.032,dark,barrel,segments=12)
tube("CollierMetal",-.447,-.465,.046,.032,metal,barrel)
tube("FreinDeBouche",-.481,-.550,.046,.024,dark,barrel,segments=12)
tube("BordDeBouche",-.540,-.550,.047,.024,metal,barrel,segments=48)
tube("AnneauDeSortie",-.540,-.546,.024,.020,cyan,barrel)
cylinder("FondSombreDuCanon",(0,.025,-.495),.019,.001,rubber,barrel,vertices=32,bevel=0)
cylinder("CoeurPlasma",(0,.025,-.497),.009,.001,cyan,barrel,vertices=24,bevel=0)
for a in range(4):
    angle=a*math.pi/2
    x,y=.045*math.cos(angle),.025+.045*math.sin(angle)
    rod(f"EventBouche_{a}",(x,y,-.485),(x,y,-.525),.004,rubber,barrel,8)

# Batterie, connecteurs, loquet et câblage protégé.
profile("PuitsBatterie",[(-.13,-.078),(-.105,-.205),(-.015,-.205),(.002,-.078)],-.061,.061,dark,power,.004)
profile("BatterieCeramique",[(-.108,-.12),(-.094,-.224),(-.020,-.224),(-.012,-.12)],-.064,.064,armor,power,.004)
box("TalonBatterie",(0,-.228,-.058),(.142,.021,.114),rubber,power,.004)
for side in [-1,1]:
    box(f"RailBatterie_{side}",(side*.066,-.166,-.058),(.005,.079,.017),dark,power,.002)
    box(f"TemoinBatterie_{side}",(side*.070,-.166,-.058),(.002,.055,.006),cyan,power,.0005)
    cylinder(f"ConnecteurEnergie_{side}",(side*.097,-.067,-.183),.015,.018,metal,power,(side,0,0),24)
    wire(f"CableOrange_{side}",[(side*.11,-.068,-.183),(side*.123,-.092,-.20),(side*.077,-.048,-.283)],.004,orange,power)
    cylinder(f"ConnecteurAvant_{side}",(side*.077,-.048,-.283),.009,.018,metal,power,(side,0,0),16)
box("LoquetBatterie",(-.079,-.096,-.006),(.017,.021,.025),orange,power,.003)

# Poignée inclinée, pontet ouvert, détente, crosse allégée.
profile("Poignee",[(.055,-.067),(.123,-.067),(.180,-.251),(.108,-.251)],-.042,.042,rubber,stock,.008)
for side in [-1,1]:
    profile(f"PlaquettePoignee_{side}",[(.073,-.10),(.117,-.10),(.156,-.227),(.117,-.231)],side*.041,side*.046,dark,stock,.002)
    for j in range(6):
        y=-.12-j*.018
        box(f"StriePoignee_{side}_{j}",(side*.047,y,.112+(-y-.12)*.25),(.003,.005,.046),rubber,stock,.001)
wire("Pontet",[(0,-.075,.065),(0,-.135,.052),(0,-.151,-.011),(0,-.12,-.036),(0,-.079,-.036)],.008,metal,stock)
wire("Detente",[(0,-.075,.036),(0,-.108,.022),(0,-.119,.033)],.004,dark,stock)
profile("CrosseArmature",[(.185,.055),(.316,.042),(.355,.069),(.385,.055),(.382,-.101),(.348,-.115),(.306,-.047),(.186,-.043)],-.062,.062,dark,stock,.007)
box("AppuiJoue",(0,.063,.277),(.142,.026,.146),rubber,stock,.006)
profile("InsertCrosse",[(.227,.020),(.310,.012),(.343,-.066),(.318,-.055),(.292,-.025),(.227,-.025)],-.065,.065,armor,stock,.003)
box("TalonCrosse",(0,-.027,.385),(.148,.189,.035),rubber,stock,.007)
for j in range(7):
    box(f"StrieTalon_{j}",(0,-.101+j*.025,.406),(.129,.008,.006),dark,stock,.001)
for side in [-1,1]:
    box(f"TraitCrosse_{side}",(side*.068,.024,.268),(.004,.008,.093),orange,stock,.001)
    cylinder(f"AttacheBretelle_{side}",(side*.069,-.058,.342),.012,.009,metal,stock,(side,0,0),24)

# Rail denté et viseur réflexe ouvert, sans surface opaque sur la cible.
box("SupportRail",(0,.118,-.037),(.056,.016,.342),dark,sight,.002)
for j in range(15):
    box(f"DentRail_{j}",(0,.130,.113-j*.023),(.073,.010,.011),metal,sight,.001)
box("EmbaseViseur",(0,.148,.068),(.081,.027,.088),dark,sight,.004)
for side in [-1,1]:
    box(f"PiedViseur_{side}",(side*.036,.181,.063),(.013,.061,.026),dark,sight,.003)
    box(f"CoinViseur_{side}",(side*.026,.214,.063),(.023,.013,.026),armor,sight,.003)
box("SommetViseur",(0,.218,.063),(.055,.012,.026),dark,sight,.003)
box("EcranViseur",(0,.154,.116),(.044,.012,.002),glass,sight,.001)
for j in range(3):
    box(f"DiodeViseur_{j}",(-.013+j*.013,.155,.118),(.006,.004,.001),cyan,sight,.0003)
box("Guidon",(0,.100,-.414),(.018,.047,.020),dark,sight,.003)
box("FibreGuidon",(0,.123,-.402),(.007,.006,.003),cyan,sight,.001)

# Mains gantées et manches, dans la même pose fixe que l'ancienne arme.
# Leur géométrie suit le recul du nœud Model, sans nouveau squelette ni logique.
ellipsoid("PaumeDroite",(.018,-.163,.132),(.058,.084,.062),rubber,hands)
for j in range(3):
    y=-.159-j*.026
    ellipsoid(f"DoigtDroit_{j}",(-.013,y,.084+j*.008),(.048,.013,.024),rubber,hands)
    box(f"ProtectionDoigtDroit_{j}",(-.043,y,.089+j*.008),(.015,.017,.025),dark,hands,.004)
ellipsoid("PouceDroit",(-.040,-.126,.155),(.019,.038,.039),rubber,hands)
ellipsoid("IndexDroit",(.016,-.116,.040),(.012,.013,.041),rubber,hands)
rod("MancheDroite",(.047,-.253,.219),(.145,-.403,.437),.071,fabric,hands,20)
rod("PoignetDroit",(.036,-.224,.183),(.055,-.267,.231),.062,rubber,hands,24)
box("BrassardDroit",(.055,-.247,.221),(.122,.031,.060),armor,hands,.008)
box("RepereBrassardDroit",(.012,-.226,.221),(.034,.008,.044),orange,hands,.002)
ellipsoid("PaumeGauche",(-.068,-.102,-.261),(.061,.045,.079),rubber,hands)
for j in range(4):
    z=-.305+j*.029
    ellipsoid(f"DoigtGauche_{j}",(-.077,-.069,z),(.025,.022,.012),rubber,hands)
    box(f"ProtectionDoigtGauche_{j}",(-.092,-.061,z),(.018,.019,.016),dark,hands,.004)
ellipsoid("PouceGauche",(-.009,-.086,-.209),(.042,.018,.022),rubber,hands)
rod("PoignetGauche",(-.084,-.125,-.202),(-.106,-.181,-.137),.051,rubber,hands,24)
rod("MancheGauche",(-.107,-.180,-.139),(-.162,-.291,.068),.065,fabric,hands,20)
box("BrassardGauche",(-.105,-.164,-.160),(.109,.037,.069),armor,hands,.007)
box("TemoinBrassardGauche",(-.141,-.142,-.164),(.018,.009,.030),cyan,hands,.002)
for side in [-1,1]:
    # Coutures discrètes sur les manchettes.
    for j in range(4):
        box(f"Couture_{side}_{j}",((.07 if side>0 else -.13)+j*.004,-.261 if side>0 else -.219,.276 if side>0 else -.060),(.003,.008,.035),dark,hands,.001)

# Copier les maillages évalués et les réunir par matériau pour l'export.
# La source Blender conserve les pièces et les chanfreins modifiables.
bpy.context.view_layer.update()
export_root=empty("H01ViewModel")
export_root["asset"]="HELIX H-01"
export_root["role"]="visual_only"
weapon_group=empty("Weapon",export_root)
hands_group=empty("Gloves",export_root)
# Le même nom de repère sera présent dans la source et dans le GLB.
socket.name="MuzzleReference_Source"
empty("MuzzleReference",export_root,(0,.025,-.555))
groups={}
depsgraph=bpy.context.evaluated_depsgraph_get()
for original in root.children_recursive:
    if original.type!="MESH":
        continue
    data=bpy.data.meshes.new_from_object(original.evaluated_get(depsgraph),depsgraph=depsgraph)
    duplicate=bpy.data.objects.new("Export_"+original.name,data)
    bpy.context.collection.objects.link(duplicate)
    duplicate.matrix_world=original.matrix_world.copy()
    is_hand=original.parent==hands
    duplicate.parent=hands_group if is_hand else weapon_group
    groups.setdefault((is_hand,data.materials[0].name),[]).append(duplicate)
for (is_hand,mat_name),objects in groups.items():
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    if len(objects)>1:
        bpy.ops.object.join()
    objects[0].name=("Gloves_" if is_hand else "Weapon_")+mat_name
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)

export_objects=[export_root,*export_root.children_recursive]
bpy.ops.object.select_all(action="DESELECT")
for obj in export_objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active=export_root
MODEL.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(MODEL),export_format="GLB",use_selection=True,
                          export_yup=True,export_animations=False,export_materials="EXPORT",
                          export_cameras=False,export_lights=False,export_extras=True)
triangles=0
coords=[]
for obj in export_objects:
    if obj.type=="MESH":
        obj.data.calc_loop_triangles()
        triangles+=len(obj.data.loop_triangles)
        coords.extend(obj.matrix_world@v.co for v in obj.data.vertices)
game_coords=[(v.x,v.z,-v.y) for v in coords]
manifest={"name":"HELIX H-01","blender":bpy.app.version_string,"triangles":triangles,
          "meshes":sum(o.type=="MESH" for o in export_objects),
          "materials":len({m.name for o in export_objects if o.type=="MESH" for m in o.data.materials}),
          "bounds_godot":[list(map(min,zip(*game_coords))),list(map(max,zip(*game_coords)))],
          "muzzle_godot":[0,.025,-.555],"forward":"-Z","units":"meters",
          "glb":str(MODEL.relative_to(WORKSPACE))}
(ART/"asset-info.json").write_text(json.dumps(manifest,indent=2),encoding="utf-8")
for obj in reversed(export_objects):
    bpy.data.objects.remove(obj,do_unlink=True)
socket.name="MuzzleReference"

# Le studio montre uniquement la carabine ; les gants restent dans le GLB.
for obj in hands.children_recursive:
    obj.hide_render=True
studio=bpy.data.collections.new("Studio_Preview_Not_Exported")
bpy.context.scene.collection.children.link(studio)

def studio_object(obj):
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    studio.objects.link(obj)
    return obj

floor_mat=material("Studio_Slate",(.018,.032,.047),.1,.47)
bpy.ops.mesh.primitive_plane_add(size=200,location=xyz((0,-.273,0)))
floor=bpy.context.object
floor.name="Studio_Ground"
floor.data.materials.append(floor_mat)
studio_object(floor)

def light(name,pos,energy,colour,size):
    data=bpy.data.lights.new(name,"AREA")
    data.energy=energy
    data.color=colour
    data.shape="DISK"
    data.size=size
    obj=bpy.data.objects.new(name,data)
    studio.objects.link(obj)
    obj.location=xyz(pos)
    obj.rotation_euler=(xyz((0,0,-.06))-obj.location).to_track_quat("-Z","Y").to_euler()

light("Key",(-1.1,2.0,-.6),160,(1,.90,.77),1.9)
light("Fill",(-1.8,.35,.2),85,(.57,.81,1),1.6)
light("Rim",(1.2,1.7,.7),230,(.30,.72,1),1.2)
camera_data=bpy.data.cameras.new("Camera_Asset")
camera=bpy.data.objects.new("Camera_Asset",camera_data)
studio.objects.link(camera)
camera.location=xyz((-1.6,.95,-1.45))
camera.rotation_euler=(xyz((0,-.025,-.06))-camera.location).to_track_quat("-Z","Y").to_euler()
camera_data.type="ORTHO"
camera_data.ortho_scale=1.22
scene=bpy.context.scene
scene.camera=camera
scene.render.engine="CYCLES"
scene.cycles.samples=64
scene.cycles.use_denoising=True
scene.render.resolution_x=1500
scene.render.resolution_y=1000
scene.render.resolution_percentage=100
scene.world.use_nodes=True
scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.04,.065,.09,1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value=.42
scene.view_settings.view_transform="AgX"
scene.render.image_settings.file_format="PNG"
scene.render.filepath=str(ART/"preview.png")
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
bpy.context.view_layer.objects.active=root
for area in bpy.context.screen.areas:
    if area.type=="VIEW_3D":
        area.spaces.active.region_3d.view_distance=1.4
        area.spaces.active.region_3d.view_location=xyz((0,0,-.05))
        area.spaces.active.region_3d.view_perspective="CAMERA"
        area.spaces.active.shading.type="MATERIAL"
bpy.ops.wm.save_as_mainfile(filepath=str(ART/"helix_carbine.blend"))
if RENDER:
    bpy.ops.render.render(write_still=True)
print("HELIX_CARBINE",json.dumps(manifest))
