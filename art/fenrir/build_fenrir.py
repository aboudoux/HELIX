"""FENRIR, alpha des LIMIERS : modèle quadrupède dédié, mètres et +Y Godot."""
from pathlib import Path
import sys, json, math, bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
ART=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'art/arena'))
from modeling import xyz,material,empty,mesh,box,cylinder,rod,lettering
bpy.ops.wm.read_factory_settings(use_empty=True)
root=empty('HELIX_FENRIR_ALPHA')
dark=material('Fenrir_Graphite',(.025,.036,.048),.82,.32)
ivory=material('HELIX_Ceramique',(.56,.62,.65),.55,.34)
steel=material('Fenrir_Titane',(.17,.23,.28),.9,.27)
rubber=material('Fenrir_Joints',(.009,.014,.02),.2,.7)
orange=material('HELIX_Orange',(.95,.20,.025),.5,.35)
red=material('Fenrir_Rage',(1,.015,.004),.2,.22,5)
laser=material('Fenrir_Plasma',(1,.025,.22),.15,.25,6)
body=empty('Body',root)
box('Ossature',(0,2.5,0),(2.1,1.1,4.2),dark,body,.18)
box('Thorax',(0,2.8,-1.3),(2.8,1.5,1.5),steel,body,.17)
box('Carapace',(0,3.1,.2),(2.3,.6,3.7),ivory,body,.13)
box('Croupe',(0,2.5,1.7),(1.8,1.1,1.1),ivory,body,.14)
for sx in [-1,1]:
    for z in [-1.45,1.45]:
        box('Epauliere',(sx*1.3,2.65,z),(.8,1.2,1.25),ivory,body,.14)
        box('Insigne',(sx*1.72,2.9,z),(.045,.18,.8),orange,body,.015)
        cylinder('Moteur_Hanche',(sx*1.5,2.4,z),.4,.65,steel,body,axis=(1,0,0),vertices=32)
        cylinder('Anneau_Lumineux',(sx*1.85,2.4,z),.28,.045,red,body,axis=(1,0,0))
    for j in range(9):
        box('Ailette_Flanc',(sx*1.13,2.7,-.6+j*.18),(.08,.36,.075),rubber,body,.01)
    rod('Conduite_Hydraulique',(sx*1.05,2.15,-1.5),(sx*.94,2.04,1.7),.07,orange,body)
# Dorsale haute, plaques inclinées et réacteurs arrière.
for j in range(6):
    p=box('Epine_Dorsale',(0,3.55,-.8+j*.47),(.20,.8,.35),dark,body,.045)
    p.rotation_euler.x=.3
    box('Incandescence',(0,3.98,-.8+j*.47),(.13,.045,.25),red,body,.008)
for sx in [-1,1]:
    cylinder('Refroidisseur',(sx*.6,2.8,2.2),.32,.75,steel,body,axis=(0,0,1))
    cylinder('Grille_Reacteur',(sx*.6,2.8,2.61),.24,.06,red,body,axis=(0,0,1))
rod('Cou',(0,2.9,-1.8),(0,3.2,-2.5),.55,steel,body)
head=empty('Head',body,pos=(0,3.1,-2.5))
# Crâne facetté effilé, oreilles hautes, mâchoire dentée.
verts=[(-.75,-.45,.3),(.75,-.45,.3),(-.85,.38,.1),(.85,.38,.1),(-.53,.22,-.9),(.53,.22,-.9),(-.4,-.3,-1.15),(.4,-.3,-1.15)]
mesh('Crane',verts,[(0,1,3,2),(2,3,5,4),(4,5,7,6),(0,6,7,1),(0,2,4,6),(1,7,5,3)],ivory,head,.08,True)
box('Museau',(0,-.26,-1.04),(.9,.4,.85),dark,head,.08)
box('Machoire',(0,-.57,-.78),(1.05,.14,1.1),steel,head,.04)
for sx in [-1,1]:
    ear=box('Oreille',(sx*.55,.7,.05),(.25,1.2,.4),dark,head,.06)
    ear.rotation_euler.y=sx*.22
    box('Optique_Principale',(sx*.64,.07,-.68),(.10,.13,.58),red,head,.025)
    box('Optique_Avant',(sx*.32,.07,-1.04),(.23,.12,.08),red,head,.015)
    cylinder('Pivot_Machoire',(sx*.79,-.2,-.1),.19,.1,steel,head,axis=(1,0,0))
    for j in range(5):
        cylinder('Croc',(sx*.42,-.43,-.48-j*.16),.06,.28,steel,head,vertices=6)
    cylinder('Croc_Long',(sx*.46,-.62,-1.13),.095,.52,ivory,head,vertices=6)
