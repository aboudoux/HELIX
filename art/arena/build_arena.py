"""Décor original HELIX, adapté aux volumes physiques existants de DroneArena.
Ce script crée les sources Blender, les trois GLB et une vue de présentation.
"""
from pathlib import Path
import math
import sys

import bpy
from mathutils import Vector

ART=Path(__file__).resolve().parent
sys.path.insert(0,str(ART))
from modeling import xyz,material,empty,box,cylinder,rod,arc,lettering,duplicate_tree
from export_arena import export_assets

RENDER="--skip-render" not in sys.argv
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for mat in list(bpy.data.materials):
    bpy.data.materials.remove(mat)
bpy.context.preferences.filepaths.save_version=0

ivory=material("HX_Ceramique_Ivoire",(.60,.65,.59),.25,.43)
dark=material("HX_Titane_Graphite",(.028,.046,.057),.65,.48)
metal=material("HX_Aluminium_Brosse",(.25,.32,.35),.82,.38)
rubber=material("HX_Joints",(.009,.015,.019),.05,.84)
orange=material("HX_Orange_Securite",(.9,.19,.025),.2,.48)
cyan=material("HX_Balisage_Cyan",(.014,.65,.78),.12,.3,1.7)
white=material("HX_Marquage_Ivoire",(.73,.79,.72),.05,.65)
deck_a=material("HX_Sol_Anthracite",(.057,.080,.087),.38,.67)
deck_b=material("HX_Sol_Acier",(.075,.099,.106),.40,.64)
glass=material("HX_Reacteur_Teinte",(.007,.060,.080),.62,.22)
copper=material("HX_Connexion_Cuivre",(.43,.17,.06),.75,.4)
skyline=material("HX_Architecture_Distante",(.056,.093,.115),.35,.59)

root=empty("ArenaArchitecture")
root["asset"]="HELIX / SECTEUR 07"
root["collision_policy"]="Visuals only; keep Godot collision bodies"

# Sol : panneaux à niveau Y=0, joints encastrés et peinture presque affleurante.
floor=empty("DeckBase",root)
box("SupportSol",(0,-.52,0),(40,.96,48),dark,floor,0)
for section in range(4):
    deck=empty("Deck_%d"%section,root)
    for ix in range(10):
        for iz in range(12):
            x=-18+ix*4
            z=-22+iz*4
            if (0 if x<0 else 1)+(0 if z<0 else 2)!=section:
                continue
            mat=deck_b if (ix+iz)%4==0 else deck_a
            box("Dalle_%d_%d"%(ix,iz),(x,-.035,z),(3.97,.07,3.97),mat,deck,.008)
            # Verrous affleurants et lignes de maintenance, répartis sans bruit visuel.
            for sx in [-1,1]:
                box("VerrouDalle",(x+sx*1.7,.0004,z-1.75),(.17,.001,.045),metal,deck,0)
            if ix in [0,9]:
                for j in range(5):
                    box("GrillePeripherique",(x-1.2+j*.60,.0005,z),(.055,.001,3.45),rubber,deck,0)
    for x in [-2.3,2.3]:
        for z in range(-1,23,4):
            if (0 if x<0 else 1)+(0 if z<0 else 2)==section:
                box("PisteCyan",(x,.001, z),(.045,.002,1.8),cyan,deck,0)
    for x in [-.7,.7]:
        for z in [13,17,21]:
            if (0 if x<0 else 1)+2==section:
                box("ReperePosition",(x,.001,z),(.55,.002,.06),white,deck,0)
    for x in [-18.7,18.7]:
        if (0 if x<0 else 1)==section%2:
            z=-11.7 if section<2 else 11.7
            box("LignePerimetre",(x,.001,z),(.045,.002,22.9),orange,deck,0)
lettering("NumeroAuSol","07",(0,.002,21.5),.8,white,floor,top=True)
lettering("ZoneAuSol","SECTEUR 07  /  HELIX",(0,.002,19.8),.17,white,floor,top=True)

