# HELIX — Impacts et épaves des drones

Les tirs sur un drone utilisent le point et la normale fournis par le vrai rayon de la carabine. Les cibles d'entraînement et les murs gardent leur effet d'impact habituel.

Une touche projette **18 petits fragments** : morceaux de coque ivoire avec une bande orange et des tranches métalliques, éclats de métal, boulons hexagonaux et fils de cuivre. Ils sont accompagnés de **24 étincelles**, d'un bref éclair et d'une petite bouffée de fumée.

Le tir fatal garde les petits fragments de touche, puis crée une **épave physique du modèle entier**. Elle hérite du déplacement du drone, tombe avec la gravité et utilise une enveloppe convexe calculée à partir des maillages du GLB. Les hélices ralentissent, les lumières s'éteignent et un choc métallique joue au premier contact avec le décor. Une fois stabilisée, la carcasse est figée et reste présente jusqu'à la fin de la partie.

Les petits fragments tournent, subissent la gravité et rebondissent sur les collisions du décor. Les petites plaques se posent sur le sol ou les rampes. Ces débris visuels disparaissent après 1,65 seconde. Les **épaves** restent solides et arrêtent les tirs ; elles ne dépendent pas du nettoyage des effets temporaires. La pause suspend aussi leur chute. Les changements de secteur conservent les carcasses ; recommencer la mission ou quitter la scène les retire. CERBÈRE utilise la même logique avec sa propre enveloppe et un son de choc plus lourd.

## Fichiers

- `DroneArena/scripts/drone_debris.gd` crée les maillages et la fumée, regroupe les morceaux par matériau dans des MultiMesh et simule les trajectoires. Les ressources sont partagées et le nombre d'effets simultanés est limité aux seize plus récents.
- `DroneArena/scripts/drone_wreck.gd` conserve le GLB, prépare sa collision physique, éteint ses matériaux et gère la chute et le choc. Les collisions calculées sont partagées par modèle ; les matériaux de l'épave sont indépendants de ceux des drones vivants.
- `DroneArena/scripts/drone.gd` déclenche les effets et les sons lors d'une touche valide.
- `DroneArena/scripts/weapon.gd` transmet le point touché au drone.
- `preview_debris.gif` et `preview_debris.mp4` sont les aperçus historiques avec explosion. `preview_wreck.mp4` et `preview_wreck.gif` montrent le comportement actuel enregistré dans Godot.

## Vérifier

Depuis PowerShell dans `C:\code\jeux` :

```powershell
& '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path DroneArena --script res://tests/verify_debris.gd --fixed-fps 60
```

Sans `--headless`, le test produit deux captures dans `DroneArena/tests/artifacts`. Il vérifie le point touché, les projections, les rebonds réels, la pause, le nettoyage et le budget des effets.

`tests/verify_wrecks.gd` vérifie en plus les vrais tirs, les chutes, les collisions au sol, l'arrêt des hélices, l'absence d'explosion, la pause, la persistance des seize carcasses jusqu'à la victoire et leur nettoyage au redémarrage.

## Enregistrer un aperçu

```powershell
& '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --path DroneArena --script C:/code/jeux/art/effects/record_wreck.gd --fixed-fps 60 --write-movie C:/code/jeux/.tools/wreck-preview.avi --resolution 1280x800
ffmpeg -y -i .tools/wreck-preview.avi -c:v libx264 -crf 21 -pix_fmt yuv420p -c:a aac -movflags +faststart art/effects/preview_wreck.mp4
```

Le moteur enregistre son rendu et son mix sonore. Aucun logiciel de modélisation ni pack de particules n'est nécessaire pour ces effets.
