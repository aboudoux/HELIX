"""Extension éditable de la mission : ascenseur physique et deuxième étage à +14 m.
Appelé à la fin du générateur historique, qui reste la source du premier niveau.
"""
from pathlib import Path
import json,re,math
ROOT=Path(__file__).resolve().parents[2]; P=ROOT/'DroneArena'; D=P/'missions/relay_run'
def vec(*x):return 'Vector3('+', '.join(map(str,x))+')'
def q(x):return json.dumps(x,ensure_ascii=False)
class Scene:
 def __init__(self):self.ext=[];self.sub=[];self.nodes=[];self.cache={}
 def extres(self,kind,path):
  id='e'+str(len(self.ext));self.ext.append(f'[ext_resource type="{kind}" path="{path}" id="{id}"]');return f'ExtResource("{id}")'
 def subres(self,kind,props):
  key=(kind,str(props))
  if key not in self.cache:
   id='r'+str(len(self.sub));self.sub.append(f'[sub_resource type="{kind}" id="{id}"]\n'+''.join(f'{k} = {v}\n' for k,v in props.items()));self.cache[key]=f'SubResource("{id}")'
  return self.cache[key]
 def node(self,name,parent=None,kind=None,instance=None,**props):
  h=f'[node name="{name}"'+(f' type="{kind}"' if kind else '')+(f' parent="{parent}"' if parent is not None else '')+(f' instance={instance}' if instance else '')+']'
  self.nodes.append(h+'\n'+''.join(f'{k} = {v}\n' for k,v in props.items()))
 def mat(self,color,metal=.6,glow=0,glass=False):
  props={'albedo_color':'Color('+','.join(map(str,color))+')','metallic':metal,'roughness':.4}
  if glow:props.update(emission_enabled='true',emission='Color('+','.join(map(str,color))+')',emission_energy_multiplier=glow)
  if glass:props.update(transparency=1,cull_mode=2)
  return self.subres('StandardMaterial3D',props)
 def block(self,name,pos,size,mat,parent='.',solid=False):
  if solid:
   self.node(name,parent,'StaticBody3D',position=vec(*pos),collision_layer=1,collision_mask=2)
   path=parent+'/'+name if parent!='.' else name
   self.node('CollisionShape3D',path,'CollisionShape3D',shape=self.subres('BoxShape3D',{'size':vec(*size)}))
   if name not in ['Barrier','Body']:self.node('Skin',path,'MeshInstance3D',mesh=self.subres('BoxMesh',{'size':vec(*size)}),material_override=mat)
  else:self.node(name,parent,'MeshInstance3D',position=vec(*pos),mesh=self.subres('BoxMesh',{'size':vec(*size)}),material_override=mat)
 def label(self,name,pos,text,parent='.',size=45,**props):
  self.node(name,parent,'Label3D',position=vec(*pos),text=q(text),font_size=size,pixel_size=.009,outline_size=4,modulate='Color(0.4,0.95,0.9,1)',**props)
 def save(self,path):
  txt='[gd_scene format=3]\n\n'+'\n\n'.join(self.ext+self.sub+self.nodes)
  txt=re.sub(r'(?<![\w\d])(-?)\.(\d)',r'\g<1>0.\2',txt)
  path.write_text(txt,encoding='utf-8',newline='\n')
