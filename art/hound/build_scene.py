"""Créer le composant K-9 éditable ; le combat et le modèle restent séparés."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
project=ROOT/'DroneArena'
source=(project/'scenes/drone.tscn').read_text(encoding='utf-8')
source=source.replace('res://scripts/drone.gd','res://scripts/hound.gd').replace('res://assets/models/helix_sentinel.glb','res://assets/models/helix_hound.glb')
source=source.replace('res://audio/enemy_rifle.tres','res://audio/hound_laser.wav')
source=re.sub(r'\[ext_resource[^\n]+id="(?:rotor|rotor_audio)"\]\n','',source)
source=source.replace('[sub_resource type="BoxShape3D" id="r1"]\nsize = Vector3(1.8, 0.75, 1.5)', '[sub_resource type="CylinderShape3D" id="r1"]\nradius = 1.35\nheight = 1.8')
source=source.replace('[node name="Sentinelle" type="CharacterBody3D" groups=["enemies"]]', '[node name="Limier" type="CharacterBody3D" groups=["enemies", "hounds"]]')
source=source.replace('motion_mode = 1','motion_mode = 0')
source=source.replace('[node name="HitShape" type="CollisionShape3D" parent="."]','[node name="HitShape" type="CollisionShape3D" parent="."]\nposition = Vector3(0, 0.9, 0)')
source=re.sub(r'\[node name="Muzzle"[^\[]+','',source)
source=re.sub(r'\[node name="RotorSound"[\s\S]+','',source)
source=source.replace('Vector3(0.0, 0.56, -0.05)','Vector3(0.0, 1.9, -0.05)').replace('Vector3(0.0, 0.56, -0.07)','Vector3(0.0, 1.9, -0.07)')
source=source.replace('Vector3(0.0, 1.03, 0.0)','Vector3(0.0, 2.35, 0.0)').replace('Vector3(0.0, 0.79, 0.0)','Vector3(0.0, 2.12, 0.0)')
source=source.replace('text = "SENTINELLE 01"','text = "LIMIER K-9"')
source=source.replace('text = "HOSTILE"','text = "POURSUITE"')
source=source.replace('[sub_resource type="CylinderShape3D"', '[ext_resource type="AudioStream" path="res://audio/hound_step.wav" id="step"]\n[ext_resource type="AudioStream" path="res://audio/hound_charge.wav" id="charge"]\n\n[sub_resource type="CylinderShape3D"',1)
source+='''
[node name="StepSound" type="AudioStreamPlayer3D" parent="."]
stream = ExtResource("step")
volume_db = -13.0
unit_size = 5.0
max_distance = 30.0
max_polyphony = 2

[node name="ChargeSound" type="AudioStreamPlayer3D" parent="."]
stream = ExtResource("charge")
volume_db = -14.0
unit_size = 6.0
max_distance = 32.0
'''
(project/'scenes/hound.tscn').write_text(source,encoding='utf-8',newline='\n')
print('Scène LIMIER K-9 générée')
