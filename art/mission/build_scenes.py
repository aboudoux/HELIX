"""Assembler la mission dans des scènes Godot éditables, à partir du plan JSON."""
from pathlib import Path
import json
import re

ROOT=Path(__file__).resolve().parents[2]
PROJECT=ROOT/"DroneArena"
DEST=PROJECT/"missions/relay_run"
LAYOUT=json.loads((DEST/"layout.json").read_text(encoding="utf-8"))

def q(value): return json.dumps(value,ensure_ascii=False)
def vec(*v): return "Vector3("+", ".join(str(float(x)) for x in v)+")"
def numbers(text): return re.sub(r'(?<![\w\d])(-?)\.(\d)',r'\g<1>0.\2',text)


class Scene:
    def __init__(self):
        self.ext=[]; self.sub=[]; self.nodes=[]; self.shapes={}
    def external(self,kind,path):
        ident="e"+str(len(self.ext)+1)
        self.ext.append(f'[ext_resource type="{kind}" path="{path}" id="{ident}"]\n')
        return f'ExtResource("{ident}")'
    def box(self,size):
        key=tuple(size)
        if key not in self.shapes:
            ident="box"+str(len(self.shapes)+1)
            self.sub.append(f'[sub_resource type="BoxShape3D" id="{ident}"]\nsize = {vec(*size)}\n')
            self.shapes[key]=f'SubResource("{ident}")'
        return self.shapes[key]
    def node(self,name,parent=None,kind=None,instance=None,**props):
        line=f'[node name="{name}"'
        if kind: line+=f' type="{kind}"'
        if parent is not None: line+=f' parent="{parent}"'
        if instance: line+=f' instance={instance}'
        self.nodes.append(line+"]\n"+"".join(f'{key} = {val}\n' for key,val in props.items()))
    def body(self,name,pos,size,parent=".",rotation=(0,0,0)):
        self.node(name,parent,"StaticBody3D",position=vec(*pos),rotation=vec(*rotation),collision_layer=1,collision_mask=2)
        self.node("CollisionShape3D",name if parent=="." else parent+"/"+name,"CollisionShape3D",shape=self.box(size))
    def label(self,name,pos,text,parent=".",font=48,**props):
        self.node(name,parent,"Label3D",position=vec(*pos),text=q(text),font_size=font,pixel_size=.008,
                  modulate="Color(.35,.94,.91,1)",outline_size=4,**props)
    def save(self,name):
        (DEST/name).write_text(numbers('[gd_scene format=3]\n\n'+"\n".join(self.ext+self.sub+self.nodes)),encoding="utf-8",newline="\n")


s=Scene()
architecture=s.external("PackedScene","res://assets/models/helix_mission_map.glb")
leaf=s.external("PackedScene","res://assets/models/helix_mission_leaf.glb")
terminal=s.external("PackedScene","res://assets/models/helix_mission_relay.glb")
medical=s.external("PackedScene","res://assets/models/helix_mission_medical.glb")
cover=s.external("PackedScene","res://scenes/cover.tscn")
storage=s.external("PackedScene","res://scenes/tower.tscn")
target=s.external("PackedScene","res://scenes/target.tscn")
gate_script=s.external("Script","res://missions/relay_run/gate.gd")
door_sound=s.external("AudioStream","res://audio/door_open.wav")
relay_sound=s.external("AudioStream","res://audio/relay_activate.wav")
denied_sound=s.external("AudioStream","res://audio/interaction_denied.wav")
repair_sound=s.external("AudioStream","res://audio/repair_pickup.wav")
environment=s.external("Environment","res://environment/space.tres")
roofs=s.external("PackedScene","res://environment/mission_roofs.tscn")
s.node("Arena",kind="Node3D",process_mode=1)
s.node("Architecture",".",instance=architecture)
s.node("WorldEnvironment",".","WorldEnvironment",environment=environment)
s.node("Plafonds",".",instance=roofs)
s.node("Soleil",".","DirectionalLight3D",rotation=vec(-1,-.6,0),light_color="Color(.52,.68,1,1)",light_energy=.65,shadow_enabled="true",directional_shadow_max_distance=160)
for i,(x,z,w,d) in enumerate(LAYOUT["floors"]): s.body("Floor%02d"%i,(x+w/2,-.5,z+d/2),(w,1,d))
for name,x,z,length,height,axis in LAYOUT["walls"]:
    s.body(name,(x,height/2,z),(length,height,1) if axis=="x" else (1,height,length))
