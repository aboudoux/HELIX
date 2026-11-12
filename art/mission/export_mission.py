"""Exporter la source Blender enregistrée sans la reconstruire."""
from pathlib import Path
import sys,json,bpy
ART=Path(__file__).resolve().parent
sys.path.insert(0,str(ART.parent/"arena"))
from export_arena import export_model

names=[("MissionArchitecture","helix_mission_map.glb"),
       ("GateLeaf","helix_mission_leaf.glb"),
       ("RelayModel","helix_mission_relay.glb"),
       ("RepairKit","helix_mission_medical.glb")]
result={"name":"Les trois relais","assets":[]}
for root,filename in names:
    source=bpy.data.objects.get(root)
    if source is None: raise RuntimeError("Racine manquante : "+root)
    result["assets"].append(export_model(source,filename))
(ART/"asset-info.json").write_text(json.dumps(result,indent=2),encoding="utf-8")
print("HELIX_MISSION",json.dumps(result))
