# HELIX — voûte orbitale et plafonds

Le décor combine des toitures opaques, de grandes verrières, des bandeaux vitrés au-dessus des murs et un ciel nocturne. Le cargo, le refroidissement et le cœur ont les plus grandes baies ; les annexes ont surtout des panneaux techniques. Les néons cyan et ambre, les goulottes, renforts en céramique, joints métalliques, grilles et luminaires reprennent la palette HELIX.

Le panorama original `DroneArena/environment/helix_galaxy.png` est généré en 4096 × 2048 : 22 000 étoiles, une bande galactique, des nuages mauves et des poussières. Il reste fixe dans l'espace lorsque le joueur se déplace. Aucun téléchargement ni pack externe. Les vitres ont une très légère teinte ; elles ne masquent pas les étoiles. L'éclairage ambiant est indépendant du ciel noir et complété par les sources des plafonds. Pas de brume diurne.

## Modifier dans Godot

- Ouvrir `environment/mission_roofs.tscn` (sept zones) ou `environment/training_roofs.tscn` (une zone). Chaque pièce du plafond est un nœud visible dans l'arbre.
- Sélectionner un `NeonContinu…`, développer **Material Override** puis modifier **Emission** pour sa couleur. Le matériau est partagé avec les néons de même couleur dans cette scène : utiliser **Rendre unique** pour n'en changer qu'un.
- Sélectionner `Vitre…` pour sa position, sa taille ou la teinte de son matériau.
- Ouvrir `environment/space.tres` pour la rotation du ciel ou l'éclairage ambiant ; développer **Sky > Sky Material > Panorama** pour voir la texture utilisée.
- Lancer la mission avec F5, ou l'entraînement avec F6 depuis `scenes/main.tscn`.

Les hauteurs de toiture vont de 8,6 à 11,4 m. Ces ajouts sont visuels : les collisions du décor, trajectoires des drones, sauts, portes et objectifs conservent leurs réglages. Les verrières ne sont pas destructibles et n'ont pas de collision de tir. Les nouvelles sources n'ajoutent pas d'ombres dynamiques multiples ; les poutres conservent leurs ombres sous l'éclairage directionnel.

## Régénérer

Depuis `C:\code\jeux`, avec Python, NumPy et Pillow déjà disponibles :

```powershell
python art/environment/build_environment.py
python art/mission/build_scenes.py
& '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path DroneArena --import
```

Le premier script reconstruit le panorama, les matériaux et les deux scènes de toiture. Il écrase les retouches manuelles de ces fichiers ; reporter une modification durable dans ce script. Le deuxième assemble la mission et référence les toitures sans modifier les GLB, la physique ou les scripts de gameplay. Un simple export des GLB depuis Blender conserve les plafonds et le ciel.

## Vérifications

```powershell
& '.tools/godot/Godot_v4.7.2-stable_win64_console.exe' --path DroneArena --script res://tests/verify_environment.gd --fixed-fps 60 --resolution 1280x800
```

Le scénario ouvre les trois points d'entrée, vérifie l'environnement commun et les dégagements des toitures, puis capture six vues réelles dans `DroneArena/tests/artifacts/orbite_*.png`. Les suites `verify_arena.gd`, `verify_mission.gd`, `verify_boss.gd` et `verify_aim.gd` contrôlent les collisions de référence, le parcours complet avec les portes, le boss et les tirs en visée. Le rendu doit être contrôlé avec Forward+, car le mode sans interface ne montre pas la transparence et les shaders.