# Les faces des murs restent exactement sur X=+/-19.5 et Z=+/-23.5.
def wall(name,pos,yaw,length,north=False):
    group=empty(name,root,pos,yaw)
    box("StructureMur",(0,3.5,-.52),(length,7,.96),dark,group,.01)
    count=int(length/4)
    for i in range(count):
        x=-length/2+2+i*4
        # Deux travées centrales réservées à la porte fermée du mur nord.
        door=north and abs(x)<4
        if not door:
            box("JointPanneauBas",(x,1.05,-.035),(3.77,1.57,.045),rubber,group,.01)
            box("PanneauBas",(x,1.05,-.034),(3.62,1.4,.044),metal,group,.025)
            box("InsertBas",(x,1.06,-.009),(2.66,.69,.012),dark,group,.012)
            box("BandeSecurite",(x,1.46,-.002),(2.9,.055,.004),orange,group,.001)
            box("BlindageHaut",(x,4.65,-.055),(3.66,2.75,.11),ivory,group,.025)
            box("CadreVentilation",(x,2.56,-.039),(3.50,.54,.054),rubber,group,.015)
            for vent in range(9):
                box("AiletteMur",(x-1.40+vent*.35,2.57,-.013),(.15,.34,.026),metal,group,.004)
            for vx in [-1.57,1.57]:
                for y in [3.46,5.83]:
                    cylinder("FixationMur",(x+vx,y,-.006),.034,.012,dark,group,(0,0,1),6,.002)
            box("RepereTravee",(x+1.27,5.55,-.002),(.27,.11,.004),orange,group,.002)
            if i%3==0:
                lettering("CodeTravee","HX / %02d"%(i+1),(x,3.63,.0003),.14,dark,group)
        box("Plinthe",(x,.17,-.055),(3.98,.34,.11),rubber,group,.015)
        box("BalisageBas",(x,.28,-.004),(3.60,.035,.008),cyan,group,.002)
        # Une canalisation de refroidissement encastrée au-dessus des panneaux.
        rod("ConduiteHaute",(x-1.85,6.48,-.095),(x+1.85,6.48,-.095),.07,metal,group)
        for clamp in [-1.5,1.5]:
            box("CollierConduite",(x+clamp,6.48,-.079),(.10,.21,.158),dark,group,.006)
    for i in range(count+1):
        x=-length/2+i*4
        if north and abs(x)<.1:
            continue
        if abs(x)>=length/2:
            x=math.copysign(length/2-.12,x)
        box("PilastreMur",(x,3.50,-.10),(.24,6.98,.20),dark,group,.014)
        box("NervurePilastre",(x,3.54,-.012),(.08,6.3,.024),metal,group,.004)
        if i%2==0:
            box("FeuVertical",(x,3.85,-.003),(.036,3.40,.006),cyan,group,.002)
    box("CouronnementMur",(0,6.90,-.20),(length,.20,.40),metal,group,.012)
    if north:
        for side in [-1,1]:
            box("BattantPorte",(side*1.67,2.14,-.055),(3.30,4.24,.11),ivory,group,.035)
            box("RenfortPorte",(side*1.64,1.04,-.014),(2.8,.18,.028),dark,group,.008)
            box("PoigneePorte",(side*.20,2.26,-.015),(.17,.54,.03),orange,group,.008)
            box("MontantPorte",(side*3.48,2.20,-.035),(.18,4.40,.07),metal,group,.009)
            box("TemoinPorte",(side*3.47,2.35,-.003),(.045,3.2,.006),cyan,group,.002)
        box("PanneauEnseigne",(0,5.52,-.04),(7.4,1.65,.08),dark,group,.024)
        box("BarreEnseigne",(0,6.47,-.003),(5.6,.05,.006),orange,group,.002)
    return group

wall("WallWest",(-19.5,0,0),math.pi/2,48)
wall("WallEast",(19.5,0,0),-math.pi/2,48)
wall("WallNorth",(0,0,-23.5),0,40,True)
south=wall("WallSouth",(0,0,23.5),math.pi,40)

# Réacteur entièrement contenu dans les volumes de son socle et de son cylindre.
base=empty("ReactorBase",root,(0,0,-7))
box("SocleStructure",(0,.18,0),(6,.36,6),dark,base,.024)
box("SoclePlateau",(0,.3785,0),(6,.037,6),metal,base,.009)
for side in [-1,1]:
    box("BalisageSocle",(side*2.89,.401,0),(.055,.002,5.6),orange,base,0)
    box("BalisageSocleTransversal",(0,.401,side*2.89),(5.6,.002,.055),orange,base,0)
    for i in range(9):
        box("EventSocle",(-2.4+i*.60,.17,side*2.995),(.32,.12,.01),rubber,base,.004)
for x in [-2.65,2.65]:
    for z in [-2.65,2.65]:
        cylinder("VerrouSocle",(x,.395,z),.07,.01,dark,base,vertices=6,bevel=.002)
core=empty("ReactorCore",root,(0,0,-7))
cylinder("CuveReacteur",(0,2.20,0),1.64,3.40,glass,core,vertices=64,bevel=.02)
for y in [.52,.76,3.58,3.88]:
    arc("CouronneReacteur",1.80,1.57,y-.09,y+.09,metal if y in [.52,3.88] else dark,core)
for y in [.65,3.72]:
    arc("AnneauPlasma",1.795,1.76,y-.028,y+.028,cyan,core)
