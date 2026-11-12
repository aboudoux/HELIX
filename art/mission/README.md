# HELIX — Architecture de la mission

**Ouvrir la mission dans Blender.cmd** ouvre `helix_mission.blend`. Les pièces restent séparées et regroupées par mur, sol ou accessoire. La palette reprend les céramiques ivoire, le graphite, l'orange de sécurité et les traits cyan du drone et de la carabine.

Le fichier contient l'architecture, un battant de porte, une console et un kit de réparation. `Preview_Props_Not_Exported` montre l'assemblage des portes et des caisses ; `Studio_Preview_Not_Exported` contient l'éclairage et la caméra de présentation.

Les plafonds techniques, verrières et le ciel étoilé sont des ressources Godot séparées. Leur générateur et leur guide sont dans [`art/environment`](../environment/README.md). Un export Blender conserve ces ajouts ; si vous changez les limites des zones dans `layout.json`, relancez également `python art/environment/build_environment.py` avant d'assembler les scènes.

Les groupes d'ennemis mélangent douze drones et trois LIMIERS K-9. `layout.json`, clé `hound_spawns`, précise les gardes remplacés par des chiens et leurs positions au sol. `build_scenes.py` référence leurs scènes Godot ; les chiens ne font pas partie du GLB d'architecture. Leur source Blender et leur guide se trouvent dans [`art/hound`](../hound/README.md).

Les modèles exportés sont exclusivement visuels :

| GLB | Rôle |
| --- | --- |
| `helix_mission_map.glb` | Sols, murs, passerelle, réacteur et balisage |
| `helix_mission_leaf.glb` | Battant animé dans Godot |
| `helix_mission_relay.glb` | Console d'objectif |
| `helix_mission_medical.glb` | Kit consommable |

## Régénérer la carte

Le plan commun est `DroneArena/missions/relay_run/layout.json`. Depuis une console PowerShell dans `C:\code\jeux` :

```powershell
python art/mission/build_scenes.py
& '.tools/blender/blender-4.5.14-windows-x64/blender.exe' --background --python art/mission/build_mission.py
```

La première commande reconstruit les scènes Godot ; la seconde reconstruit la source Blender, exporte les quatre GLB et produit `preview.png`. Les positions et dimensions des murs et des rampes viennent du même plan pour garder le modèle et les collisions cohérents. Godot réimporte ensuite les ressources.

**Ces générateurs remplacent leurs fichiers de sortie**, y compris les modifications manuelles dans les scènes générées et dans `helix_mission.blend`. Copiez vos variantes avant de les relancer. Les scripts du jeu, le personnage et les scènes d'entraînement ne sont pas régénérés.

## Exporter seulement les modifications manuelles de Blender

Après avoir enregistré la source modifiée, lancez **Exporter la mission vers Godot.cmd**. Cette commande exporte les quatre racines existantes sans reconstruire le modèle. Pour une modification de matériau, c'est suffisant. Une modification de forme ou de position demande également d'adapter les collisions dans `map.tscn`, ou de mettre à jour le plan puis de régénérer les deux versions.

## Vérifications

Depuis le dossier du jeu :

```powershell
& '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path DroneArena --editor --import --quit
& '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path DroneArena --script res://tests/verify_mission.gd --fixed-fps 60
& '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path DroneArena --script res://tests/verify_difficulty.gd --fixed-fps 60
```

La première suite parcourt les annexes avec le vrai contrôleur, vérifie les tirs, les rampes, les soins, les relais, les portes, la pause, la victoire et les réinitialisations. La seconde vérifie les trois difficultés dans la mission et l'entraînement, avec les vrais tirs et projectiles, la sélection au clavier, les reprises, les changements de niveau et la préférence sauvegardée. Ces scripts lancés sans `--headless` produisent des captures dans `DroneArena/tests/artifacts`. Les tests historiques de l'entraînement restent séparés.