# Upper navigation footprint (separate plane, no link to the floor below).
floors=[[-12,-98,24,16],[-34,-142,68,44],[-42,-174,84,32],[-46,-220,92,46],[-12,-236,24,16]]
upper={'floors':floors,'floor_names':['ASCENSEUR / ETAGE 02','CHENIL DE SECURITE','USINE DES LIMIERS','ANTRE DE FENRIR','EXTRACTION ORBITALE'],'floor_sector':[0,0,1,2,3],'nav_bounds':[-47,-237,95,156], 'relays':[[-26,-132],[32,-164]],'gates':[[0,-142],[0,-174],[0,-220]],'extraction':[0,-230]}
(D/'upper_layout.json').write_text(json.dumps(upper,indent=2,ensure_ascii=False),encoding='utf-8')
(D/'alpha_layout.json').write_text(json.dumps({'floors':[floors[3]],'nav_bounds':[-42,-215,85,37]}),encoding='utf-8')
s=Scene();dark=s.mat((.035,.055,.075,1));panel=s.mat((.18,.24,.29,1));ivory=s.mat((.6,.66,.68,1));orange=s.mat((.95,.22,.035,1));cyan=s.mat((.12,.88,.92,1),glow=3);red=s.mat((1,.025,.08,1),glow=3);glass=s.mat((.12,.35,.45,.09),.25,glass=True)
cover=s.extres('PackedScene','res://scenes/cover.tscn');tower=s.extres('PackedScene','res://scenes/tower.tscn');leaf=s.extres('PackedScene','res://assets/models/helix_mission_leaf.glb');relay=s.extres('PackedScene','res://assets/models/helix_mission_relay.glb');medical=s.extres('PackedScene','res://assets/models/helix_mission_medical.glb');gate=s.extres('Script','res://missions/relay_run/gate.gd');door=s.extres('AudioStream','res://audio/door_open.wav');confirm=s.extres('AudioStream','res://audio/relay_activate.wav');denied=s.extres('AudioStream','res://audio/interaction_denied.wav');repair=s.extres('AudioStream','res://audio/repair_pickup.wav')
s.node('UpperArena',kind='Node3D',process_mode=1)
deck_shader=s.extres('Shader','res://missions/relay_run/deck_panels.gdshader')
deck=s.subres('ShaderMaterial',{'shader':deck_shader})
# Landing includes an actual opening for the 6 x 8 m lift.
plates=[[-12,-98,9,16],[3,-98,9,16],[-3,-98,6,4],[-3,-86,6,4]]+floors[1:]
for i,(x,z,w,d) in enumerate(plates):s.block('Deck%02d'%i,(x+w/2,13.65,z+d/2),(w,.7,d),deck,solid=True)
# Segment side walls follow the widened footprint. Floor edges are always fenced.
for i,(x,z,w,d) in enumerate(floors):
 for side in [x,x+w]:
  s.block(f'Wall{i}_{side}',(side,17.5,z+d/2),(.6,7,d),dark,solid=True)
  for zz in range(int(z)+3,int(z+d),7):
   s.block(f'Rib{i}_{side}_{zz}',(side,18,zz),(1,8,.35),ivory)
   s.block(f'WallNeon{i}_{side}_{zz}',(side+(.34 if side<0 else -.34),18,zz),(.055,2.8,.14),cyan if i<3 else red)
 # Sealed wall shoulders at each change of width; six metre doors on interior partitions.
 if i in [2,3,4]:
  for sx in [-1,1]:
   half=max(w,floors[i-1][2])/2-3
   s.block(f'Bulkhead{i}_{sx}',(sx*(3+half/2),17.5,z+d),(half,7,.6),dark,solid=True)
 elif i==1:
  for sx in [-1,1]:s.block(f'LandingShoulder{sx}',(sx*23,17.5,-98),(22,7,.6),dark,solid=True)
 # Ceiling: opaque services on both edges, star-view canopy down the centre.
 roof=24 if i==3 else 22
 for sx in [-1,1]:
  s.block(f'ServiceRoof{i}_{sx}',(sx*(w/2-4),roof,z+d/2),(8,.35,d),dark)
  s.block(f'RoofNeon{i}_{sx}',(sx*(w/2-8),roof-.2,z+d/2),(.12,.08,d-.5),cyan if i!=3 else red)
 s.block(f'Canopy{i}',(0,roof,z+d/2),(max(w-16,4),.08,d),glass)
 for zz in range(int(z),int(z+d)+1,8):
  s.block(f'RoofBeam{i}_{zz}',(0,roof+.08,zz),(w,.4,.4),panel)
 for sx in [-1,1]:
  for zz in range(int(z)+5,int(z+d),15):
   s.node(f'Light{i}_{sx}_{zz}','.','OmniLight3D',position=vec(sx*(w/2-7),roof-2,zz),light_color='Color(0.45,0.72,1,1)',light_energy=2.8,omni_range=18)
# Panneaux de maintenance, ouïes, fixations et conduites sur les murs.
for i,(x,z,w,d) in enumerate(floors[1:4],1):
 for side in [-1,1]:
  xx=side*(w/2-.38)
  for j,zz in enumerate(range(int(z)+4,int(z+d)-2,7)):
   n=f'Panel{i}_{side}_{j}'
   s.block(n+'Back',(xx,16.8,zz),(.09,3.6,5.5),panel)
   s.block(n+'Face',(xx-side*.06,17.1,zz),(.06,2.6,4.8),ivory)
   s.block(n+'Inset',(xx-side*.105,16.9,zz),(.035,1.1,3.9),dark)
   s.block(n+'Orange',(xx-side*.105,18.15,zz),(.035,.12,4.8),orange)
   for v in range(6):s.block(n+f'Vent{v}',(xx-side*.13,16.9,zz-1.5+v*.6),(.035,.6,.12),panel)
   for yy in [15.35,18.25]:
    for oz in [-2.45,2.45]:s.block(n+f'Bolt{yy}_{oz}',(xx-side*.1,yy,zz+oz),(.045,.09,.09),orange)
   s.block(n+'Conduit',(xx-side*.12,14.65,zz),(.12,.17,6.8),panel)