for index in range(8):
    a=index*math.tau/8
    x,z=1.71*math.cos(a),1.71*math.sin(a)
    rod("MontantCuve",(x,.87,z),(x,3.45,z),.072,dark,core,12)
    x,z=1.79*math.cos(a),1.79*math.sin(a)
    rod("TubeEnergie",(x,1.05,z),(x,3.27,z),.008,cyan,core,12)
    # Écrans d'armure courbes entre les montants, dans le rayon physique 1.8 m.
    arc("PetaleCeramique",1.79,1.72,1.24,3.03,ivory,core,a+.17,a+.57,10)
    arc("InsertOrangeReacteur",1.795,1.79,1.38,1.45,orange,core,a+.21,a+.53,8)
cylinder("CouvercleReacteur",(0,3.965,0),1.76,.03,dark,core,vertices=64,bevel=.004)
arc("CapotSuperieur",1.73,1.19,3.97,4.0,ivory,core)
arc("TraceSuperieure",1.08,1.04,3.991,3.998,cyan,core)
cylinder("TrappeReacteur",(0,3.982,0),.75,.028,metal,core,vertices=32,bevel=.005)
for index in range(8):
    a=index*math.tau/8
    cylinder("VisCouvercle",(1.5*math.cos(a),3.995,1.5*math.sin(a)),.04,.01,dark,core,vertices=6,bevel=.001)
for x in [-3.2,3.2]:
    pylon=empty("ReactorPylon_L" if x<0 else "ReactorPylon_R",root,(x,0,-7))
    box("StructurePilier",(0,2.3,0),(.40,4.6,.70),dark,pylon,.015)
    for sign in [-1,1]:
        box("FacePilier",(0,2.3,sign*.335),(.36,4.45,.03),ivory,pylon,.01)
        box("TraitPilier",(0,2.45,sign*.349),(.065,3.5,.002),orange,pylon,0)
        box("FeuPilier",(0,3.95,sign*.350),(.12,.15,.001),cyan,pylon,0)

# Deux marches : leur plateau reste à 0.35 m, sans rehausser le saut existant.
for x in [-8,8]:
    step=empty("Step_L" if x<0 else "Step_R",root,(x,0,16))
    box("MarcheStructure",(0,.16,0),(4,.32,2.5),dark,step,.018)
    box("MarchePlateau",(0,.335,0),(4,.03,2.5),metal,step,.007)
    for i in range(9):
        box("RainureMarche",(-1.72+i*.43,.350,0),(.07,.001,2.14),rubber,step,0)
    box("RepereMarche",(0,.351,1.13),(3.5,.002,.045),orange,step,0)
    box("BalisageMarche",(0,.23,1.247),(3.4,.035,.006),cyan,step,.002)

# Caisses modulaires : les pièces ne dépassent pas la collision de référence.
def crate(name,pos,width,height):
    group=empty(name,None,pos)
    structure=empty("Frame",group)
    box("ChassisCaisse",(0,height/2,0),(width-.06,height-.02,2.94),dark,structure,.02)
    box("DessusCaisse",(0,height-.0265,0),(width,.05,3),metal,structure,.012)
    box("BaseCaisse",(0,.04,0),(width,.08,3),rubber,structure,.012)
    for x in [-width/2+.10,width/2-.10]:
        for z in [-1.4,1.4]:
            box("CoinRenforce",(x,height/2,z),(.2,height-.05,.2),dark,structure,.012)
            cylinder("FixationDessus",(x,height-.003,z),.037,.006,rubber,structure,vertices=6,bevel=.001)
    # Quatre faces ; les renfoncements restent inclus dans le volume fermé.
    for face,yaw,offset,span in [("Front",0,(0,0,1.5),width),
                                 ("Back",math.pi,(0,0,-1.5),width),
                                 ("Left",-math.pi/2,(-width/2,0,0),3),
                                 ("Right",math.pi/2,(width/2,0,0),3)]:
        panel=empty("Face"+face,group,offset,yaw)
        box("PlaqueCaisse",(0,height*.54,-.031),(span-.40,height-.27,.05),ivory,panel,.015)
        box("JointCaisse",(0,height*.54,-.007),(span-.68,height*.34,.006),dark,panel,.008)
        for i in range(5):
            box("OuieCaisse",(-.56+i*.28,height*.54,-.002),(.14,height*.20,.002),metal,panel,0)
        box("BandeCaisse",(0,height*.80,-.002),(span-.56,.055,.004),orange,panel,.001)
        box("VoyantCaisse",(-span*.27,height*.25,-.002),(.29,.045,.004),cyan,panel,.001)
        for sx in [-1,1]:
            for y in [height*.20,height*.85]:
                cylinder("VisCaisse",(sx*(span/2-.28),y,-.004),.025,.008,metal,panel,(0,0,1),6,.001)
        if face in ["Front","Back"]:
            lettering("IdentifiantCaisse","HELIX  //  CELL 07",(0,height*.72,.0002),.075,dark,panel)
    for i in range(4):
        box("NervureDessus",(-width*.30+i*width*.20,height-.001,0),(.035,.002,2.48),dark,structure,0)
    return group