for label,sx,z in [('FL',-1,-1.45),('FR',1,-1.45),('RL',-1,1.5),('RR',1,1.5)]:
    hip=empty('Hip'+label,root,pos=(sx*1.5,2.4,z))
    bend=.35 if z<0 else -.35
    rod('Femur',(0,0,0),(0,-.95,bend),.22,steel,hip)
    box('Cuisse',(sx*.12,-.45,bend*.5),(.62,1.1,.65),ivory,hip,.09)
    rod('Verin_Cuisse',(sx*.38,-.1,0),(sx*.38,-.8,bend),.065,orange,hip)
    knee=empty('Knee'+label,hip,pos=(0,-.95,bend))
    cylinder('Rotule',(0,0,0),.3,.85,steel,knee,axis=(1,0,0),vertices=24)
    cylinder('Rotule_Orange',(sx*.45,0,0),.22,.06,orange,knee,axis=(1,0,0))
    rod('Tibia',(0,0,0),(0,-1.1,-bend),.17,dark,knee)
    box('Protege_Tibia',(0,-.65,-bend*.6),(.43,.9,.44),steel,knee,.06)
    rod('Piston',(sx*.28,-.1,0),(sx*.28,-1.03,-bend),.065,steel,knee)
    box('Pied',(0,-1.3,-bend-.18),(.9,.3,1.1),rubber,knee,.06)
    box('Sabot',(0,-1.14,-bend-.2),(.82,.14,1.0),ivory,knee,.045)
    for toe in [-.28,0,.28]:
        box('Griffe',(toe,-1.3,-bend-.84),(.14,.13,.48),steel,knee,.025)
# Queue segmentée terminée par une lame capteur.
for a,b in [((0,2.7,2.0),(0,3.3,2.9)),((0,3.3,2.9),(0,3.8,3.6))]: rod('Queue',a,b,.14,steel,body)
box('Lame_Queue',(0,3.95,3.65),(.18,.75,.45),orange,body,.04)
# Deux canons sur le même pivot, chacun avec un repère de sortie réel.
turret=empty('Turret',body,pos=(0,3.5,-.45))
for sx in [-1,1]:
    box('Berceau_Canon',(sx*1.6,0,0),(.9,.65,1.8),dark,turret,.1)
    box('Blindage_Canon',(sx*1.6,.38,0),(1,.16,1.7),ivory,turret,.06)
    for z,r,d,m in [(-1,.27,.8,steel),(-1.4,.34,.15,dark),(-1.5,.22,.05,laser)]:
        cylinder('Canon_Double',(sx*1.6,0,z),r,d,m,turret,axis=(0,0,1),vertices=32)
    for j in range(4): box('Bobine',(sx*1.6,.16,-.7+j*.34),(.66,.08,.12),laser,turret,.01)
    empty('LaserMuzzle' if sx<0 else 'LaserMuzzleRight',turret,pos=(sx*1.6,0,-1.54))
lettering('Designation','FENRIR',(0,3.43,.9),.5,dark,body,top=True)

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
bpy.ops.export_scene.gltf(filepath=str(ROOT/'DroneArena/assets/models/helix_fenrir.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_extras=True)
triangles = 0
for obj in export:
    if obj.type=='MESH':
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
info={'name':'FENRIR / HELIX ALPHA','triangles':triangles,'meshes':sum(o.type=='MESH' for o in export),'source_pieces':len(originals),'pivots':['HipFL','HipFR','HipRL','HipRR','KneeFL','KneeFR','KneeRL','KneeRR','Turret','LaserMuzzle']}
(ART/'asset-info.json').write_text(json.dumps(info,indent=2),encoding='utf-8')
for obj in export: bpy.data.objects.remove(obj,do_unlink=True)
for obj in originals: obj.name=names[obj]

# Studio enregistré dans Blender, entièrement exclu du GLB.
studio=bpy.data.collections.new('Studio_Not_Exported');bpy.context.scene.collection.children.link(studio)
for name,pos,power,color in [('Key',(6,10,-8),2800,(.7,.85,1)),('Fill',(-8,5,-6),2000,(1,.75,.6)),('Rim',(2,8,8),3500,(1,.08,.2))]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=7
    obj=bpy.data.objects.new(name,data);studio.objects.link(obj);obj.location=xyz(pos)
    obj.rotation_euler=(xyz((0,2,0))-obj.location).to_track_quat('-Z','Y').to_euler()
camera_data=bpy.data.cameras.new('Camera_Limier');camera=bpy.data.objects.new('Camera_Limier',camera_data);studio.objects.link(camera)
camera.location=xyz((10,7,-12));camera.rotation_euler=(xyz((0,1.7,0))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO';camera_data.ortho_scale=11
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
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'helix_fenrir.blend'))
if '--skip-render' not in sys.argv: bpy.ops.render.render(write_still=True)
print('HELIX_FENRIR',json.dumps(info))
