"""HELIX M-90 CERBERE. Blender 4.5, metres, avant Godot -Z.
Les pieces du .blend restent editables ; le GLB regroupe les meshes par materiau
en preservant les pivots des quatre helices et des deux mitrailleuses.
"""
from pathlib import Path
import json
import math
import sys
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
ART = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'art/arena'))
from modeling import xyz, material, empty, mesh, box, cylinder, rod, arc, lettering

bpy.ops.wm.read_factory_settings(use_empty=True)
ART.mkdir(parents=True, exist_ok=True)
root = empty('HELIX_M90_CERBERE')
body = empty('Armor', root)
dark = material('M90_Graphite', (.045,.063,.078), .78,.32)
armor = material('M90_Armor', (.22,.27,.28), .72,.38)
ivory = material('HELIX_Ivory', (.72,.73,.64), .5,.42)
steel = material('M90_MachinedSteel', (.32,.39,.42), .88,.24)
black = material('M90_Carbon', (.012,.019,.023), .32,.6)
orange = material('HELIX_Warning', (.92,.235,.035), .38,.42)
red = material('M90_RedOptics', (1,.009,.003), .2,.23, 6)
amber = material('M90_HotCoils', (1,.12,.008), .4,.3, 2)


def plate(name, outline, bottom, top, mat, parent):
    n = len(outline)
    points = [(x,y,z) for y in (bottom,top) for x,z in outline]
    faces = [tuple(range(n-1,-1,-1)), tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,points,faces,mat,parent,.035,True)


def prism(name, points, depth, mat, parent):
    # Face menacante dans le plan XY, epaisseur suivant Z.
    n = len(points)
    verts = [(x,y,z) for z in (-depth/2,depth/2) for x,y in points]
    faces = [tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,verts,faces,mat,parent,.018,True)


outline = [(-1.05,-1.5),(-1.42,-.6),(-1.22,1.45),(-.72,1.85),(.72,1.85),(1.22,1.45),(1.42,-.6),(1.05,-1.5),(0,-1.85)]
plate('Chassis_monocoque',outline,-.42,.43,dark,body)
plate('Blindage_dorsal',[(x*.92,z*.94) for x,z in outline],.43,.7,armor,body)
plate('Capot_superieur', [(-.65,-.9),(-.78,.9),(0,1.35),(.78,.9),(.65,-.9),(0,-1.4)],.7,.83,ivory,body)
plate('Quille_inferieure',[(-.85,-.8),(-.55,1.5),(.55,1.5),(.85,-.8),(0,-1.65)],-.68,-.42,black,body)
# Ailerons, verins, plaques rapportees et aerations.
for sx in (-1,1):
    flank = empty('Flanc_G' if sx<0 else 'Flanc_D',body)
    for z in (-.9,-.25,.4,1.05):
        box('Ecaille_laterale',(sx*1.18,.47,z),(.38,.22,.54),armor,flank,.05)
        cylinder('Boulon_blindage',(sx*1.18,.6,z),.045,.035,steel,flank,vertices=6)
    for j in range(9):
        box('Grille_radiateur',(sx*.9,.845,-.38+j*.16),(.28,.035,.055),black,flank,.008)
    for j in range(4):
        vane = prism('Aileron_dorsal',[(0,0),(.1,.65),(.24,.95),(.34,0)],.15,dark,flank)
        vane.location=xyz((sx*(.25+j*.23),.75,.95))
    rod('Verin_exterieur',(sx*.85,-.35,.75),(sx*1.55,-.62,.0),.075,steel,flank)
    rod('Cable_orange',(sx*.85,-.4,.65),(sx*1.6,-.7,-.65),.04,orange,flank)
    box('Bande_identification',(sx*.82,.85,-.95),(.1,.018,.55),orange,flank,.005)
lettering('Numero_dorsal','M-90',(0,.846,.25),.32,black,body,top=True)
lettering('Marquage_HELIX','HELIX',(0,.846,-.43),.15,orange,body,top=True)

# Masque de predateur : sourcils anguleux, optique rouge centrale et machoire.
face = empty('PredatorMask',body,pos=(0,0,-1.55))
mask = prism('Masque_cranien',[(-.88,.52),(-.98,.13),(-.62,-.48),(0,-.77),(.62,-.48),(.98,.13),(.88,.52),(0,.72)],.32,ivory,face)
for sx in (-1,1):
    brow=prism('Sourcil_blinde',[(sx*.08,.27),(sx*.87,.55),(sx*.8,.16),(sx*.2,-.02)],.18,dark,face)
    brow.location=xyz((0,.13,-.23))
    eye=prism('Fente_optique',[(sx*.17,.23),(sx*.72,.39),(sx*.67,.27),(sx*.19,.12)],.05,red,face)
    eye.location=xyz((0,.1,-.34))
    fang=prism('Crochet_mandibule',[(sx*.4,-.26),(sx*.76,-.22),(sx*.7,-.8),(sx*.43,-1.02)],.3,dark,face)
    fang.location=xyz((0,0,-.12))
