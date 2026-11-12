@tool
extends EditorScenePostImport
## L'arme tenue devant la caméra conserve l'absence d'ombres de l'ancien modèle.
## Cette préparation est enregistrée à l'import, sans logique de jeu ajoutée.


func _post_import(scene: Node) -> Object:
	for mesh in scene.find_children("*", "GeometryInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return scene
