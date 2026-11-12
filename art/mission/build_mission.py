"""Architecture et accessoires Blender de la mission Les trois relais.
Le même plan JSON définit la géométrie visible et les collisions Godot.
"""
from pathlib import Path
import json, math, sys
import bpy
from mathutils import Vector

ART=Path(__file__).resolve().parent
ROOT=ART.parents[1]
sys.path.insert(0,str(ART.parent/"arena"))
from modeling import xyz,material,empty,box,cylinder,rod,arc,lettering,duplicate_tree
from export_arena import export_model
LAYOUT=json.loads((ROOT/"DroneArena/missions/relay_run/layout.json").read_text(encoding="utf-8"))
RENDER="--skip-render" not in sys.argv
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for mat in list(bpy.data.materials): bpy.data.materials.remove(mat)
bpy.context.preferences.filepaths.save_version=0

ivory=material("MS_Ceramique_Ivoire",(.60,.65,.59),.25,.43)
dark=material("MS_Titane_Graphite",(.028,.046,.057),.65,.48)
metal=material("MS_Aluminium",(.25,.32,.35),.82,.38)
rubber=material("MS_Joints",(.009,.015,.019),.05,.84)
orange=material("MS_Orange",(.9,.19,.025),.2,.48)
cyan=material("MS_Cyan",(.014,.65,.78),.12,.3,1.7)
white=material("MS_Marquage",(.73,.79,.72),.05,.65)
deck_a=material("MS_Sol",(.057,.080,.087),.38,.67)
deck_b=material("MS_Sol_Alternatif",(.075,.099,.106),.4,.64)
glass=material("MS_Ecran",(.007,.060,.080),.62,.22)
architecture=empty("MissionArchitecture")

for index,(x,z,w,d) in enumerate(LAYOUT["floors"]):
    floor=empty("Floor_%d"%index,architecture)
    box("Fondation",(x+w/2,-.52,z+d/2),(w,.96,d),dark,floor,0)
    nx,nz=math.ceil(w/4),math.ceil(d/4)
    for ix in range(nx):
        for iz in range(nz):
            xx=x+(ix+.5)*w/nx; zz=z+(iz+.5)*d/nz
            box("Dalle",(xx,-.035,zz),(w/nx-.025,.07,d/nz-.025),deck_b if (ix+iz)%4==0 else deck_a,floor,.008)
            for sx in [-1,1]: box("VerrouSol",(xx+sx*(w/nx/2-.24),.0005,zz-d/nz/2+.23),(.15,.001,.035),metal,floor,0)
    lettering("NumeroSecteur","0%d"%(index+1),(x+w/2,.002,z+d-4),1.7,white,floor,True)

for name,x,z,length,height,axis in LAYOUT["walls"]:
    group=empty(name,architecture,(x,0,z),0 if axis=="x" else math.pi/2)
    box("StructureMur",(0,height/2,0),(length,height,.84),dark,group,.012)
    n=math.ceil(length/4)
    width=length/n
    for facing in [-1,1]:
        face=empty("FaceMur",group,(0,0,facing*.42),0 if facing>0 else math.pi)
        for i in range(n):
            xx=-length/2+(i+.5)*width
            h=min(2.45,height*.46)
            box("BlindageMur",(xx,height-h/2-.35,.045),(width-.22,h,.07),ivory,face,.016)
            box("PanneauBas",(xx,.94,.045),(width-.27,1.24,.07),metal,face,.015)
            box("InsertBas",(xx,.94,.088),(width-.62,.58,.018),dark,face,.005)
            box("BandeSecurite",(xx,1.44,.103),(width-.5,.042,.006),orange,face,.001)
            box("Balisage",(xx,.26,.103),(width-.3,.028,.006),cyan,face,.001)
            if height>4:
                for vent in range(5): box("Ventilation",(xx-(width-.7)/2+vent*(width-.7)/4,2.55,.103),(.14,.28,.006),metal,face,.001)
            box("Pilastre",(xx-width/2+.05,height/2,.07),(.10,height-.08,.07),metal,face,.006)
        box("Couronne",(0,height-.10,.07),(length,.20,.14),metal,face,.006)

platforms=empty("Passerelles",architecture)
for name,x,y,z,w,h,d,angle in LAYOUT["platforms"]:
    group=empty(name,platforms,(x,y,z))
    group.rotation_euler.y=-angle
    if name.startswith("Rambarde"):
        box("BarreHaute",(0,h/2-.055,0),(w,.11,d),orange,group,.008)
        for xx in [-w/2+i*2 for i in range(int(w/2)+1)]:
            box("Montant",(xx,0,0),(.08,h,d),metal,group,.008)
    else:
        box("Tablier",(0,0,0),(w,h,d),metal,group,.014)
        for zz in [-d/2+.1,d/2-.1]:
            box("BandeRampe",(0,h/2+.002,zz),(w-.12,.004,.06),orange,group,0)
        for xx in [-w/2+.25+i*.5 for i in range(int((w-.5)/.5)+1)]:
            box("Antiderapant",(xx,h/2+.003,0),(.08,.006,d-.38),dark,group,0)
