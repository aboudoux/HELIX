# HELIX T-07 — cible d'entraînement

Cette cible originale reprend le style des drones, de la carabine et du décor : armure ivoire, châssis graphite, métal, repères orange et anneaux cyan. Le disque gradué possède une couronne en huit segments, des fixations, un centre lumineux et une trappe de maintenance à l'arrière. Le pied comporte une charnière, des vérins, un socle vissé et un voyant.

Les quatre cibles utilisent ces modèles. Leurs scripts restent inchangés : un tir les rabat, le collider est désactivé, le compteur et **TOUCHÉ** apparaissent, puis le disque revient après **deux secondes de jeu**. La pause suspend ce délai.

## Ouvrir et observer

Dans `C:\code\jeux`, double-cliquez sur **Ouvrir la cible dans Blender.cmd**. Le raccourci utilise Blender 4.5.14 LTS portable, déjà présent.

- **Pavé numérique 0** affiche la caméra de présentation. **F12** calcule un rendu.
- Dans l'Outliner, développez **TrainingTargetModel**.
- **TargetBase / BaseParts** contient le socle, la colonne et la charnière fixes.
- **TargetPlate / PlateParts** contient toutes les pièces qui basculent ensemble.
- **Studio_Preview_Not_Exported** contient le sol, la caméra et les lumières de présentation.

Les pièces et leurs chanfreins restent modifiables dans le `.blend`. Les copies exportées sont regroupées par matériau : **6 maillages pour le pied, 8 pour le disque**, soit environ **18 100 triangles** pour une cible complète. Les matériaux sont intégrés aux GLB, sans texture externe.

## Changer une couleur et exporter

1. Sélectionnez un segment ivoire du disque.
2. Dans **Material Properties / Propriétés de matériau**, ouvrez **T07_Ceramique_Ivoire**, puis modifiez **Base Color / Couleur de base**.
3. Enregistrez le fichier Blender avec **Ctrl+S**.
4. Lancez **Exporter la cible vers Godot.cmd**, dans le dossier du jeu.
5. Revenez dans Godot pour laisser la réimportation se terminer, puis lancez **F5** ou **Jouer DroneArena.cmd**.

Ce matériau est partagé par les pièces ivoire de la cible. Les quatre instances du jeu changent ensemble. Les matériaux des autres assets restent dans leurs propres GLB.

Le raccourci lit votre `.blend` enregistré et remplace les deux GLB. Il conserve vos modifications et exclut le studio. La sélection des pièces et leurs modificateurs sont préservés dans la source.

## Montage dans Godot

| Source Blender | Fichier GLB dans `DroneArena/assets/models` | Nœud de `target.tscn` |
| --- | --- | --- |
| `TargetBase` | `helix_target_base.glb` | `BaseVisual` |
| `TargetPlate` | `helix_target_plate.glb` | `Plate/PlateVisual` |

Les sources de Blender montrent la cible assemblée. L'exporteur ramène chaque partie à sa propre origine : le socle reste au sol, et le disque est exprimé par rapport à sa charnière. Godot anime toujours le nœud **Plate**, comme avant.

Les noms **CIBLE 01…04** et les états **PRÊT / TOUCHÉ** restent des libellés Godot. Ils ont été rehaussés de 12 cm pour être lisibles au-dessus de la nouvelle couronne.

## Dimensions et comportement à conserver

- Conception en mètres, **Y vertical et face avant vers +Z** dans Godot.
- **Plate** reste à `(0, 1, 0)` dans la scène Godot. Le centre du disque se trouve à `(0, 0.65, 0)` depuis ce pivot, donc à **1,65 m du sol**.
- Le disque conserve un **rayon de 0,65 m** et reste dans une épaisseur de **0,16 m**, de Z = -0,08 à +0,08.
- **HitShape** reste à `(0, 1.65, 0)`, avec son orientation et ses couches initiales. Le collider est fixe et se désactive pendant le rabattement, selon le comportement existant.
- La rotation va toujours de **0 à -80 degrés sur X**. Le socle et la charnière fixe restent immobiles.
- Le socle ne crée pas de nouvelle collision. Les deux GLB sont uniquement visuels, sans script, collider, squelette ni animation préenregistrée.

Conservez les origines, les axes et le diamètre du disque lors de vos modifications pour que les impacts restent alignés avec la surface visible. Déplacer une cible entière dans Godot déplace ensemble son modèle, son pivot, ses libellés et sa collision.

## Fichiers et commandes

- **helix_target.blend** : source modifiable avec studio.
- **preview.png** : rendu de présentation.
- **build_target.py** : reconstruction du modèle et rendu.
- **export_target.py** : export de la source enregistrée, sans reconstruction.
- **asset-info.json** : dimensions et géométrie des deux parties.

Les scripts réutilisent les outils de modélisation et d'export présents dans `art/arena/modeling.py` et `art/arena/export_arena.py`. La source `.blend` et les GLB sont autonomes pour afficher le modèle.

Pour exporter vos modifications enregistrées :

```powershell
& 'C:\code\jeux\.tools\blender\blender-4.5.14-windows-x64\blender.exe' --background 'C:\code\jeux\art\target\helix_target.blend' --python-exit-code 1 --python 'C:\code\jeux\art\target\export_target.py'
```

La commande suivante **recrée et remplace la source, les GLB et l'aperçu** à partir du script. Faites une copie si vous avez modifié le modèle à la main.

```powershell
& 'C:\code\jeux\.tools\blender\blender-4.5.14-windows-x64\blender.exe' --background --factory-startup --python-exit-code 1 --python 'C:\code\jeux\art\target\build_target.py'
```

Ajoutez `-- --skip-render` pour ne pas recalculer l'aperçu.

## Vérifications

```powershell
& 'C:\code\jeux\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path 'C:\code\jeux\DroneArena' --import
& 'C:\code\jeux\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'C:\code\jeux\DroneArena' --script res://tests/verify_target.gd --fixed-fps 60
```

Le test vérifie l'import, les dimensions, la séparation du pied et du disque, un vrai impact, le rabattement, la pause, le rétablissement, un second tir et le redémarrage. Sans `--headless`, il enregistre aussi deux vues dans `tests/artifacts/target_ready.png` et `target_hit.png`. Les suites existantes `verify.gd` et `verify_arena.gd` contrôlent les tirs et la conservation des 21 collisions de l'arène.
