# HELIX — décor du secteur 07

Le décor est un ensemble original créé dans Blender 4.5.14 LTS. Il reprend les matériaux des drones et de la carabine : céramique ivoire, titane graphite, aluminium, orange de sécurité et balisage cyan. Il comprend les panneaux des quatre murs, le sol, les caisses, les marches, le réacteur et les bâtiments de fond.

Les **21 formes de collision restent dans Godot**, avec leurs positions, dimensions et couches initiales. Les modèles GLB ne contiennent aucun collider. Les passages, les sauts, la couverture contre les tirs et la carte de vol des drones sont conservés.

## Ouvrir et explorer la source

Dans `C:\code\jeux`, double-cliquez sur **Ouvrir le decor dans Blender.cmd**.

- **Pavé numérique 0** : vue d'ensemble. **F12** : rendu de présentation.
- Dans l'Outliner, développez **ArenaArchitecture** pour sélectionner les pièces du sol, des murs, des marches, du réacteur et du fond.
- **Cover_A01** est la source exportée des quatre caisses basses. **Storage_C01** est celle des deux caisses hautes.
- Les autres caisses montrent l'assemblage complet dans Blender. Leur géométrie est liée aux pièces sources ; les transformations de chaque pièce restent individuelles.
- Les caméras et lumières de présentation sont dans **Studio_Preview_Not_Exported**.

Les murs **WallWest** et **WallSouth** sont masqués uniquement dans le rendu de présentation pour montrer l'intérieur de l'arène. Ils sont présents dans la vue 3D et dans le GLB du jeu.

## Première modification : changer l'orange

1. Sélectionnez une bande orange d'une caisse ou d'un mur.
2. Ouvrez **Material Properties / Propriétés de matériau**, puis le matériau **HX_Orange_Securite**.
3. Modifiez **Base Color / Couleur de base**. Ce matériau est partagé par les éléments orange du décor.
4. Enregistrez avec **Ctrl+S**.
5. Dans le dossier du jeu, lancez **Exporter le decor vers Godot.cmd**. Il lit le `.blend` enregistré et remplace les trois GLB, sans reconstruire vos pièces.
6. Revenez dans Godot pour laisser la réimportation se terminer, puis lancez **F5** ou **Jouer DroneArena.cmd**.

Les matériaux du drone et de l'arme appartiennent à leurs propres GLB : ils ne changent pas avec ce matériau de décor.

## Organisation et export

| Source Blender | Modèle utilisé par Godot | Intégration |
| --- | --- | --- |
| `ArenaArchitecture` | `helix_arena.glb` | `arena.tscn / VisualModel` |
| `Cover_A01` | `helix_cover.glb` | `cover.tscn / VisualModel` |
| `Storage_C01` | `helix_storage.glb` | `tower.tscn / VisualModel` |

Les trois GLB se trouvent dans `DroneArena/assets/models`. Leurs matériaux sont intégrés et ne demandent aucune texture externe. Les pièces restent séparées dans la source Blender. L'exporteur travaille sur des copies : il applique les chanfreins et regroupe les maillages par secteur et matériau. Les caisses gardent leur origine au sol, même si leur source est placée ailleurs dans la présentation Blender.

Pour déplacer une caisse dans Godot, sélectionnez par exemple **Arena/Obstacle_A01** : son modèle et sa collision se déplacent ensemble. Les quatre cibles d'entraînement, les textes de signalétique, l'éclairage du jeu, les drones et l'arme restent dans leurs scènes Godot.

## Dimensions à conserver

Les coordonnées du script sont celles de Godot : **mètres, Y vers le haut**. Blender utilise Z comme axe vertical ; l'exporteur effectue la conversion.

| Élément | Volume physique conservé |
| --- | --- |
| Sol | 40 × 48 m, surface à Y = 0 |
| Murs | Faces intérieures à X = ±19,5 et Z = ±23,5 m ; hauteur 7 m |
| Caisses basses | 3 × 1,1 × 3 m, origine au sol |
| Caisses hautes | 2,8 × 3,2 × 3 m, origine au sol |
| Marches | 4 × 0,35 × 2,5 m |
| Socle du réacteur | 6 × 0,4 × 6 m |
| Cuve du réacteur | Rayon 1,8 m ; Y = 0,4 à 4 m |
| Piliers du réacteur | 0,4 × 4,6 × 0,7 m |

Les panneaux et les renforts sont contenus dans ces volumes. Les marquages sont presque affleurants. Conservez ces limites pour que les formes visibles correspondent toujours aux collisions. Modifier la position ou la taille d'un grand élément dans Blender demanderait aussi d'adapter sa collision dans Godot.

## Exporter depuis la source enregistrée

Le raccourci **Exporter le decor vers Godot.cmd** exécute cette commande. Elle conserve votre `.blend` et remplace uniquement les GLB et `asset-info.json` :

```powershell
& 'C:\code\jeux\.tools\blender\blender-4.5.14-windows-x64\blender.exe' --background 'C:\code\jeux\art\arena\helix_arena.blend' --python-exit-code 1 --python 'C:\code\jeux\art\arena\export_arena.py'
```

Gardez les noms **ArenaArchitecture**, **Cover_A01** et **Storage_C01**. Le script trouve ces sources par leur nom, exclut le studio et exporte les modèles sans animation ni lumière.

## Reconstruire depuis le code

Cette commande **recrée et remplace le `.blend`, les GLB et l'aperçu**, à partir de `build_arena.py` et `modeling.py`. Faites une copie si vous avez modifié la source à la main.

```powershell
& 'C:\code\jeux\.tools\blender\blender-4.5.14-windows-x64\blender.exe' --background --factory-startup --python-exit-code 1 --python 'C:\code\jeux\art\arena\build_arena.py'
```

Ajoutez `-- --skip-render` pour ne pas recalculer l'aperçu.

## Vérifier la physique

```powershell
& 'C:\code\jeux\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path 'C:\code\jeux\DroneArena' --import
& 'C:\code\jeux\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'C:\code\jeux\DroneArena' --script res://tests/verify_arena.gd --fixed-fps 60
```

Le test compare les 21 collisions au relevé antérieur au nouveau décor, ainsi que les **294 cellules bloquées** de la carte de vol. Il vérifie aussi l'import, l'échelle des caisses et l'absence de collision ou de studio dans les modèles. Les suites `verify.gd` et `verify_combat.gd` contrôlent les déplacements, le saut, les tirs, la couverture et les ennemis. Un lancement graphique de `verify_arena.gd` enregistre quatre vues dans `tests/artifacts/decor_*.png`.
