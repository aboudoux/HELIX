# FENRIR / HELIX ALPHA

Boss quadrupède construit dans Blender, distinct du LIMIER K-9. Source modifiable : `helix_fenrir.blend`. GLB : `../../DroneArena/assets/models/helix_fenrir.glb`. Aperçu : `preview.png`.

La silhouette dépasse quatre mètres de haut et environ huit mètres de long : blindage céramique, châssis graphite, épaulières, pistons, griffes, mâchoire dentée, oreilles, queue segmentée, dorsale rouge et deux canons laser. Les quatre chaînes hanche/genou et le pivot de canon sont conservés dans le GLB ; les collisions restent dans Godot. Les sorties `LaserMuzzle` et `LaserMuzzleRight` sont utilisées par les vrais tirs.

`build_fenrir.py` reconstruit la source, exporte le GLB et rend l’aperçu. Cette commande remplace ces fichiers ; copiez vos variantes avant de la relancer :

```powershell
& '.tools/blender/blender-4.5.14-windows-x64/blender.exe' --background --python art/fenrir/build_fenrir.py
```

Le boss utilise `scripts/fenrir.gd`, `scenes/fenrir.tscn` et sa propre grille au deuxième étage. La visée est figée pendant les quatre lasers, puis six en seconde phase. Après neutralisation, le modèle entier devient une carcasse physique de 650 kg, conservée jusqu’au redémarrage. Le raccourci **Affronter Fenrir.cmd** permet d’essayer le boss sans refaire la campagne.