for i,(x,z) in enumerate(LAYOUT["covers"]): s.node("Cover%02d"%i,".",instance=cover,position=vec(x,0,z))
for i,(x,z,sx,sy,sz) in enumerate(LAYOUT["storage"]): s.node("Storage%02d"%i,".",instance=storage,position=vec(x,0,z),scale=vec(sx,sy,sz))
for name,x,y,z,w,h,d,angle in LAYOUT["platforms"]:
    s.body(name,(x,y,z),(w,h,d),rotation=(0,0,angle))
for i,x in enumerate([-8,8]): s.node("Training%02d"%i,".",instance=target,position=vec(x,0,62),target_name=q("ESSAI %02d"%(i+1)))
s.node("Medical",".","Node3D")
for i,(x,z) in enumerate(LAYOUT["medical"]):
    path="Medical/Kit%d"%i
    s.node("Kit%d"%i,"Medical","Node3D",position=vec(x,0,z))
    s.node("Visual",path,instance=medical)
    s.node("PickupSound",path,"AudioStreamPlayer3D",position=vec(0,.6,0),stream=repair_sound,volume_db=-9,unit_size=4,max_distance=20)
    s.label("Label",(0,1.1,0),"REPARATION +40",path,font=25,billboard=1)
x,z=LAYOUT["reactor"]
s.body("ReactorBase",(x,.2,z),(6,.4,6))
s.node("ReactorCore",".","StaticBody3D",position=vec(x,2.2,z),collision_layer=1,collision_mask=2)
s.sub.append('[sub_resource type="CylinderShape3D" id="reactor_shape"]\nradius = 1.8\nheight = 3.6\n')
s.node("CollisionShape3D","ReactorCore","CollisionShape3D",shape='SubResource("reactor_shape")')
for side in [-3.2,3.2]: s.body("PylonLeft" if side<0 else "PylonRight",(x+side,2.3,z),(.4,4.6,.7))
s.node("ReactorLight",".","OmniLight3D",position=vec(x,4.4,z),light_color="Color(.15,.83,1,1)",light_energy=3,omni_range=10)
s.node("Gates",".","Node3D")
for i,(x,z) in enumerate(LAYOUT["gates"]):
    path="Gates/Gate%d"%i
    s.node("Gate%d"%i,"Gates","Node3D",position=vec(x,0,z),script=gate_script)
    s.node("OpenSound",path,"AudioStreamPlayer3D",position=vec(0,2,0),stream=door_sound,volume_db=-3,unit_size=24,max_distance=140)
    s.body("Barrier",(0,2.5,0),(6,5,.5),path)
    s.node("Left",path,instance=leaf,position=vec(-1.5,0,0))
    s.node("Right",path,instance=leaf,position=vec(1.5,0,0))
    s.label("Label",(0,5.25,.65),"ACCES VERROUILLE",path,font=34)
    s.body("GateBeam%d"%i,(x,6.1,z),(6,1.8,1))
    s.label("SectorSign%d"%i,(x,6.35,z+.56),["02 / REFROIDISSEMENT","03 / COEUR HELIX","04 / EXTRACTION"][i],font=40)
for i,(x,z,title) in enumerate([(-25.4,53,"ANNEXE LOGISTIQUE"),(33.4,10,"MAINTENANCE TECHNIQUE"),(-33.4,-38,"CENTRALE ENERGIE")]):
    s.label("AnnexeSign%d"%i,(x,5.7,z),title,font=30,rotation=vec(0,1.5707963,0))
s.node("Relays",".","Node3D")
for i,(x,z) in enumerate(LAYOUT["relays"]):
    path="Relays/Relay%d"%i
    s.node("Relay%d"%i,"Relays","Node3D",position=vec(x,0,z))
    s.node("Visual",path,instance=terminal)
    s.body("Body",(0,.7,0),(1,1.4,.8),path)
    s.node("Interaction",path,"Marker3D",position=vec(0,1.15,.55))
    s.node("ActivationSound",path,"AudioStreamPlayer3D",position=vec(0,1.1,0),stream=relay_sound,volume_db=-8,unit_size=4,max_distance=28)
    s.node("DeniedSound",path,"AudioStreamPlayer3D",position=vec(0,1.1,0),stream=denied_sound,volume_db=-11,unit_size=4,max_distance=16)
    s.label("Label",(0,2.05,0),LAYOUT["relay_names"][i],path,font=28,billboard=1)
    s.node("Light",path,"OmniLight3D",position=vec(0,1.5,.65),light_color="Color(.15,.85,1,1)",light_energy=.6,omni_range=3)
ex,ez=LAYOUT["extraction"]
s.label("ExtractionLabel",(ex,2.5,ez),"EXTRACTION",font=45,billboard=1)
s.label("Welcome",(0,4.5,70.4),"QUAI 04 / DEPART",font=48,rotation=vec(0,3.14159265,0))
s.label("Tutorial",(0,3.8,52.6),"01  /  CARGO\nSUIVEZ LA LIGNE CYAN",font=38)
s.save("map.tscn")