# Width transitions need side caps at the north edge of each widened hall.
for i in [1,2,3]:
 x,z,w,d=floors[i];prevw=floors[i-1][2]
 for sx in [-1,1]:s.block(f'Cap{i}_{sx}',(sx*(prevw/2+(w-prevw)/4),17.5,z+d),((w-prevw)/2,7,.6),dark,solid=True)
s.block('SouthLanding',(0,17.5,-82),(24,7,.6),dark,solid=True)
s.block('NorthExtraction',(0,17.5,-236),(24,7,.6),dark,solid=True)
# Walkways, floor joints and orange safety markings.
for i,(x,z,w,d) in enumerate(floors):
 for sx in [-1,1]:s.block(f'Path{i}_{sx}',(sx*3.6,14.025,z+d/2),(.1,.035,d-.8),cyan)
 for zz in range(int(z)+2,int(z+d),6):s.block(f'Expansion{i}_{zz}',(0,14.015,zz),(w-.8,.02,.045),dark)
for i,(x,z) in enumerate([(-16,-110),(17,-118),(-12,-125),(15,-135),(-25,-150),(23,-151),(-18,-164),(18,-168),(-25,-184),(25,-184),(-25,-207),(25,-207)]):
 s.node(f'Cover{i}','.',instance=cover,position=vec(x,14,z))
for i,(x,z) in enumerate([(-29,-116),(29,-128),(-36,-154),(36,-160),(-40,-194),(40,-194)]):
 s.node(f'Rack{i}','.',instance=tower,position=vec(x,14,z),scale=vec(1.4,1.4,1.4))
 # Open robot maintenance bays, deliberately kept out of the central route.
 s.block(f'Bay{i}',(x,14.08,z+4),(6,.16,4),dark)
 for side in [-2.7,2.7]:s.block(f'BayFrame{i}_{side}',(x+side,16,z+4),(.22,4,.25),orange)
 s.block(f'BayBeam{i}',(x,18,z+4),(5.6,.22,.25),ivory)
 s.label(f'BayLabel{i}',(x,18.5,z+4.1),'K-9 / MAINTENANCE',size=23)
s.node('Gates','.','Node3D')
for i,(x,z) in enumerate(upper['gates']):
 p=f'Gates/Gate{i}';s.node(f'Gate{i}','Gates','Node3D',position=vec(x,14,z),script=gate)
 s.node('OpenSound',p,'AudioStreamPlayer3D',position=vec(0,2,0),stream=door,volume_db=-3,unit_size=20,max_distance=100)
 s.block('Barrier',(0,2.5,0),(6,5,.5),dark,p,solid=True)
 for n,xx in [('Left',-1.5),('Right',1.5)]:s.node(n,p,instance=leaf,position=vec(xx,0,0))
 s.label('Label',(0,5.25,.65),'VERROU SECURITE',p,size=32)
 s.block(f'Lintel{i}',(0,20,z),(6,2,.6),panel,solid=True)
 s.label(f'Sector{i}',(0,21.5,z+.4),['USINE / VERROU 01','FENRIR / VERROU 02','EXTRACTION ORBITALE'][i],size=40)
s.node('Relays','.','Node3D')
for i,(x,z) in enumerate(upper['relays']):
 p=f'Relays/Relay{i}';s.node(f'Relay{i}','Relays','Node3D',position=vec(x,14,z));s.node('Visual',p,instance=relay)
 s.block('Body',(0,.7,0),(1,1.4,.8),panel,p,solid=True)
 s.node('Interaction',p,'Marker3D',position=vec(0,1.15,.55));s.label('Label',(0,2.1,0),'VERROU 0'+str(i+1),p,size=26,billboard=1)
 for name,aud,vol in [('ActivationSound',confirm,-8),('DeniedSound',denied,-11)]:s.node(name,p,'AudioStreamPlayer3D',stream=aud,volume_db=vol,unit_size=4,max_distance=28)