for x in [9,19]:
    for z in [-16,-14]: box("PilierPasserelle",(x,1.38,z),(.16,2.76,.16),dark,platforms,.008)

route=empty("Guidage",architecture)
for a,b in zip(LAYOUT["route"],LAYOUT["route"][1:]):
    a,b=Vector(a),Vector(b)
    length=(b-a).length
    for distance in range(1,int(length),3):
        p=a.lerp(b,distance/length)
        line=box("LigneGuidage",(p.x,.0015,p.y),(.07,.003,.75),cyan,route,0)
        line.rotation_euler.z=math.atan2(-(b.x-a.x),-(b.y-a.y))

# Encadrements des portes, contenus dans les murs voisins et les linteaux.
for index,(x,z) in enumerate(LAYOUT["gates"]):
    group=empty("GateFrame_%d"%index,architecture,(x,0,z))
    for side in [-1,1]:
        box("MontantPorte",(side*3.22,2.65,0),(.42,5.3,1.10),metal,group,.015)
        box("SignalPorte",(side*3.23,2.7,.558),(.075,4.6,.012),orange,group,.003)
    box("Linteau",(0,6.1,0),(6,1.8,1),dark,group,.012)
    box("BandeLinteau",(0,5.46,.51),(5.9,.09,.02),orange,group,.002)

# Réacteur et piliers au centre du dernier secteur.
rx,rz=LAYOUT["reactor"]
reactor=empty("Reactor",architecture,(rx,0,rz))
box("Socle",(0,.20,0),(6,.4,6),metal,reactor,.025)
for side in [-1,1]:
    box("LiseretSocle",(side*2.88,.401,0),(.045,.002,5.7),orange,reactor,0)
    box("LiseretSocleBis",(0,.401,side*2.88),(5.7,.002,.045),orange,reactor,0)
cylinder("Cuve",(0,2.2,0),1.64,3.4,glass,reactor,vertices=64,bevel=.02)
for y in [.52,3.88]: arc("Couronne",1.8,1.57,y-.09,y+.09,metal,reactor)
for y in [.65,3.72]: arc("Plasma",1.795,1.76,y-.028,y+.028,cyan,reactor)
for i in range(8):
    a=i*math.tau/8
    xx,zz=1.71*math.cos(a),1.71*math.sin(a)
    rod("RenfortCuve",(xx,.87,zz),(xx,3.45,zz),.072,dark,reactor,12)
    arc("PetaleCuve",1.79,1.72,1.24,3.03,ivory,reactor,a+.17,a+.57,10)
cylinder("Capot",(0,3.985,0),1.76,.03,dark,reactor,vertices=64)
for x in [-3.2,3.2]:
    box("Pilier",(x,2.3,0),(.4,4.6,.7),ivory,reactor,.015)
    box("TraitPilier",(x,2.4,.351),(.065,3.6,.002),orange,reactor,0)

ex,ez=LAYOUT["extraction"]
pad=empty("ExtractionPad",architecture,(ex,0,ez))
arc("AnneauExtraction",3.05,2.96,.001,.004,cyan,pad)
for x in [-4,4]:
    box("RepereExtraction",(x,.002,0),(.14,.004,8),white,pad,0)
lettering("Heliport","H",(0,.005,0),2.2,white,pad,True)

# Deux accessoires séparés : les portes bougent, les consoles restent fixes.
leaf=empty("GateLeaf",pos=(70,0,0))
parts=empty("LeafParts",leaf)
box("CorpsBattant",(0,2.5,0),(3,5,.40),dark,parts,.025)
for facing in [-1,1]:
    for y in [1.25,3.75]: box("ArmureBattant",(0,y,facing*.219),(2.80,2.28,.04),ivory,parts,.018)
    box("BandeBattant",(0,2.50,facing*.245),(2.86,.16,.01),orange,parts,.002)
    for xx in [-1.20,1.20]: box("TraitBattant",(xx,2.5,facing*.245),(.035,4.6,.01),metal,parts,.001)