for radius,depth,z,mat in [(.29,.19,-.26,steel),(.22,.21,-.35,black),(.145,.05,-.48,red),(.065,.06,-.52,amber)]:
    cylinder('Oeil_central',(0,.16,z),radius,depth,mat,face,axis=(0,0,1),vertices=32)
for x in (-.28,-.14,0,.14,.28):
    box('Event_machoire',(x,-.39,-.185),(.06,.16,.05),black,face)

# Quatre turbines carenees avec pales independantes.
rotors=empty('Rotors',root)
for i,(x,z) in enumerate([(-2.12,-.75),(2.12,-.75),(-2.02,1.34),(2.02,1.34)]):
    rotor=empty(f'Rotor{i}',rotors,pos=(x,.26,z))
    rod('Bras_porteur',(math.copysign(.9,x),.15,z*.7),(x,.26,z),.16,dark,body)
    rod('Durite_turbine',(math.copysign(.9,x),.37,z*.7),(x,.47,z),.035,orange,body)
    arc('Carter_epais',.91,.72,-.2,.19,dark,rotor,segments=48)
    arc('Blindage_haut',.93,.75,.16,.28,armor,rotor,segments=48)
    arc('Anneau_signal',.916,.9,-.11,-.04,orange,rotor,segments=48)
    arc('Bord_interieur',.76,.72,.20,.31,steel,rotor,segments=48)
    for j in range(8):
        a=j*math.tau/8
        cylinder('Vis_carter',(.835*math.cos(a),.29,.835*math.sin(a)),.032,.035,steel,rotor,vertices=6)
        rod('Protection_radiale',(.2*math.cos(a),.32,.2*math.sin(a)),(.72*math.cos(a),.32,.72*math.sin(a)),.021,steel,rotor,8)
    cylinder('Stator',(0,-.1,0),.18,.36,black,rotor)
    blades=empty(f'Blades{i}',rotor)
    for j in range(6):
        a=j*math.tau/6
        blade=plate('Pale_turbine',[(.17,-.06),(.62,-.03),(.69,.08),(.19,.12)],-.025,.025,steel,blades)
        blade.rotation_euler.z=a
    cylinder('Moyeu',(0,.08,0),.17,.18,orange,blades,vertices=16)

# Deux vraies mitrailleuses a six canons, tambours, courroies, supports.
guns=empty('Guns',root)
for side,x in [('Left',-1.52),('Right',1.52)]:
    gun=empty(side,guns,pos=(x,-.62,-.42))
    box('Berceau',(0,.14,.1),(.8,.38,1.8),armor,gun,.08)
    cylinder('Pivot_tourelle',(0,.4,.36),.23,.3,steel,gun,axis=(1,0,0))
    cylinder('Boitier_moteur',(0,0,.38),.4,1.1,dark,gun,axis=(0,0,1))
    cylinder('Tambour_munitions',(math.copysign(.48,x),.02,.4),.4,.5,armor,gun,axis=(1,0,0))
    cylinder('Flasque_tambour',(math.copysign(.76,x),.02,.4),.32,.06,steel,gun,axis=(1,0,0))
    for j in range(11):
        a=j*math.pi/10
        cylinder('Cartouche_bande',(math.copysign(.46,x)*math.sin(a),.2+.32*math.cos(a),-.15),.035,.18,orange,gun,axis=(0,0,1),vertices=8)
    for j in range(6):
        box('Radiateur_culasse',(0,.38,-.35+j*.15),(.45,.055,.06),black,gun,.005)
    barrels=empty(side+'Barrels',gun)
    for z,rad,depth in [(-.45,.36,.18),(-1.4,.36,.12),(-1.96,.36,.14)]:
        cylinder('Collier_canons',(0,0,z),rad,depth,steel,barrels,axis=(0,0,1),vertices=24)
    for j in range(6):
        a=j*math.tau/6
        xx,yy=.235*math.cos(a),.235*math.sin(a)
        cylinder('Canon',(xx,yy,-1.22),.077,1.85,dark,barrels,axis=(0,0,1),vertices=12)
        cylinder('Frein_de_bouche',(xx,yy,-2.13),.09,.18,steel,barrels,axis=(0,0,1),vertices=12)
        cylinder('Ame_noire',(xx,yy,-2.227),.055,.012,black,barrels,axis=(0,0,1),vertices=12,bevel=0)
        cylinder('Bobine_chaude',(xx,yy,-.62),.084,.16,amber,barrels,axis=(0,0,1),vertices=12)
    empty(side+'Muzzle',gun,pos=(0,0,-2.3))
    lettering('Danger','DANGER',(0,.34,-.1),.1,orange,gun,top=True)