# Conserver le langage visuel et les chemins des composants du HUD d'entraînement.
source=(PROJECT/"scenes/main.tscn").read_text(encoding="utf-8")
source=re.sub(r' uid="[^"]+"','',source)
source=re.sub(r' unique_id=\d+','',source)
source=source.replace('res://scripts/main.gd','res://missions/relay_run/mission.gd').replace('res://scenes/arena.tscn','res://missions/relay_run/map.tscn').replace('res://scripts/drone_director.gd','res://missions/relay_run/director.gd')
source=source.replace('[node name="Main"','[node name="Mission"')
source=source.replace('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.005817771, 0, -0.0031785965)','position = Vector3(0,0,0)')
source=source.replace('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.05, 18)','position = '+vec(*LAYOUT["spawn"]))
records=re.split(r'(?=^\[)',source,flags=re.M)
source=''.join(r for r in records if not r.startswith('[node name="Sentinelle'))
drone_nodes=''
hound_spawns={index:(x,z) for index,x,z in LAYOUT["hound_spawns"]}
for i,(x,z,sector) in enumerate(LAYOUT["drones"]):
    is_hound=i in hound_spawns
    if is_hound: x,z=hound_spawns[i]
    kind="hound" if is_hound else "drone"
    title=f"LIMIER K-9 / {sector+1:02d}" if is_hound else f"SENTINELLE {i+1:02d}"
    drone_nodes+=f'\n[node name="Sentinelle{i+1:02d}" parent="Drones" instance=ExtResource("{kind}")]\nposition = {vec(x,.05 if is_hound else 2.4,z)}\ndrone_name = {q(title)}\ninitial_delay = {2.4+i*.15}\nfire_interval = 3.1\norbit_direction = {1.0 if i%2==0 else -1.0}\nmetadata/sector = {sector}\n'
