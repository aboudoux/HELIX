# HELIX S-07 — modèle Blender et GLB

Ce drone est un modèle original créé pour DroneArena avec Blender 4.5.14 LTS. Il remplace l'apparence des trois sentinelles. Ses scripts de poursuite, de tir et de dégâts restent dans Godot.

- **helix_sentinel.blend** : source modifiable, avec un studio et une caméra de présentation.
- **build_sentinel.py** : script Blender qui reconstruit le modèle et exporte le GLB.
- **preview.png** : rendu de présentation du modèle.
- **asset-info.json** : dimensions, nombre de triangles et noms des pivots.
- **../../DroneArena/assets/models/helix_sentinel.glb** : fichier autonome utilisé par le jeu, avec ses matériaux intégrés.

## Ouvrir et observer

Dans `C:\code\jeux`, double-cliquez sur **Ouvrir le drone dans Blender.cmd**. Le raccourci utilise la version portable déjà installée dans `.tools\blender`.

Dans Blender : **pavé numérique 0** affiche la caméra de présentation, **F12** produit un rendu. Dans l'Outliner, développez **SentinelModel** : **Chassis** contient les pièces fixes et **Rotors** les quatre turbines. Le studio est rangé dans **Studio_Preview_Not_Exported** et ne fait pas partie du GLB.

Le modèle comporte une coque biseautée, des panneaux d'armure, un capteur optique rouge, un canon, des câbles, des ailettes de refroidissement, des rivets et quatre turbines carénées. Ses matériaux sont des matériaux PBR simples ; aucune texture ni bibliothèque externe n'est nécessaire.

## Contrat avec Godot

- Taille approximative : **1,80 × 0,58 × 1,42 m** (largeur, hauteur, profondeur).
- Axe vertical : **+Y** dans Godot. Avant du drone : **-Z**.
- Les pivots animés sont `Rotors/Rotor0/Blades0` à `Rotors/Rotor3/Blades3`. Leur rotation se fait sur leur axe Y local dans Godot.
- La bouche du canon correspond au marqueur existant `Hull/Muzzle`, à `(0, -0.11, -0.64)`.
- `scenes/drone.tscn` conserve le corps physique, les sons, les indicateurs de santé et le marqueur de tir. Le GLB est une instance sous `Hull/VisualModel`.
- Aucune collision, caméra, lumière de studio ni IA n'est incluse dans le fichier GLB.

Gardez ces noms de pivots et ces dimensions si vous modifiez le modèle. Les points de vie, vitesses, délais de tir et collisions se règlent toujours dans Godot, comme avant.

## Exporter une modification manuelle

Enregistrez le `.blend`, puis sélectionnez **SentinelModel et tous ses descendants**, en excluant le studio. Utilisez **Fichier → Exporter → glTF 2.0**, format **glTF Binary (.glb)**, avec **Selected Objects / Objets sélectionnés**. Remplacez `C:\code\jeux\DroneArena\assets\models\helix_sentinel.glb`.

En revenant dans Godot, le GLB est réimporté et les trois instances sont mises à jour. Relancez le jeu avec F5 ou le raccourci Jouer DroneArena.

## Reconstruire depuis le script

Cette commande **recrée et remplace** la source `.blend`, le GLB et l'aperçu à partir du script. Faites une copie si vous avez modifié le modèle à la main.

```powershell
& 'C:\code\jeux\.tools\blender\blender-4.5.14-windows-x64\blender.exe' --background --factory-startup --python-exit-code 1 --python 'C:\code\jeux\art\sentinel\build_sentinel.py'
```

Pour recréer le GLB et la source sans recalculer le rendu de présentation, ajoutez `-- --skip-render` à la commande.

Les coordonnées du script sont celles de Godot ; le script effectue la conversion vers les axes de Blender et l'export glTF. Les hélices sont animées par le script du drone dans Godot, sans animation préenregistrée ni squelette.