# Export sur des copies evaluees : les pieces originales restent separees dans Blender.
originals=[root,*root.children_recursive]
original_names={obj:obj.name for obj in originals}
for obj in originals: obj.name=original_names[obj]+'__source'
copies={}
deps=bpy.context.evaluated_depsgraph_get()
for original in originals:
    if original.type=='MESH':
        copy=bpy.data.objects.new(original_names[original]+'_export',bpy.data.meshes.new_from_object(original.evaluated_get(deps)))
    else:
        copy=bpy.data.objects.new(original_names[original],None)
    bpy.context.collection.objects.link(copy)
    copy.matrix_local=original.matrix_local.copy()
    copies[original]=copy
for original,copy in copies.items():
    copy.parent=copies.get(original.parent)
    copy.matrix_local=original.matrix_local.copy()
export_root=copies[root]
for parent in [obj for obj in copies.values() if obj.type=='EMPTY']:
    groups={}
    for obj in list(parent.children):
        if obj.type=='MESH':
            groups.setdefault(obj.data.materials[0].name,[]).append(obj)
    for mat_name,objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects: obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        if len(objects)>1: bpy.ops.object.join()
        objects[0].name=parent.name+'_'+mat_name
export_objects=[export_root,*export_root.children_recursive]
bpy.ops.object.select_all(action='DESELECT')
for obj in export_objects: obj.select_set(True)
bpy.context.view_layer.objects.active=export_root
bpy.context.view_layer.update()
glb=ROOT/'DroneArena/assets/models/helix_boss.glb'
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_extras=True)
triangles=0
coords=[]
for obj in export_objects:
    if obj.type=='MESH':
        obj.data.calc_loop_triangles()
        triangles+=len(obj.data.loop_triangles)
        coords += [obj.matrix_world@v.co for v in obj.data.vertices]
manifest={'name':'HELIX M-90 CERBERE','blender':bpy.app.version_string,'triangles':triangles,'meshes':sum(o.type=='MESH' for o in export_objects),'editable_pieces':len(originals),'bounds_blender':[list(map(min,zip(*coords))),list(map(max,zip(*coords)))],'game_forward':'-Z','glb':str(glb.relative_to(ROOT)),'animated_pivots':['Rotors/Rotor0/Blades0','Rotors/Rotor1/Blades1','Rotors/Rotor2/Blades2','Rotors/Rotor3/Blades3','Guns/Left/LeftBarrels','Guns/Right/RightBarrels']}
(ART/'asset-info.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
for obj in export_objects: bpy.data.objects.remove(obj,do_unlink=True)
for obj in originals: obj.name=original_names[obj]

# Studio a l'echelle du boss, exclu du GLB.
studio=bpy.data.collections.new('Studio_Not_Exported')
bpy.context.scene.collection.children.link(studio)
floor_mat=material('Studio_Slate',(.018,.028,.039),.25,.45)
bpy.ops.mesh.primitive_plane_add(size=200,location=xyz((0,-1.8,0)))
floor=bpy.context.object
floor.data.materials.append(floor_mat)
for col in list(floor.users_collection): col.objects.unlink(floor)
studio.objects.link(floor)
for name,pos,energy,col,size in [('Key',(3,7,-6),2000,(1,.84,.68),7),('Fill',(-5,3,-4),1500,(.44,.65,1),6),('Rim',(2,5,5),2800,(1,.13,.025),4)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.color=col;data.size=size
    obj=bpy.data.objects.new(name,data);studio.objects.link(obj);obj.location=xyz(pos)
    obj.rotation_euler=(-obj.location).to_track_quat('-Z','Y').to_euler()
camera_data=bpy.data.cameras.new('Camera_Boss')
camera=bpy.data.objects.new('Camera_Boss',camera_data);studio.objects.link(camera)
camera.location=xyz((7,4.7,-9))
camera.rotation_euler=(xyz((0,.05,-.2))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO';camera_data.ortho_scale=9.2
scene=bpy.context.scene;scene.camera=camera
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.render.resolution_x=1600;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('StudioWorld');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.035,.055,.08,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(ART/'preview.png')
bpy.ops.object.select_all(action='DESELECT');root.select_set(True);bpy.context.view_layer.objects.active=root
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_distance=10
        area.spaces.active.region_3d.view_perspective='CAMERA'
        area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'helix_boss.blend'))
if '--skip-render' not in sys.argv: bpy.ops.render.render(write_still=True)
print('HELIX_BOSS',json.dumps(manifest))