relay=empty("RelayModel",pos=(75,0,0))
parts=empty("RelayParts",relay)
box("PiedConsole",(0,.08,0),(1,.16,.8),dark,parts,.018)
box("CorpsConsole",(0,.72,0),(.84,1.12,.64),metal,parts,.022)
box("CapotConsole",(0,1.345,0),(1,.11,.8),ivory,parts,.016)
box("JointEcran",(0,.98,.334),(.69,.53,.028),rubber,parts,.012)
box("Ecran",(0,.98,.352),(.60,.43,.012),glass,parts,.006)
for i in range(4): box("ChargeEcran",(-.19+i*.13,.96,.361),(.055,.20,.006),cyan,parts,.001)
lettering("TitreConsole","H E L I X",(0,1.19,.362),.053,white,parts)
box("BandeConsole",(0,.40,.328),(.60,.05,.012),orange,parts,.002)
for xx in [-.32,.32]: cylinder("VisConsole",(xx,1.34,.22),.024,.012,dark,parts,vertices=6,bevel=.001)

medical=empty("RepairKit",pos=(80,0,0))
parts=empty("KitParts",medical)
box("Coque",(0,.23,0),(.85,.46,.6),ivory,parts,.04)
box("Ceinture",(0,.23,0),(.86,.11,.61),orange,parts,.012)
for xx in [-.31,.31]: box("Renfort",(xx,.23,0),(.10,.48,.62),metal,parts,.012)
box("Poignee",(0,.51,0),(.38,.08,.09),dark,parts,.015)
box("Indicateur",(0,.30,.307),(.19,.05,.012),cyan,parts,.003)
for xx in [-.2,0,.2]: box("Charge",(xx,.466,0),(.06,.012,.17),cyan,parts,.001)

metadata={"name":"Les trois relais","assets":[]}
for source,name in [(architecture,"helix_mission_map.glb"),(leaf,"helix_mission_leaf.glb"),(relay,"helix_mission_relay.glb"),(medical,"helix_mission_medical.glb")]:
    metadata["assets"].append(export_model(source,name))
(ART/"asset-info.json").write_text(json.dumps(metadata,indent=2),encoding="utf-8")

# Assemblage de présentation : ces instances ne sont pas réexportées avec les murs.
preview=empty("Preview_Props_Not_Exported")
for x,z in LAYOUT["gates"]:
    duplicate_tree(leaf,"DoorLeft",(x-1.5,0,z),preview)
    duplicate_tree(leaf,"DoorRight",(x+1.5,0,z),preview)
for x,z in LAYOUT["relays"]: duplicate_tree(relay,"RelayPreview",(x,0,z),preview)
for x,z in LAYOUT["medical"]: duplicate_tree(medical,"RepairPreview",(x,0,z),preview)

def import_master(filename):
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/"DroneArena/assets/models"/filename))
    objects=set(bpy.data.objects)-before
    return next(obj for obj in objects if obj.parent is None)

cover=import_master("helix_cover.glb")
storage=import_master("helix_storage.glb")
for x,z in LAYOUT["covers"]: duplicate_tree(cover,"CoverPreview",(x,0,z),preview)
for x,z,sx,sy,sz in LAYOUT["storage"]:
    obj=duplicate_tree(storage,"StoragePreview",(x,0,z),preview)
    obj.scale=(sx,sz,sy)
for obj in [leaf,relay,medical,cover,storage]:
    for child in [obj,*obj.children_recursive]: child.hide_render=True

studio=bpy.data.collections.new("Studio_Preview_Not_Exported")
bpy.context.scene.collection.children.link(studio)
sun_data=bpy.data.lights.new("SoleilStudio","SUN")
sun_data.energy=2.1
sun_data.angle=.15
sun=bpy.data.objects.new("SoleilStudio",sun_data)
studio.objects.link(sun)
sun.rotation_euler=(.45,-.3,-.55)
camera_data=bpy.data.cameras.new("Camera_Overview")
camera=bpy.data.objects.new("Camera_Overview",camera_data)
studio.objects.link(camera)
camera.location=xyz((140,200,180))
camera.rotation_euler=(xyz((0,0,-10))-camera.location).to_track_quat("-Z","Y").to_euler()
camera_data.type="ORTHO"
camera_data.ortho_scale=220
scene=bpy.context.scene
scene.camera=camera
scene.render.engine="CYCLES"
scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.resolution_x=1600
scene.render.resolution_y=1300
scene.render.resolution_percentage=100
scene.world.use_nodes=True
scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.10,.16,.20,1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value=.65
scene.view_settings.view_transform="AgX"
scene.render.image_settings.file_format="PNG"
scene.render.filepath=str(ART/"preview.png")
bpy.ops.object.select_all(action="DESELECT")
architecture.select_set(True)
bpy.context.view_layer.objects.active=architecture
for area in bpy.context.screen.areas:
    if area.type=="VIEW_3D":
        area.spaces.active.region_3d.view_perspective="CAMERA"
        area.spaces.active.shading.type="MATERIAL"
bpy.ops.wm.save_as_mainfile(filepath=str(ART/"helix_mission.blend"))
if RENDER: bpy.ops.render.render(write_still=True)
print("HELIX_MISSION",json.dumps(metadata))
