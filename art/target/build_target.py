"""Cible originale HELIX T-07, adaptée au pivot et à la collision existants.
Les coordonnées de conception sont celles de Godot : +Y vertical, mètres.
"""
from pathlib import Path
import math
import sys

import bpy
from mathutils import Vector

ART=Path(__file__).resolve().parent
sys.path.insert(0,str(ART.parent/"arena"))
sys.path.insert(0,str(ART))
from modeling import xyz,material,empty,box,cylinder,rod,mesh,lettering
from export_target import export_assets

RENDER="--skip-render" not in sys.argv
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for mat in list(bpy.data.materials):
    bpy.data.materials.remove(mat)
bpy.context.preferences.filepaths.save_version=0

ivory=material("T07_Ceramique_Ivoire",(.65,.70,.64),.25,.39)
dark=material("T07_Titane_Graphite",(.028,.046,.057),.70,.40)
metal=material("T07_Aluminium_Brosse",(.28,.36,.40),.83,.32)
rubber=material("T07_Joints",(.009,.015,.019),.03,.85)
orange=material("T07_Orange_Securite",(.90,.19,.025),.28,.42)
cyan=material("T07_Anneaux_Cyan",(.014,.65,.78),.14,.25,1.8)
amber=material("T07_Centre_Ambre",(1.0,.24,.015),.14,.22,1.7)
white=material("T07_Marquage_Ivoire",(.75,.81,.75),.05,.62)

root=empty("TrainingTargetModel")
root["asset"]="HELIX T-07"
root["role"]="visual_only"
base=empty("TargetBase",root)
base_parts=empty("BaseParts",base)
plate=empty("TargetPlate",root,(0,1,0))
plate_parts=empty("PlateParts",plate)
plate["game_pivot"]="Plate at (0,1,0); rotate X from 0 to -80 degrees"

# Socle fermé, patins et plateau démontable, dans l'encombrement initial.
box("Semelle",(0,.030,0),(1.45,.06,.85),rubber,base_parts,.012)
box("ChassisSocle",(0,.075,0),(1.41,.09,.81),dark,base_parts,.016)
box("PlaqueSocle",(0,.121,0),(1.29,.018,.73),ivory,base_parts,.008)
for x in [-.58,.58]:
    for z in [-.29,.29]:
        cylinder("VisSocle",(x,.132,z),.025,.008,metal,base_parts,vertices=6,bevel=.001)
        box("FenteVisSocle",(x,.1365,z),(.026,.001,.004),rubber,base_parts,0)
for x in [-.45,.45]:
    for j in range(5):
        box("RainureSocle",(x,.131,-.18+j*.09),(.13,.002,.025),dark,base_parts,.001)
box("CadreVoyantSocle",(0,.078,.408),(.65,.052,.016),rubber,base_parts,.004)
box("VoyantSocle",(0,.078,.418),(.50,.018,.004),cyan,base_parts,.001)
for x in [-.61,.61]:
    box("RepereSocle",(x,.102,.410),(.10,.020,.004),orange,base_parts,.001)
lettering("SerieSocle","HELIX  /  T-07",(0,.133,.24),.045,dark,base_parts,top=True)

# Colonne et articulation fixes. Aucun nouveau corps physique n'est exporté.
box("EmbaseColonne",(0,.171,0),(.31,.08,.27),metal,base_parts,.014)
box("Colonne",(0,.56,-.01),(.15,.72,.17),dark,base_parts,.009)
box("CapotColonne",(0,.57,.080),(.106,.64,.016),ivory,base_parts,.006)
box("RainureColonne",(0,.57,.090),(.036,.46,.004),rubber,base_parts,.002)
box("TraitColonne",(0,.48,.093),(.016,.25,.002),orange,base_parts,.001)
for sign in [-1,1]:
    rod("VerinColonne",(sign*.089,.22,-.02),(sign*.089,.86,-.02),.015,metal,base_parts)
    cylinder("CollierVerin",(sign*.089,.41,-.02),.021,.13,dark,base_parts,vertices=16,bevel=.002)