s.node('Medical','.','Node3D')
for i,(x,z) in enumerate([(8,-100),(-28,-138),(35,-170),(-10,-178)]):
 p=f'Medical/Kit{i}';s.node(f'Kit{i}','Medical','Node3D',position=vec(x,14,z));s.node('Visual',p,instance=medical);s.label('Label',(0,1.1,0),'REPARATION +40',p,size=23,billboard=1);s.node('PickupSound',p,'AudioStreamPlayer3D',stream=repair,volume_db=-9,unit_size=4,max_distance=20)
s.label('Welcome',(0,18.5,-100),'ETAGE 02 / LE CHENIL\nLES LIMIERS PROTEGENT LEUR ALPHA',size=48)
s.label('Fenrir',(0,21,-215),'F E N R I R\nHELIX ALPHA / DANGER EXTREME',size=65)
s.label('Exit',(0,17,-230),'EXTRACTION\nMAINTENEZ LA POSITION',size=45,billboard=1)
s.block('ExtractionPad',(0,14.04,-230),(9,.06,9),dark)
for xx in [-4.5,4.5]:s.block(f'ExitStrip{xx}',(xx,14.08,-230),(.15,.1,9),cyan)
for zz in [-234.5,-225.5]:s.block(f'ExitEnd{zz}',(0,14.08,zz),(9,.1,.15),cyan)
s.save(D/'upper_map.tscn')
# Elevator cab, rail shaft and moving floor share a physics body.
s=Scene();dark=s.mat((.035,.055,.075,1));steel=s.mat((.24,.32,.38,1));cyan=s.mat((.12,.88,.92,1),glow=3);orange=s.mat((.95,.22,.035,1));glass=s.mat((.12,.35,.45,.15),.3,glass=True)
script=s.extres('Script','res://missions/relay_run/elevator.gd');motor=s.extres('AudioStream','res://audio/elevator_motor.wav');bell=s.extres('AudioStream','res://audio/elevator_bell.wav');door=s.extres('AudioStream','res://audio/door_open.wav')
s.node('Elevator',kind='Node3D',process_mode=1,script=script)
s.node('Cab','.','AnimatableBody3D',collision_layer=1,collision_mask=2,sync_to_physics='true')
for name,pos,size in [('Floor',(0,-.25,0),(6,.5,8)),('West',(-3,2,0),(.2,4,8)),('East',(3,2,0),(.2,4,8)),('Roof',(0,4.1,0),(6,.2,8))]:
 s.node(name+'Shape','Cab','CollisionShape3D',position=vec(*pos),shape=s.subres('BoxShape3D',{'size':vec(*size)}));s.block(name+'Skin',pos,size,dark if name in ['Floor','Roof'] else glass,'Cab')
for name,z in [('South',4),('North',-4)]:
 s.node(name+'Block','Cab','CollisionShape3D',position=vec(0,2,z),shape=s.subres('BoxShape3D',{'size':vec(6,4,.2)}))
 s.node(name+'Door','Cab','Node3D',position=vec(0,0,z))
 s.block('Panel',(0,2,0),(6,4,.16),steel,'Cab/'+name+'Door')
 for x in [-2.8,2.8]:s.block('Neon'+str(x),(x,2,.12),(.08,3.7,.04),cyan,'Cab/'+name+'Door')
 s.label('DeckSign',(0,3.1,.15),'HELIX / ASCENSEUR','Cab/'+name+'Door',size=28)
for x in [-2.7,2.7]:s.block('Safety'+str(x),(x,.025,0),(.12,.05,7.7),orange,'Cab')
s.block('Console',(2.7,1.25,2.8),(.3,.9,.7),steel,'Cab');s.block('Button',(2.51,1.45,2.8),(.04,.2,.25),cyan,'Cab')
s.label('CabHelp',(0,1.9,-3.8),'E / MONTER','Cab',size=26)
s.label('Sign',(0,5,4.2),'ASCENSEUR VERROUILLE\nNEUTRALISEZ CERBERE',size=38)
for x in [-3.5,3.5]:
 for z in [-4.3,4.3]:
  s.block(f'Rail{x}_{z}',(x,9,z),(.22,18,.24),steel)
  s.block(f'Guide{x}_{z}',(x+.15,9,z),(.045,18,.08),cyan)
