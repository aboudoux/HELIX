"""Exporter les sources ouvertes dans Blender sans reconstruire le décor.
Les pièces restent séparées dans le .blend ; seules les copies sont regroupées.
"""
from pathlib import Path
import json
import bpy
from mathutils import Matrix

ART=Path(__file__).resolve().parent
WORKSPACE=ART.parents[1]
OUTPUT=WORKSPACE/"DroneArena/assets/models"
ASSETS=[("ArenaArchitecture","helix_arena.glb"),
        ("Cover_A01","helix_cover.glb"),("Storage_C01","helix_storage.glb")]


def export_model(source, filename):
    bpy.context.view_layer.update()
    inverse=source.matrix_world.inverted()
    export=bpy.data.objects.new(source.name+"Visual",None)
    bpy.context.collection.objects.link(export)
    export["role"]="visual_only"
    export["collision_policy"]="Godot owns the original collision shapes"
    # Les secteurs gardent un découpage permettant le culling dans Godot.
    groups={}
    depsgraph=bpy.context.evaluated_depsgraph_get()
    # Évaluer les sources avant de lier les copies : lier une copie invalide
    # le graphe et forçait une réévaluation de toute la carte à chaque pièce.
    originals=[obj for obj in source.children_recursive if obj.type=="MESH"]
    evaluated=[obj.evaluated_get(depsgraph) for obj in originals]
    copies=[bpy.data.meshes.new_from_object(obj,depsgraph=depsgraph) for obj in evaluated]
    for original,data in zip(originals,copies):
        sector=original
        while sector.parent!=source:
            sector=sector.parent
        key=sector.name if sector.type=="EMPTY" else "Body"
        if key not in groups:
            group=bpy.data.objects.new("Visual_"+key,None)
            bpy.context.collection.objects.link(group)
            group.parent=export
            groups[key]=[group,{}]
        parent,materials=groups[key]
        duplicate=bpy.data.objects.new("Export_"+original.name,data)
        bpy.context.collection.objects.link(duplicate)
        duplicate.parent=parent
        duplicate.matrix_world=inverse@original.matrix_world
        materials.setdefault(data.materials[0].name,[]).append(duplicate)
    for parent,materials in groups.values():
        for mat_name,objects in materials.items():
            bpy.ops.object.select_all(action="DESELECT")
            for obj in objects:
                obj.select_set(True)
            bpy.context.view_layer.objects.active=objects[0]
            if len(objects)>1:
                bpy.ops.object.join()
            obj=objects[0]
            obj.name=parent.name+"_"+mat_name
            bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    objects=[export,*export.children_recursive]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=export
    OUTPUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT/filename),export_format="GLB",use_selection=True,
                              export_yup=True,export_animations=False,export_materials="EXPORT",
                              export_cameras=False,export_lights=False,export_extras=True)
    coords=[]
    triangles=0
    materials=set()
    for obj in objects:
        if obj.type=="MESH":
            obj.data.calc_loop_triangles()
            triangles+=len(obj.data.loop_triangles)
            coords.extend(obj.matrix_world@v.co for v in obj.data.vertices)
            materials.update(m.name for m in obj.data.materials)
    game=[(v.x,v.z,-v.y) for v in coords]
    result={"glb":filename,"triangles":triangles,"meshes":sum(o.type=="MESH" for o in objects),
            "materials":len(materials),"bounds_godot":[list(map(min,zip(*game))),list(map(max,zip(*game)))],
            "sectors":list(groups)}
    for obj in reversed(objects):
        bpy.data.objects.remove(obj,do_unlink=True)
    return result


def export_assets():
    # Une copie de la sélection est restaurée après l'export.
    selected=list(bpy.context.selected_objects)
    active=bpy.context.view_layer.objects.active
    result={"name":"HELIX / SECTEUR 07","blender":bpy.app.version_string,"units":"meters",
            "up":"+Y","assets":[]}
    for name,filename in ASSETS:
        source=bpy.data.objects.get(name)
        if source is None:
            raise RuntimeError("Source manquante : "+name)
        result["assets"].append(export_model(source,filename))
    (ART/"asset-info.json").write_text(json.dumps(result,indent=2),encoding="utf-8")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in selected:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=active
    print("HELIX_ARENA",json.dumps(result))
    return result


if __name__=="__main__":
    export_assets()