box("TeteColonne",(0,.931,0),(.25,.12,.20),dark,base_parts,.011)
cylinder("CharniereFixe",(0,1,0),.075,.37,metal,base_parts,(1,0,0),32,.004)
for sign in [-1,1]:
    cylinder("EcrouCharniere",(sign*.190,1,0),.055,.018,dark,base_parts,(1,0,0),12,.002)
    cylinder("RepereCharniere",(sign*.201,1,0),.027,.006,orange,base_parts,(1,0,0),16,.001)


def ring(name,outer,inner,back,front,mat,parent,start=0,end=math.tau,segments=64):
    # Anneau dans le plan XY, centré à Y=.65 depuis le pivot de bascule.
    n=segments+1
    vertices=[(r*math.cos(a),.65+r*math.sin(a),z)
              for r,z in [(outer,back),(outer,front),(inner,front),(inner,back)]
              for a in [start+(end-start)*i/segments for i in range(n)]]
    faces=[]
    for k in range(4):
        for i in range(segments):
            faces.append((k*n+i,k*n+i+1,((k+1)%4)*n+i+1,((k+1)%4)*n+i))
    faces += [(0,n,2*n,3*n),(n-1,4*n-1,3*n-1,2*n-1)]
    obj=mesh(name,vertices,faces,mat,parent,0,True)
    for face in obj.data.polygons:
        face.use_smooth=face.index//segments in (0,2)
    return obj


# Le disque reste intégralement dans R=.65 et Z=-.08..+.08.
cylinder("CorpsDisque",(0,.65,0),.65,.12,dark,plate_parts,(0,0,1),96,.008)
ring("JointCouronne",.642,.559,.060,.065,rubber,plate_parts)
for index in range(8):
    angle=index*math.tau/8
    ring("SegmentCeramique_%d"%index,.637,.568,.064,.077,ivory,plate_parts,
         angle+.035,angle+math.pi/4-.035,12)
    a=angle+math.pi/8
    x,y=.603*math.cos(a),.65+.603*math.sin(a)
    cylinder("VisCouronne_%d"%index,(x,y,.075),.013,.006,metal,plate_parts,(0,0,1),6,.0008)
    box("FenteCouronne_%d"%index,(x,y,.0785),(.013,.002,.001),rubber,plate_parts,0)
    if index%2==0:
        ring("AccentOrange_%d"%index,.634,.615,.077,.079,orange,plate_parts,
             angle+.08,angle+.25,6)
ring("BagueOptique",.546,.507,.061,.066,metal,plate_parts)
ring("AnneauCyanExterieur",.524,.510,.066,.071,cyan,plate_parts)
ring("AnneauGrave",.367,.361,.061,.063,metal,plate_parts)
ring("AnneauCyanInterieur",.225,.213,.063,.070,cyan,plate_parts)
for index in range(32):
    a=index*math.tau/32
    ring("Graduation_%02d"%index,.493,.466 if index%4==0 else .479,.061,.063,
         white if index%4==0 else metal,plate_parts,a-.006,a+.006,2)
for index in range(8):
    a=index*math.tau/8
    ring("RepereRadial_%d"%index,.341,.242,.061,.0625,metal,plate_parts,a-.0035,a+.0035,2)
ring("CadreCentre",.117,.080,.061,.073,metal,plate_parts)
cylinder("CentreAmbre",(0,.65,.071),.078,.014,amber,plate_parts,(0,0,1),48,.003)
cylinder("PointCentral",(0,.65,.0785),.018,.001,white,plate_parts,(0,0,1),32,.0004)
lettering("MarqueDisque","H E L I X",(0,1.077,.064),.030,white,plate_parts)
lettering("IdentificationDisque","T-07  /  TRAINING",(0,.232,.064),.024,white,plate_parts)
for x in [-.045,.045]:
    box("RepereCentre",(x,.65,.079),(.011,.002,.001),rubber,plate_parts,0)

