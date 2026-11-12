"""HELIX K-9 LIMIER. Blender 4.5, GLB avec quatre pattes et un canon articulés."""
from pathlib import Path
import sys
import json
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
ART = Path(__file__).resolve().parent
ART.mkdir(exist_ok=True)
sys.path.insert(0, str(ROOT / 'art/arena'))
from modeling import xyz, material, empty, mesh, box, cylinder, rod, lettering

bpy.ops.wm.read_factory_settings(use_empty=True)
root = empty('HELIX_K9_LIMIER')
dark = material('K9_Graphite', (.032,.048,.062), .75,.36)
ivory = material('HELIX_Ceramique', (.68,.72,.72), .40,.38)
steel = material('K9_Acier', (.24,.32,.36), .88,.28)
rubber = material('K9_Caoutchouc', (.012,.018,.022), .12,.78)
orange = material('HELIX_Orange', (.95,.23,.035), .4,.38)
red = material('K9_Optiques', (1,.015,.008), .15,.22, 5)
laser = material('K9_Laser', (.95,.035,.38), .2,.25, 4)
body = empty('Body', root)


def wedge(name, outline, depth, mat, parent):
    n = len(outline)
    verts = [(x,y,z) for x in (-depth/2,depth/2) for y,z in outline]
    faces = [tuple(range(n-1,-1,-1)), tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name, verts, faces, mat, parent, .018, True)


# Corps de quadrupède, épaules puissantes et taille plus étroite.
box('Chassis', (0,.93,.0), (.79,.42,1.47), dark, body,.075)
box('Carapace_Dorsale',(0,1.16,-.06),(.86,.21,1.38),ivory,body,.055)
box('Poitrail',(0,.94,-.62),(.83,.56,.41),steel,body,.065)
box('Croupe',(0,.98,.63),(.69,.40,.36),ivory,body,.055)
for sx in [-1,1]:
    box('Blindage_Epaule',(sx*.43,1.00,-.49),(.13,.35,.43),ivory,body,.045)
    box('Marquage_Orange',(sx*.505,1.08,-.48),(.018,.08,.28),orange,body,.006)
    for j in range(7):
        box('Ventilation',(sx*.417,.98,-.22+j*.105),(.035,.13,.043),rubber,body,.003)
    rod('Cable_Flanc',(sx*.38,.84,-.53),(sx*.36,.8,.5),.025,orange,body)
    for z in [-.53,.55]:
        cylinder('Axe_Hanche',(sx*.5,.95,z),.15,.23,steel,body,axis=(1,0,0))
        cylinder('Moyeu_Hanche',(sx*.63,.95,z),.095,.035,orange,body,axis=(1,0,0),vertices=12)
lettering('Designation','K-9',(0,1.272,.34),.18,dark,body,top=True)

# Cou, tête de loup, museau allongé, oreilles et mâchoire mécanique.
rod('Cou',(0,1.02,-.57),(0,1.20,-.84),.20,dark,body)
head = empty('Head',body,pos=(0,1.18,-.85))
wedge('Crane',[(-.16,.18),(.15,.18),(.22,-.10),(.13,-.39),(-.08,-.47),(-.23,-.24)],.53,ivory,head)
wedge('Museau',[(-.07,-.29),(.02,-.35),(-.03,-.63),(-.15,-.69),(-.21,-.43)],.34,dark,head)
box('Truffe',(0,-.09,-.63),(.37,.15,.12),steel,head,.025)
box('Machoire',(0,-.22,-.41),(.36,.075,.38),steel,head,.02)
for sx in [-1,1]:
    wedge('Oreille',[ (.12,.08),(.49,.17),(.39,-.06),(.10,-.17)],.13,dark,head).location = xyz((sx*.19,0,0))
    box('Oeil_Rouge',(sx*.29,.035,-.255),(.045,.055,.22),red,head,.012)
    box('Oeil_Frontal',(sx*.15,.035,-.455),(.115,.055,.065),red,head,.01)
    for j in range(3):
        cylinder('Dent',(sx*.145,-.2,-.35-j*.07),.022,.075,steel,head,vertices=8)
    cylinder('Articulation_Machoire',(sx*.276,-.10,-.05),.06,.025,steel,head,axis=(1,0,0),vertices=12)

# Queue capteur et antenne : silhouette canine également de profil.
rod('Queue_Base',(0,1.01,.74),(0,1.20,1.02),.06,steel,body)
rod('Queue_Capteur',(0,1.20,1.02),(0,1.42,1.31),.04,dark,body)
cylinder('Embout_Queue',(0,1.42,1.31),.065,.09,red,body)