source=source.replace('[node name="Projectiles"',drone_nodes+'\n[node name="Projectiles"')
boss_nodes='''[node name="BossEncounter" type="Node3D" parent="."]
process_mode = 1
script = ExtResource("boss_director")

[node name="Cerbere" parent="BossEncounter" instance=ExtResource("boss")]
position = Vector3(0,4.2,-68)
rotation = Vector3(0,3.14159265,0)

'''
source=source.replace('[node name="Projectiles"',boss_nodes+'[node name="Projectiles"')
extra_ext='''[ext_resource type="Script" path="res://missions/relay_run/minimap.gd" id="mini_map"]
[ext_resource type="PackedScene" path="res://scenes/boss.tscn" id="boss"]
[ext_resource type="Script" path="res://scripts/boss_director.gd" id="boss_director"]

'''
source=source.replace('[sub_resource',extra_ext+'[sub_resource',1)
style='''[sub_resource type="StyleBoxFlat" id="mission_panel"]
bg_color = Color(.025,.065,.088,.92)
border_width_left = 2
border_color = Color(.21,.78,.78,.8)
content_margin_left = 16.0
content_margin_right = 16.0
content_margin_top = 14.0
content_margin_bottom = 14.0
corner_radius_top_left = 6
corner_radius_top_right = 6
corner_radius_bottom_left = 6
corner_radius_bottom_right = 6

'''
source=source.replace('[node name="Mission"',style+'[node name="Mission"',1)
boss_style='''[sub_resource type="StyleBoxFlat" id="boss_fill"]
bg_color = Color(.95,.16,.045,1)
corner_radius_top_left = 3
corner_radius_top_right = 3
corner_radius_bottom_left = 3
corner_radius_bottom_right = 3

[sub_resource type="StyleBoxFlat" id="boss_back"]
bg_color = Color(.12,.04,.035,1)
corner_radius_top_left = 3
corner_radius_top_right = 3
corner_radius_bottom_left = 3
corner_radius_bottom_right = 3

'''
source=source.replace('[node name="Mission"',boss_style+'[node name="Mission"',1)
source+='''
[node name="MissionHUD" type="Control" parent="Interface"]
visible = false
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
theme = SubResource("r8")

[node name="Objective" type="PanelContainer" parent="Interface/MissionHUD"]
offset_left = 42.0
offset_top = 188.0
offset_right = 435.0
offset_bottom = 370.0
mouse_filter = 2
theme_override_styles/panel = SubResource("mission_panel")

[node name="Content" type="VBoxContainer" parent="Interface/MissionHUD/Objective"]
layout_mode = 2
theme_override_constants/separation = 8
mouse_filter = 2

[node name="Kicker" type="Label" parent="Interface/MissionHUD/Objective/Content"]
layout_mode = 2
theme_override_font_sizes/font_size = 14
theme_override_colors/font_color = Color(1,.62,.33,1)
text = "OBJECTIF 01 / 05"

[node name="Title" type="Label" parent="Interface/MissionHUD/Objective/Content"]
layout_mode = 2
theme_override_font_sizes/font_size = 22
text = "Rétablir le relais cargo"
autowrap_mode = 2

[node name="Task" type="Label" parent="Interface/MissionHUD/Objective/Content"]
layout_mode = 2
theme_override_font_sizes/font_size = 17
autowrap_mode = 2
text = "Rejoignez le secteur."

[node name="Progress" type="Label" parent="Interface/MissionHUD/Objective/Content"]
layout_mode = 2
theme_override_font_sizes/font_size = 14
theme_override_colors/font_color = Color(.3,.94,.84,1)
text = "RELAIS 0 / 3"

[node name="MapPanel" type="Panel" parent="Interface/MissionHUD"]
anchor_left = 1.0
anchor_right = 1.0
offset_left = -235.0
offset_right = -42.0
offset_top = 188.0
offset_bottom = 466.0
mouse_filter = 2
theme_override_styles/panel = SubResource("mission_panel")

[node name="Title" type="Label" parent="Interface/MissionHUD/MapPanel"]
offset_left = 12.0
offset_top = 10.0
theme_override_font_sizes/font_size = 13
text = "CARTE  /  N ↑"

[node name="MiniMap" type="Control" parent="Interface/MissionHUD/MapPanel"]
offset_top = 27.0
offset_right = 193.0
offset_bottom = 277.0
mouse_filter = 2
script = ExtResource("mini_map")

[node name="Interaction" type="Label" parent="Interface/MissionHUD"]
anchor_left = .5
anchor_right = .5
anchor_top = 1.0
anchor_bottom = 1.0
offset_left = -370.0
offset_right = 370.0
offset_top = -164.0
offset_bottom = -128.0
horizontal_alignment = 1
theme_override_font_sizes/font_size = 22
theme_override_colors/font_color = Color(.3,1,.85,1)
theme_override_colors/font_shadow_color = Color(0,0,0,1)
theme_override_constants/shadow_offset_x = 2
theme_override_constants/shadow_offset_y = 2

[node name="Toast" type="Label" parent="Interface/MissionHUD"]
anchor_left = .5
anchor_right = .5
anchor_top = 1.0
anchor_bottom = 1.0
offset_left = -490.0
offset_right = 490.0
offset_top = -212.0
offset_bottom = -175.0
horizontal_alignment = 1
autowrap_mode = 2
theme_override_font_sizes/font_size = 17
theme_override_colors/font_color = Color(.75,.97,.94,1)
'''
source+='''
[node name="Boss" type="PanelContainer" parent="Interface/MissionHUD"]
visible = false
anchor_left = .5
anchor_right = .5
offset_left = -275.0
offset_right = 275.0
offset_top = 140.0
offset_bottom = 237.0
mouse_filter = 2
theme_override_styles/panel = SubResource("mission_panel")

[node name="Content" type="VBoxContainer" parent="Interface/MissionHUD/Boss"]
layout_mode = 2
theme_override_constants/separation = 5
mouse_filter = 2

[node name="Name" type="Label" parent="Interface/MissionHUD/Boss/Content"]
layout_mode = 2
text = "CERBÈRE  /  HELIX M-90"
horizontal_alignment = 1
theme_override_font_sizes/font_size = 20
theme_override_colors/font_color = Color(1,.58,.38,1)

[node name="Health" type="ProgressBar" parent="Interface/MissionHUD/Boss/Content"]
layout_mode = 2
custom_minimum_size = Vector2(0,12)
mouse_filter = 2
show_percentage = false
max_value = 44.0
value = 44.0
theme_override_styles/fill = SubResource("boss_fill")
theme_override_styles/background = SubResource("boss_back")

[node name="Phase" type="Label" parent="Interface/MissionHUD/Boss/Content"]
layout_mode = 2
horizontal_alignment = 1
text = "PHASE 1  ·  DOUBLE MITRAILLEUSE"
theme_override_font_sizes/font_size = 13
theme_override_colors/font_color = Color(1,.7,.55,1)
'''
# L'interaction rejoint la deuxième ligne pour garder le tir lisible à petite taille.
source=source.replace("CTRL S'accroupir\"","CTRL S'accroupir  ·  E Activer\"")
(DEST/"mission.tscn").write_text(numbers(source),encoding="utf-8",newline="\n")
print(f"Scènes de mission générées : {len(LAYOUT['floors'])} zones, 3 relais, 3 portes et {len(LAYOUT['drones'])} sentinelles.")

# Extension permanente du deuxième étage.
import runpy
runpy.run_path(str(ROOT/"art/campaign/build_campaign.py"))
