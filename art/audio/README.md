# HELIX — Sons de combat et mécanismes

Les sons sont originaux et synthétisés pour ce projet. Aucune banque externe, licence à acheter ou extension Godot n'est nécessaire pour jouer.

La carabine combine un claquement très bref, un corps grave, une décharge d'énergie et une courte résonance. Les drones possèdent leurs propres tirs et des chocs de coque métallique à chaque impact. Leur neutralisation provoque une chute ; le choc au sol utilise un son métallique distinct pour les sentinelles et pour CERBÈRE.

| Ressource dans `DroneArena/audio` | Usage |
| --- | --- |
| `rifle.tres` et les trois `shot*.wav` | Variantes de la carabine, sans répétition immédiate |
| `enemy_rifle.tres` et les deux `enemy_shot*.wav` | Tirs ennemis spatialisés |
| `armor_impact.tres` et les trois `drone_impact*.wav` | Impacts métalliques au niveau du drone touché |
| `drone_destroyed.wav` | Ancien son d'explosion, conservé comme source historique et inutilisé par les drones |
| `drone_crash.wav` / `boss_crash.wav` | Choc de la carcasse au contact du décor |
| `hit.wav` | Confirmation de touche discrète au niveau du joueur |
| `weapon_reload.wav` | Déverrouillage, retrait, insertion de cellule et verrouillage de la carabine, en 1,8 seconde |
| `weapon_empty.wav` | Clic mécanique à vide, une seule fois par pression sur le bouton de tir |
| `hound_step.wav` | Pas des pattes mécaniques, spatialisés près du chien |
| `hound_charge.wav` | Charge du canon dorsal pendant le verrouillage laser |
| `hound_laser.wav` | Deux impulsions laser distinctes par rafale du LIMIER K-9 |

Les WAV du jeu sont en PCM mono 16 bits à 48 kHz. Godot applique les variations et les positions 3D à la lecture. La carabine autorise quatre voix simultanées pour que les queues des tirs se superposent en rafale ; les impacts en autorisent trois. Les volumes se règlent dans `scenes/weapon.tscn` et `scenes/drone.tscn`. Le mix principal possède un limiteur à −1 dB dans `default_bus_layout.tres`.

`preview_combat.wav` est l'ancien extrait stéréo de combat, enregistré avant le remplacement des explosions par des épaves. `manifest.json` décrit les sons de combat source et leurs niveaux avant les volumes appliqués dans le jeu.

## Régénérer les sons

Depuis PowerShell dans `C:\code\jeux` :

```powershell
python art/audio/design_combat.py
& '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path DroneArena --editor --import --quit
& '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path DroneArena --script C:/code/jeux/art/audio/build_resources.gd
```

Python et NumPy sont utilisés uniquement pour la fabrication. Le jeu utilise les fichiers enregistrés et ne dépend pas de Python. Les graines aléatoires sont fixes pour rendre la génération reproductible.

Les deux sons de la recharge se régénèrent avec `python art/audio/design_reload.py`, puis un import Godot. `reload_manifest.json` donne leurs durées et niveaux source. Le son de manipulation suit la pause et reprend au même point ; recommencer, perdre ou terminer la mission l'arrête. Ses volumes se règlent dans `ReloadSound` et `EmptySound` de `scenes/weapon.tscn`. Ces sons sont au niveau du joueur, comme la carabine.

Les sons du LIMIER K-9 se régénèrent avec `python art/audio/design_hound.py`, puis un import Godot. Ils sont spatialisés en 3D, suivent la pause et s'arrêtent à la neutralisation ou au redémarrage. La hauteur de lecture du son de charge suit la durée d'avertissement de la difficulté. `hound_manifest.json` donne les niveaux et durées source ; les volumes sont dans `scenes/hound.tscn`.

## Vérifier et enregistrer un extrait

```powershell
& '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path DroneArena --script res://tests/verify_audio.gd --fixed-fps 60
& '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --path DroneArena --script res://tests/verify_audio.gd --max-fps 60 -- --record
```