# Chaîne hiérarchique de chaque patte : hanche, genou et pied.
for label, sx, z in [('FL',-1,-.55),('FR',1,-.55),('RL',-1,.57),('RR',1,.57)]:
    hip = empty('Hip'+label,root,pos=(sx*.49,.95,z))
    bend = .14 if z<0 else -.13
    rod('Fémur',(0,0,0),(0,-.37,bend),.080,steel,hip)
    box('Blindage_Cuisse',(sx*.04,-.18,bend*.5),(.18,.37,.20),ivory,hip,.035)
    rod('Verin_Haut',(sx*.11,-.04,0),(sx*.11,-.31,bend),.025,orange,hip)
    knee = empty('Knee'+label,hip,pos=(0,-.37,bend))
    cylinder('Axe_Genou',(0,0,0),.105,.25,steel,knee,axis=(1,0,0),vertices=16)
    cylinder('Cache_Genou',(sx*.14,0,0),.07,.025,dark,knee,axis=(1,0,0),vertices=12)
    rod('Tibia',(0,0,0),(0,-.41,-bend),.055,dark,knee)
    rod('Piston',(sx*.08,-.05,0),(sx*.08,-.37,-bend),.022,steel,knee)
    box('Protection_Tibia',(0,-.26,-bend*.6),(.14,.28,.13),steel,knee,.02)
    box('Patin',(0,-.50,-bend-.075),(.29,.15,.40),rubber,knee,.028)
    box('Dessus_Pied',(0,-.43,-bend-.10),(.25,.06,.32),ivory,knee,.018)
    for toe in [-.09,0,.09]:
        box('Griffe',(toe,-.48,-bend-.29),(.048,.045,.13),steel,knee,.008)

# Canon laser indépendant, avec pivot de tangage et repère exact de sortie.
box('Support_Canon',(0,1.42,-.03),(.37,.28,.45),steel,body,.03)
turret = empty('Turret',body,pos=(0,1.58,-.13))
box('Canon_Corps',(0,0,-.04),(.35,.23,.55),dark,turret,.035)
box('Capot_Canon',(0,.13,-.02),(.39,.07,.41),ivory,turret,.02)
for z,r,depth,mat in [(-.38,.115,.28,steel),(-.57,.13,.10,dark),(-.63,.08,.035,laser)]:
    cylinder('Emetteur',(0,0,z),r,depth,mat,turret,axis=(0,0,1))
for sx in [-1,1]:
    box('Bobine_Laser',(sx*.192,.025,-.12),(.035,.08,.25),laser,turret,.007)
empty('LaserMuzzle',turret,pos=(0,0,-.66))

# Copies évaluées pour l'export ; regroupement par matériau à chaque pivot.
originals = [root,*root.children_recursive]
names = {obj:obj.name for obj in originals}
for obj in originals: obj.name = names[obj]+'__source'
copies = {}
deps = bpy.context.evaluated_depsgraph_get()
for obj in originals:
    copy = bpy.data.objects.new(names[obj]+'_mesh' if obj.type=='MESH' else names[obj], bpy.data.meshes.new_from_object(obj.evaluated_get(deps)) if obj.type=='MESH' else None)
    bpy.context.collection.objects.link(copy)
    copies[obj] = copy
for obj,copy in copies.items():
    copy.parent = copies.get(obj.parent)
    copy.matrix_local = obj.matrix_local.copy()
for parent in [o for o in copies.values() if o.type=='EMPTY']:
    groups = {}
    for child in list(parent.children):
        if child.type=='MESH': groups.setdefault(child.data.materials[0].name,[]).append(child)
    for mat,objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects: obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        if len(objects)>1: bpy.ops.object.join()
        objects[0].name=parent.name+'_'+mat
export = [copies[root],*copies[root].children_recursive]
bpy.ops.object.select_all(action='DESELECT')
for obj in export: obj.select_set(True)
bpy.context.view_layer.objects.active=copies[root]
bpy.context.view_layer.update()
bpy.ops.export_scene.gltf(filepath=str(ROOT/'DroneArena/assets/models/helix_hound.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_extras=True)
triangles = 0
for obj in export:
    if obj.type=='MESH':
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
info={'name':'HELIX K-9 LIMIER','triangles':triangles,'meshes':sum(o.type=='MESH' for o in export),'source_pieces':len(originals),'pivots':['HipFL','HipFR','HipRL','HipRR','KneeFL','KneeFR','KneeRL','KneeRR','Turret','LaserMuzzle']}
(ART/'asset-info.json').write_text(json.dumps(info,indent=2),encoding='utf-8')
for obj in export: bpy.data.objects.remove(obj,do_unlink=True)
for obj in originals: obj.name=names[obj]

# Studio enregistré dans Blender, entièrement exclu du GLB.
studio=bpy.data.collections.new('Studio_Not_Exported');bpy.context.scene.collection.children.link(studio)
for name,pos,power,color in [('Key',(3,5,-4),800,(.7,.85,1)),('Fill',(-4,2,-3),650,(1,.75,.6)),('Rim',(1,3,4),1100,(1,.08,.2))]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=4
    obj=bpy.data.objects.new(name,data);studio.objects.link(obj);obj.location=xyz(pos)
    obj.rotation_euler=(xyz((0,.8,0))-obj.location).to_track_quat('-Z','Y').to_euler()
camera_data=bpy.data.cameras.new('Camera_Limier');camera=bpy.data.objects.new('Camera_Limier',camera_data);studio.objects.link(camera)
camera.location=xyz((3.6,2.5,-4.6));camera.rotation_euler=(xyz((0,.75,0))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO';camera_data.ortho_scale=3.7
scene=bpy.context.scene;scene.camera=camera;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1280;scene.render.resolution_y=960;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('StudioWorld');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.025,.04,.06,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.4
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(ART/'preview.png')
bpy.ops.object.select_all(action='DESELECT');root.select_set(True);bpy.context.view_layer.objects.active=root
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'helix_hound.blend'))
if '--skip-render' not in sys.argv: bpy.ops.render.render(write_still=True)
print('HELIX_HOUND',json.dumps(info))