for name,stream,pos,vol in [('Motor',motor,(0,2,0),-8),('Bell',bell,(0,3,0),-8),('DoorSound',door,(0,2,0),-6)]:s.node(name,'.','AudioStreamPlayer3D',position=vec(*pos),stream=stream,volume_db=vol,unit_size=10,max_distance=40)
s.save(D/'elevator.tscn')
# Dedicated FENRIR scene uses the authored GLB and the shared articulated hound rig.
src=(P/'scenes/hound.tscn').read_text(encoding='utf-8').replace('res://scripts/hound.gd','res://scripts/fenrir.gd').replace('helix_hound.glb','helix_fenrir.glb').replace('name="Limier"','name="Fenrir"').replace('radius = 1.35','radius = 4.35').replace('height = 1.8','height = 4.9').replace('Vector3(0, 0.9, 0)','Vector3(0, 2.45, 0)').replace('Vector3(0.0, 1.9,','Vector3(0.0, 5.15,').replace('Vector3(0.0, 2.35,','Vector3(0.0, 5.8,').replace('Vector3(0.0, 2.12,','Vector3(0.0, 5.55,').replace('text = "LIMIER K-9"','text = "FENRIR / HELIX ALPHA"')
src=src.replace('script = ExtResource("e1")','script = ExtResource("e1")\ndrone_name = "FENRIR / HELIX ALPHA"\npreferred_range = 12.0\nwreck_mass = 650.0\nheavy_wreck = true\nmax_health = 85\n')
for name in ['NameTag','State','HealthBack','HealthFill']:
 src=re.sub(r'(\[node name="'+name+r'"[^\n]*\]\n)',r'\1visible = false\n',src)
(P/'scenes/fenrir.tscn').write_text(src,encoding='utf-8',newline='\n')
# Hook the new components into the regenerated mission, preserving all original paths.
f=D/'mission.tscn';src=f.read_text(encoding='utf-8')
ext=''
for kind,path,id in [('PackedScene','upper_map.tscn','upper_map'),('PackedScene','elevator.tscn','lift'),('Script','director.gd','upper_director'),('Script','alpha_director.gd','alpha_director'),('PackedScene','res://scenes/fenrir.tscn','fenrir')]:
 if not path.startswith('res:'):path='res://missions/relay_run/'+path
 ext+=f'[ext_resource type="{kind}" path="{path}" id="{id}"]\n'
src=src.replace('[sub_resource',ext+'\n[sub_resource',1)
nodes='''[node name="UpperArena" parent="." instance=ExtResource("upper_map")]

[node name="Elevator" parent="." instance=ExtResource("lift")]
position = Vector3(0,0,-90)

[node name="UpperDrones" type="Node3D" parent="."]
process_mode = 1
script = ExtResource("upper_director")
layout_path = "res://missions/relay_run/upper_layout.json"
floor_height = 14.0
flight_height = 16.4

'''
spawns=[(-19,-113,0,False),(20,-125,0,False),(-23,-128,0,True),(14,-109,0,True),(4,-135,0,True),(-26,-151,1,False),(25,-160,1,False),(10,-149,1,True),(-12,-162,1,True),(31,-169,1,True)]
for i,(x,z,sector,hound) in enumerate(spawns):
 nodes+=f'[node name="UpperGuard{i:02d}" parent="UpperDrones" instance=ExtResource("{"hound" if hound else "drone"}")]\nposition = {vec(x,14.05 if hound else 16.4,z)}\ndrone_name = "{"LIMIER" if hound else "SENTINELLE"} / CHENIL {i+1:02d}"\ninitial_delay = {3+i*.12}\nfire_interval = 3.2\norbit_direction = {1.0 if i%2 else -1.0}\nmetadata/sector = {sector}\n\n'
nodes+='''[node name="AlphaEncounter" type="Node3D" parent="."]
process_mode = 1
script = ExtResource("alpha_director")
layout_path = "res://missions/relay_run/alpha_layout.json"
floor_height = 14.0
flight_height = 16.4
ground_radius = 4.6
ground_height = 4.9

[node name="Fenrir" parent="AlphaEncounter" instance=ExtResource("fenrir")]
position = Vector3(0,14.05,-204)
rotation = Vector3(0,3.14159265,0)
metadata/sector = 0

'''
src=src.replace('[node name="Projectiles"',nodes+'[node name="Projectiles"',1)
f.write_text(src,encoding='utf-8',newline='\n')
# The old exit is now the lift lobby; keep its collision floor intact.
f=D/'map.tscn';src=f.read_text(encoding='utf-8').replace('04 / EXTRACTION','04 / ASCENSEUR').replace('text = "EXTRACTION"','text = "ASCENSEUR / ETAGE 02"');f.write_text(src,encoding='utf-8',newline='\n')
print('Extension : 10 gardes, 2 verrous, FENRIR, +14 m, ascenseur 8 secondes.')
