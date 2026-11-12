# HELIX H-01 — carabine Blender et GLB

Cette carabine originale remplace le modèle de l'arme dans DroneArena. Sa coque ivoire, son châssis graphite, ses accents orange et sa chambre cyan reprennent le style du drone HELIX S-07. La cadence, la portée, les dégâts, le recul et les effets de tir restent gérés par les scripts existants de Godot.

## Ouvrir le modèle

Dans `C:\code\jeux`, double-cliquez sur **Ouvrir l'arme dans Blender.cmd**. Le raccourci ouvre `art\carbine\helix_carbine.blend` avec Blender 4.5.14 LTS portable, déjà installé.

- **Pavé numérique 0** : vue de présentation. **F12** : rendu.
- Dans l'Outliner, développez **CarbineModel**. Les groupes **Receiver**, **Barrel**, **PowerCell**, **StockGrip** et **Sight** regroupent les pièces de l'arme.
- **Hands** contient les gants et les avant-bras. Ils apparaissent dans le jeu et dans la vue 3D, mais sont masqués uniquement dans le rendu de présentation.
- **MuzzleReference** indique la sortie du canon. Ce repère permet de contrôler l'alignement avec le flash de Godot.
- Le studio, ses lumières, son sol et sa caméra sont rangés dans **Studio_Preview_Not_Exported**.

Les pièces restent séparées dans la source Blender, avec leurs chanfreins modifiables. Le GLB livré est regroupé par matériau pour réduire les appels de rendu : **14 maillages, 9 matériaux PBR intégrés et 78 216 triangles**, gants compris. Aucune texture externe n'est requise.

## Essayer une couleur

Sélectionnez une plaque du groupe **Receiver**, ouvrez **Material Properties / Propriétés de matériau**, puis modifiez **Base Color / Couleur de base** du matériau **H01_Ceramique_Ivoire**. Ce matériau est partagé par plusieurs plaques. Enregistrez le `.blend` avec **Ctrl+S**.

Le jeu lit le **GLB**, il faut donc exporter pour voir cette modification dans Godot.

## Exporter une modification manuelle

1. Sélectionnez **CarbineModel et tous ses descendants**. Excluez le studio.
2. **Fichier → Exporter → glTF 2.0**. Choisissez **glTF Binary (.glb)**.
3. Activez **Selected Objects / Objets sélectionnés** et **Apply Modifiers / Appliquer les modificateurs**. Gardez **+Y Up**. Laissez le filtre **Renderable Objects / Objets rendables** désactivé pour inclure aussi les gants masqués dans le rendu de présentation.
4. Exportez vers `C:\code\jeux\DroneArena\assets\models\helix_carbine.glb` en remplaçant le fichier existant.
5. Revenez dans Godot pour laisser l'import se terminer, puis lancez **F5** ou **Jouer DroneArena.cmd**.

Cet export manuel conserve les pièces séparées ; il peut donc produire plus de maillages que le GLB initial optimisé. Les lumières du studio doivent rester exclues.

## Contrat avec les tirs du jeu

- Les unités sont des **mètres** : Y vers le haut, canon dirigé vers **-Z** dans Godot.
- La bouche du canon finit à `Z = -0.55`, autour de `Y = 0.025`.
- **MuzzleReference** est à `(0, 0.025, -0.555)`, comme le marqueur `Model/Muzzle` de `scenes/weapon.tscn`.
- L'instance du GLB se trouve sous **Model/VisualModel**, sans translation, rotation ni changement d'échelle.
- La pose de l'arme par rapport à la caméra reste `(0.28, -0.24, -0.5)`.
- Le nœud **Model** reçoit le recul et la pose de rechargement : l'arme, les gants et les repères bougent ensemble. Le script `weapon.gd` gère le chargeur de 30 impulsions, la touche R et le délai de 1,8 seconde ; aucun nouvel export Blender n'est nécessaire pour ces réglages.
- Le GLB n'ajoute aucun collider, script de jeu, squelette ni animation préenregistrée. Les sons, le flash et la lumière de tir restent dans la scène Godot.
- `scripts/import_carbine.gd`, configuré dans les paramètres d'import du GLB, désactive les ombres du modèle tenu en main comme sur l'ancienne arme. Il ne modifie pas les tirs.

Conservez l'origine, l'échelle et l'axe du canon si vous modifiez la forme de l'arme. La scène et `scripts/weapon.gd` gardent le mécanisme de tir.

## Fichiers et reconstruction

- **helix_carbine.blend** : source éditable, avec studio.
- **preview.png** : présentation de l'arme seule.
- **build_carbine.py** : reconstruction des pièces, export optimisé et rendu.
- **asset-info.json** : dimensions, géométrie et repère du canon.
- **../../DroneArena/assets/models/helix_carbine.glb** : modèle autonome utilisé par le jeu.

La commande suivante **recrée et remplace la source, le GLB et l'aperçu**. Elle repart du script : faites une copie si vous avez modifié le modèle à la main.

```powershell
& 'C:\code\jeux\.tools\blender\blender-4.5.14-windows-x64\blender.exe' --background --factory-startup --python-exit-code 1 --python 'C:\code\jeux\art\carbine\build_carbine.py'
```

Ajoutez `-- --skip-render` pour reconstruire sans recalculer l'aperçu.

Pour contrôler l'import et l'alignement dans le vrai projet :

```powershell
& 'C:\code\jeux\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path 'C:\code\jeux\DroneArena' --import
& 'C:\code\jeux\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'C:\code\jeux\DroneArena' --script res://tests/verify_carbine.gd --fixed-fps 60
```

Les suites existantes `verify.gd` et `verify_combat.gd` contrôlent les tirs, les obstacles, les drones et le cycle de partie avec ce modèle.