# Dos mécanique, cache de maintenance et bras liés à la partie mobile.
ring("BagueArriere",.604,.52,-.077,-.064,metal,plate_parts)
cylinder("TrappeArriere",(0,.65,-.067),.40,.012,rubber,plate_parts,(0,0,1),48,.004)
for x in [-.22,.22]:
    box("NervureArriere",(x,.65,-.075),(.041,.58,.010),ivory,plate_parts,.003)
for j in range(7):
    box("VentilationArriere",(0,.51+j*.045,-.077),(.26,.013,.004),metal,plate_parts,.001)
box("BrasMobile",(0,.15,-.025),(.115,.28,.095),dark,plate_parts,.009)
box("PlaqueBras",(0,.15,.027),(.075,.20,.009),ivory,plate_parts,.003)
box("TraitBras",(0,.13,.033),(.023,.09,.002),orange,plate_parts,.001)
back_label=empty("RearLabel",plate_parts,yaw=math.pi)
lettering("MarquageMaintenance","HX-T07 / SERVICE",(0,.975,.079),.025,white,back_label)

bpy.context.view_layer.update()
export_assets()

# Studio exclu des GLB : les seules lumières de jeu restent celles de Godot.
studio=bpy.data.collections.new("Studio_Preview_Not_Exported")
bpy.context.scene.collection.children.link(studio)
floor_mat=material("Studio_Slate",(.023,.040,.056),.10,.53)
bpy.ops.mesh.primitive_plane_add(size=200,location=xyz((0,-.012,0)))
floor=bpy.context.object
floor.name="Studio_Ground"
floor.data.materials.append(floor_mat)
for collection in list(floor.users_collection):
    collection.objects.unlink(floor)
studio.objects.link(floor)

def light(name,pos,energy,colour,size):
    data=bpy.data.lights.new(name,"AREA")
    data.energy=energy
    data.color=colour
    data.shape="DISK"
    data.size=size
    obj=bpy.data.objects.new(name,data)
    studio.objects.link(obj)
    obj.location=xyz(pos)
    obj.rotation_euler=(xyz((0,1.1,0))-obj.location).to_track_quat("-Z","Y").to_euler()

light("Key",(-2,4,3),420,(1,.89,.75),3)
light("Fill",(2,2,2.5),250,(.55,.81,1),2.7)
light("Rim",(1.0,3,-2),440,(.33,.75,1),2)
camera_data=bpy.data.cameras.new("Camera_Asset")
camera=bpy.data.objects.new("Camera_Asset",camera_data)
studio.objects.link(camera)
camera.location=xyz((2.4,2.05,4.2))
camera.rotation_euler=(xyz((0,1.14,0))-camera.location).to_track_quat("-Z","Y").to_euler()
camera_data.type="ORTHO"
camera_data.ortho_scale=3.05
scene=bpy.context.scene
scene.camera=camera
scene.render.engine="CYCLES"
scene.cycles.samples=48
scene.cycles.use_denoising=True
scene.render.resolution_x=1400
scene.render.resolution_y=1200
scene.render.resolution_percentage=100
scene.world.use_nodes=True
scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.04,.065,.09,1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value=.45
scene.view_settings.view_transform="AgX"
scene.render.image_settings.file_format="PNG"
scene.render.filepath=str(ART/"preview.png")
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
bpy.context.view_layer.objects.active=root
for area in bpy.context.screen.areas:
    if area.type=="VIEW_3D":
        area.spaces.active.region_3d.view_distance=3.5
        area.spaces.active.region_3d.view_location=xyz((0,1.1,0))
        area.spaces.active.region_3d.view_perspective="CAMERA"
        area.spaces.active.shading.type="MATERIAL"
bpy.ops.wm.save_as_mainfile(filepath=str(ART/"helix_target.blend"))
if RENDER:
    bpy.ops.render.render(write_still=True)
