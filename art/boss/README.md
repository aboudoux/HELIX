# HELIX M-90 — CERBÈRE

Boss original construit dans Blender 4.5.14 LTS pour le FPS HELIX. Aucun asset externe.

Ouvrir **C:\code\jeux\Ouvrir le boss dans Blender.cmd** pour voir et modifier `helix_boss.blend`. Le studio, sa caméra et ses éclairages restent dans une collection séparée et sont exclus du modèle du jeu.

- Envergure : **6,10 m** ; profondeur : environ **4,92 m** ; hauteur : environ **2,71 m**.
- 311 objets de construction : blindages chanfreinés, masque anguleux, trois optiques rouges, mandibules, ailettes dorsales, vérins, grilles, boulons, tambours et cartouches.
- Quatre turbines carénées avec pales indépendantes.
- Deux mitrailleuses à six canons, avec pivots de rotation et repères de bouche.
- Le GLB contient **53 172 triangles et 67 meshes**, regroupés par matériau pour limiter les appels de rendu. Les pièces sources du .blend restent séparées.

`build_boss.py` reconstruit le modèle, exporte `C:\code\jeux\DroneArena\assets\models\helix_boss.glb`, sauvegarde le .blend et rend `preview.png`. **Cette génération remplace les modifications manuelles** : sauvegarder une copie du .blend avant de la relancer.

```powershell
& 'C:\code\jeux\.tools\blender\blender-4.5.14-windows-x64\blender.exe' --background --python 'C:\code\jeux\art\boss\build_boss.py'
```

Les coordonnées de conception utilisent Y vertical et l'avant -Z, en mètres. Blender convertit ces coordonnées vers Z vertical ; l'export GLB remet le modèle dans le repère de Godot. Les pivots sont listés dans `asset-info.json`.

Dans Godot, `scenes/boss.tscn` conserve la collision de gameplay séparée du GLB. `scripts/boss.gd` reprend les impacts détaillés des sentinelles et ajoute l'alternance des deux armes, leur animation, le verrouillage, les rafales et la seconde phase. `scripts/boss_director.gd` utilise une grille avec une marge suffisante pour tourner sans traverser les obstacles ; il confine le boss à la cour du cœur HELIX.

Le troisième relais de la mission réveille CERBÈRE. Sa mort ouvre la porte d'extraction. La vie, les dégâts, les temps de préparation et les rafales suivent les trois difficultés ; pause et redémarrage conservent les règles du jeu. **Affronter Cerbere.cmd** permet d'essayer directement ce combat sans refaire les trois secteurs.

CERBÈRE utilise aussi `enemy_tactics.gd` pour choisir des angles de tir accessibles avec sa propre grille et chercher la dernière position connue après une perte de vue. Il se déplace un peu plus vite et réduit ses temps morts en Moyen et Difficile. Sa santé, ses dégâts, la durée des avertissements et le nombre de tirs par rafale sont conservés ; sa visée annoncée reste figée pendant chaque rafale.

Une fois neutralisé, CERBÈRE s'écrase avec ses deux mitrailleuses. Son modèle entier devient une épave physique aux optiques éteintes ; le choc métallique joue au contact du décor. La carcasse reste jusqu'à la fin de la partie, puis est retirée au redémarrage. `scripts/drone_wreck.gd` utilise une enveloppe convexe du modèle et conserve les matériaux des drones encore vivants.

`preview.png` montre le rendu studio Blender. `preview_combat.mp4` et `preview_combat.gif` montrent un combat enregistré dans Godot avec le vrai fusil, les projectiles et les débris. `record_preview.gd` permet de refaire l'enregistrement avec le mode Movie Maker de Godot.

Vérifications dans le vrai moteur : `tests/verify_boss.gd` couvre le GLB, les deux armes, les déplacements, les collisions, les tirs réels, l'esquive, les deux phases, la jauge, la progression jusqu'à la victoire, la pause et les redémarrages. Les suites de mission et de difficulté couvrent aussi le boss dans leur parcours complet.
