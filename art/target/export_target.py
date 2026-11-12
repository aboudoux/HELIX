"""Exporter les deux parties de la cible depuis la source Blender enregistrée."""
from pathlib import Path
import json
import sys
import bpy

ART=Path(__file__).resolve().parent
sys.path.insert(0,str(ART.parent/"arena"))
from export_arena import export_model


def export_assets():
    selected=list(bpy.context.selected_objects)
    active=bpy.context.view_layer.objects.active
    result={"name":"HELIX T-07","blender":bpy.app.version_string,"units":"meters",
            "up":"+Y","front":"+Z","plate_pivot_godot":[0,1,0],
            "disk_center_from_pivot":[0,.65,0],"collision_radius":.65,"collision_depth":.16,
            "assets":[]}
    for name,filename in [("TargetBase","helix_target_base.glb"),("TargetPlate","helix_target_plate.glb")]:
        source=bpy.data.objects.get(name)
        if source is None:
            raise RuntimeError("Source manquante : "+name)
        result["assets"].append(export_model(source,filename))
    (ART/"asset-info.json").write_text(json.dumps(result,indent=2),encoding="utf-8")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in selected:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=active
    print("HELIX_TARGET",json.dumps(result))
    return result


if __name__=="__main__":
    export_assets()