La seconde commande ouvre le jeu, joue la séquence de combat et remplace l'extrait par un enregistrement du mix principal. Elle utilise le temps réel afin que le son et les actions restent synchronisés.

## Hélices et interactions

| Ressource dans `DroneArena/audio` | Usage |
| --- | --- |
| `drone_rotor.wav` | Souffle et passage des pales des quatre turbines d'une sentinelle |
| `boss_rotor.wav` | Turbines plus graves et plus présentes de CERBÈRE |
| `door_open.wav` | Déverrouillage, moteur, glissières et butée de porte |
| `relay_activate.wav` | Confirmation d'activation d'un relais |
| `interaction_denied.wav` | Refus lorsque E est pressé près d'un relais encore verrouillé |
| `repair_pickup.wav` | Confirmation d'un kit de réparation effectivement consommé |
| `drone_crash.wav` | Choc métallique d'une sentinelle abattue, joué au contact |
| `boss_crash.wav` | Choc plus lourd de la carcasse de CERBÈRE |

Les hélices bouclent sur quatre secondes. `scripts/rotor_audio.gd` prépare une copie du flux pour chaque drone, décale leur phase et applique un fondu au démarrage. La poussée et le verrouillage modifient légèrement le régime ; la phase de surchauffe du boss l'augmente aussi. Les lecteurs 3D placent chaque moteur à son drone et atténuent son volume avec la distance. Les secteurs dormants, les drones cachés et les carcasses restent silencieux. La pause suspend les boucles et les sons en cours.

La porte joue son moteur au début de son ouverture réelle. La butée du son tombe à **1,2 seconde**, avec la fin du mouvement. Une commande répétée sur une porte déjà ouverte ne relance pas le son. Certains relais sont loin de la porte qu'ils commandent : la confirmation se joue près du terminal, tandis que le moteur provient de la porte et reste plus lointain. Les kits ne produisent leur son que lorsqu'ils rendent effectivement de la santé. Recommencer coupe les anciens sons d'interaction et remet les objets dans leur état initial.

Les niveaux se règlent dans `scenes/drone.tscn`, `scenes/boss.tscn`, `scripts/drone_wreck.gd` pour les chocs des carcasses et `art/mission/build_scenes.py` pour les éléments du décor. Les fichiers `.wav.import` des sons mécaniques conservent le PCM 16 bits ; les bornes de boucle sont calculées à partir de la durée et de la fréquence d'échantillonnage.

`design_mechanical.py` génère ces huit WAV avec NumPy ; `mechanical_manifest.json` indique leurs durées et niveaux. Pour les régénérer, exécuter `python art/audio/design_mechanical.py`, puis réimporter le projet avec Godot comme ci-dessus. Si les métadonnées `.wav.import` ont été supprimées, refaire la génération après le premier import pour rétablir les réglages PCM, puis réimporter.

`preview_mechanical.wav` est un enregistrement stéréo du vrai moteur : une sentinelle devant, à droite puis à gauche, une activation de relais, une ouverture de porte à proximité, un kit et les turbines de CERBÈRE. Les repères temporels figurent dans `preview_mechanical.json`. Pour refaire cet extrait :

```powershell
& '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --path DroneArena --script C:/code/jeux/art/audio/record_mechanical.gd --max-fps 60
```

`tests/verify_mechanical_audio.gd` vérifie les boucles et leurs arrêts, la spatialisation configurée, la vraie touche E, l'ouverture et la collision des portes, les kits, la pause, les redémarrages et le régime du boss. Cette suite peut être lancée en mode sans interface ou avec une fenêtre native.

Après l'enregistrement, `python art/audio/verify_mechanical_mix.py` contrôle le panoramique gauche/droite, la présence de chaque action, le silence après arrêt des hélices et la marge du mix. Les mesures sont sauvegardées dans `mechanical_mix_check.json`.