cover=crate("Cover_A01",(-8,0,8),3,1.1)
duplicate_tree(cover,"Cover_A02",(8,0,8))
duplicate_tree(cover,"Cover_B01",(-9,0,-4))
duplicate_tree(cover,"Cover_B02",(9,0,-4))
storage=crate("Storage_C01",(-13,0,-15),2.8,3.2)
duplicate_tree(storage,"Storage_C02",(13,0,-15))

# Skyline inaccessible, avec couronnes et bandeaux de fenêtres à distance.
city=empty("Skyline",root)
for index,(x,z,height) in enumerate([(-36,-45,18),(-22,-53,26),(-8,-62,17),(11,-55,30),(30,-48,19),(43,-29,23),(-42,-18,15)]):
    building=empty("Building_%d"%index,city,(x,-2,z))
    box("TourLointaine",(0,height/2,0),(8,height,10),skyline,building,.08)
    box("CouronneTour",(0,height-.14,0),(8.3,.28,10.3),dark,building,.04)
    for y in range(3,height-1,3):
        box("BandeFenetre",(0,y,5.005),(7.2,.14,.01),dark,building,0)
        for dx in [-2.4,0,2.4]:
            box("FenetreLumineuse",(dx,y,5.014),(.95,.045,.008),cyan,building,0)
    box("RepereTour",(0,height-1,5.02),(4.2,.08,.02),cyan,building,0)
    box("TechniqueToit",(0,height+.45,0),(3.2,.9,3.7),metal,building,.04)
    rod("AntenneTour",(2,height,0),(2,height+1.8,0),.05,dark,building)

bpy.context.view_layer.update()
export_assets()

# Présentation en coupe : le mur proche est masqué uniquement au rendu Blender.
# Les quatre murs restent tous exportés et visibles dans Godot.
for wall_group in [south,bpy.data.objects["WallWest"]]:
    for obj in wall_group.children_recursive:
        obj.hide_render=True
studio=bpy.data.collections.new("Studio_Preview_Not_Exported")
bpy.context.scene.collection.children.link(studio)

def light(name,pos,energy,colour,size):
    data=bpy.data.lights.new(name,"AREA")
    data.energy=energy
    data.color=colour
    data.shape="DISK"
    data.size=size
    obj=bpy.data.objects.new(name,data)
    studio.objects.link(obj)
    obj.location=xyz(pos)
    obj.rotation_euler=(xyz((0,0,-3))-obj.location).to_track_quat("-Z","Y").to_euler()

light("Key",(-12,32,6),18000,(1,.89,.76),24)
light("Fill",(16,20,-15),10000,(.55,.80,1),20)
data=bpy.data.lights.new("SoleilStudio","SUN")
data.energy=2
data.angle=.15
sun=bpy.data.objects.new("SoleilStudio",data)
studio.objects.link(sun)
sun.rotation_euler=(.35,-.3,-.5)
camera_data=bpy.data.cameras.new("Camera_Overview")
camera=bpy.data.objects.new("Camera_Overview",camera_data)
studio.objects.link(camera)
camera.location=xyz((-33,36,46))
camera.rotation_euler=(xyz((0,.5,-3))-camera.location).to_track_quat("-Z","Y").to_euler()
camera_data.type="ORTHO"
camera_data.ortho_scale=69
scene=bpy.context.scene
scene.camera=camera
scene.render.engine="CYCLES"
scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.resolution_x=1600
scene.render.resolution_y=1100
scene.render.resolution_percentage=100
scene.world.use_nodes=True
scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.08,.13,.17,1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value=.65
scene.view_settings.view_transform="AgX"
scene.render.image_settings.file_format="PNG"
scene.render.filepath=str(ART/"preview.png")
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
bpy.context.view_layer.objects.active=root
for area in bpy.context.screen.areas:
    if area.type=="VIEW_3D":
        area.spaces.active.region_3d.view_distance=62
        area.spaces.active.region_3d.view_location=xyz((0,0,0))
        area.spaces.active.region_3d.view_perspective="CAMERA"
        area.spaces.active.shading.type="MATERIAL"
bpy.ops.wm.save_as_mainfile(filepath=str(ART/"helix_arena.blend"))
if RENDER:
    bpy.ops.render.render(write_still=True)
