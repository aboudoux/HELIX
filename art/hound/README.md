# HELIX K-9 — LIMIER

Chien robot original modélisé dans Blender 4.5 : châssis graphite et céramique ivoire, axes de hanche orange, quatre pattes articulées, vérins, patins et griffes, museau et oreilles de chien, optiques rouges, queue capteur et canon laser dorsal. La version GLB regroupe les pièces par matériau à chaque articulation : environ 17 000 triangles et 42 maillages. La source conserve toutes les pièces éditables.

**Ouvrir le chien robot dans Blender.cmd** ouvre `helix_hound.blend`. Le studio est exclu du GLB. Dans Godot, `scenes/hound.tscn` réunit le modèle, sa collision, sa jauge, son laser de visée et ses sons.

## Comportement

- Poursuite au sol, avec gravité et collisions ; une grille distincte de celle des drones évite les caisses et les murs. Les jambes exécutent un trot diagonal, et le canon s'incline vers la cible.
- À portée, le chien s'arrête, annonce son tir avec un laser rouge et une charge sonore, puis envoie **deux impulsions laser roses** vers le point annoncé. Un déplacement latéral permet l'esquive. Les obstacles arrêtent les tirs.
- Les impulsions sont des traits lumineux sans noyau sphérique, avec un cœur incandescent et une enveloppe rose. Leur longueur atteint 1,4 m ; les drones et CERBÈRE utilisent la variante rouge-orange de 1,8 m. Le trait grandit depuis le canon et reste derrière sa pointe physique, qui détecte les collisions.
- En Facile / Moyen / Difficile : **2 / 3 / 4 impacts** pour le neutraliser, **3 / 6 / 9 dégâts par impulsion**, vitesse au sol d'environ **3 / 4,5 / 5,7 m/s**. La protection temporaire du joueur après un impact reste en vigueur. Les tirs sont plus espacés et les avertissements plus longs en Facile.
- Le limier cherche un angle accessible à environ sept mètres, se replace pendant ses temps morts et s'arrête pour annoncer sa rafale. Il échange les repérages avec les sentinelles proches et réagit aux tirs du joueur. Après une perte de vue, la poursuite vise une position mémorisée et ne suit pas les déplacements invisibles. Un impact lui fait changer de côté.
- Impacts métalliques et fragments à chaque touche. À sa mort, le modèle tombe et reste comme carcasse pendant la mission ; ses optiques s'éteignent. Recommencer nettoie l'épave et restaure le chien. La pause fige déplacements, pattes, tirs et sons.

L'entraînement contient **deux drones et un limier**. La mission conserve quinze gardes, répartis en **douze drones et trois limiers**, un par secteur. Tous doivent être neutralisés pour activer leur relais ; le troisième relais réveille toujours CERBÈRE. Les trois positions des chiens se règlent dans `missions/relay_run/layout.json`, clé `hound_spawns` : index du garde dans le tableau existant, X et Z au sol. Le mode de combat direct contre CERBÈRE conserve les groupes dormants.

## Modifications et génération

Les pivots `HipFL`, `HipFR`, `HipRL`, `HipRR` portent les hanches ; les `Knee…` sont leurs enfants. `Body/Turret` porte `LaserMuzzle`, aligné sur l'émetteur. Conserver ces noms et hiérarchies lors d'un export manuel. Les unités sont des mètres, +Y vertical et avant -Z dans Godot. Exporter la hiérarchie `HELIX_K9_LIMIER`, avec +Y Up, sans le studio. Destination : `DroneArena/assets/models/helix_hound.glb`.

Pour reconstruire depuis les scripts, dans `C:\code\jeux` :

```powershell
& '.tools/blender/blender-4.5.14-windows-x64/blender.exe' --background --python art/hound/build_hound.py
python art/hound/build_scene.py
python art/audio/design_hound.py
python art/mission/build_scenes.py
& '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path DroneArena --import
```

Ces commandes écrasent les retouches manuelles des fichiers générés ; reporter les modifications durables dans les sources Python. Le jeu utilise les assets sauvegardés, sans Python ni Blender au lancement.

Le contrat de rencontre garde les noms historiques `drone_name`, `reset_drone()` et `destroyed` pour que le directeur et les objectifs gèrent les deux familles. Le groupe `hounds` identifie les K-9. `scripts/ground_navigation.gd` construit la carte de marche, invalidée lors des changements de portes et en cas de blocage ; les 21 collisions du décor d'entraînement sont conservées.

`scripts/enemy_tactics.gd` est commun aux drones, limiers et au boss : information visuelle mémorisée huit secondes, rapports radio entre alliés actifs à moins de 36 m, audition des tirs du joueur à moins de 32 m, recherche de positions dégagées et accessibles, séparation des alliés et choix de côté. Les décisions sont espacées et les chemins sont réutilisés. Les positions d'entrée connues à l'activation d'un secteur servent de premier renseignement. La mémoire vieillit sans voir le joueur ; la dernière position reste un lieu à fouiller. Seule une ligne de vue réelle autorise la préparation et le tir. Les réglages de cadence et de vitesse restent centralisés dans `scripts/difficulty.gd`.

## Vérifier

```powershell
& '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path DroneArena --script res://tests/verify_hound.gd --fixed-fps 60
& '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --path DroneArena --script res://tests/verify_hound.gd --fixed-fps 60 --resolution 1280x800
```

La suite contrôle l'import, les difficultés, la marche réelle entre les annexes et les cours, les articulations, la charge, les deux tirs, les dégâts, l'esquive, les murs, les impacts du fusil, la carcasse persistante, la pause, le redémarrage et l'activation des trois relais avec les groupes mixtes. Le rendu natif produit `tests/artifacts/limier_*.png`.
