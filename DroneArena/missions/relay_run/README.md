# Campagne — Les deux gardiens

Dans `C:\code\jeux`, lancez **Jouer Les trois relais.cmd** ou **Jouer DroneArena.cmd**. Dans Godot, **F5** lance cette mission ; **F6** la lance si `missions/relay_run/mission.tscn` est la scène sélectionnée.

Choisissez **Facile**, **Moyen** ou **Difficile**, puis cliquez sur **Commencer la mission**. Le quai de départ est sûr jusqu'à la première ligne : deux cibles permettent de reprendre les commandes.

Levez les yeux : les grandes cours possèdent des verrières, à travers lesquelles on voit l'espace étoilé et la Voie lactée. Les annexes et les bords des salles ont des plafonds techniques avec néons cyan ou ambre. Ces modules sont dans `environment/mission_roofs.tscn`, séparés du décor Blender ; ils restent présents après un nouvel export de la mission.

| Niveau | Résistance d'un drone | Dégâts ennemis | Comportement |
| --- | --- | --- | --- |
| Facile | 2 impacts | 5 par projectile | Déplacements plus lents, tirs espacés, davantage de temps pour esquiver |
| Moyen | 3 impacts | 10 par projectile | Ennemis mobiles et contournements, pression modérée |
| Difficile | 4 impacts | 15 par projectile | Déplacements et projectiles plus rapides, tirs rapprochés, avertissement court |

Le niveau choisi est mémorisé entre les lancements et partagé avec l'entraînement. Le HUD indique celui de la partie en cours. Pour changer depuis la pause, sélectionnez un niveau puis **Recommencer la mission** ; **Reprendre** conserve la difficulté actuelle. Le même choix est proposé après une défaite ou une victoire. Les 25 gardes, les deux boss, les objectifs, les soins et les 100 points de santé maximale sont présents dans les trois difficultés.

## Objectif

1. Traversez le cargo et son annexe logistique. Neutralisez **3 drones et 1 LIMIER K-9**, approchez du relais logistique puis appuyez sur **E**.
2. La première porte s'ouvre. Explorez la cour de refroidissement et la maintenance technique. Neutralisez **4 drones et 1 LIMIER K-9** puis activez le deuxième relais.
3. Franchissez la deuxième porte, traversez le cœur HELIX et la centrale énergie. Neutralisez **5 drones et 1 LIMIER K-9** puis activez le dernier relais.
4. Le troisième relais réveille **CERBÈRE**, le boss du cœur HELIX. Détruisez ce drone massif à deux mitrailleuses pour déverrouiller l’accès à l’ascenseur.
5. Entrez entièrement dans la cabine, puis appuyez sur **E**. Les portes se ferment et l’ascenseur vous porte réellement de **14 mètres**, en huit secondes. Sortez au deuxième étage par la porte opposée.
6. Sécurisez le **chenil** : deux drones et trois limiers. Approchez de sa console orange sur la carte et appuyez sur **E** pour lever le premier verrou.
7. Traversez l’**usine des limiers**, neutralisez ses deux drones et trois limiers, puis activez la deuxième console. La porte de l’antre s’ouvre.
8. Abattez **FENRIR / HELIX ALPHA**. Ce quadrupède de plus de quatre mètres de haut alterne ses deux canons après une visée rouge figée. À mi-vie, la rafale passe de quatre à six lasers. Bougez latéralement et rechargez derrière les couvertures.
9. Rejoignez la zone cyan d’**extraction orbitale**, au fond de l’antre, et restez en son centre pendant **deux secondes**. La victoire demande de vaincre les deux gardiens. Le bilan compte les 27 hostiles, le temps et la santé.

Chaque annexe possède deux entrées : vous pouvez contourner les installations et revenir par un autre passage. La cour de refroidissement possède une passerelle à trois mètres de hauteur, accessible par ses deux rampes. Le réacteur et les caisses donnent des repères et des couvertures.

Les **chiens robots LIMIER K-9** sont plus rapides au sol que les drones. Un avertissement rouge et sonore précède leurs deux impulsions laser roses : quittez le point annoncé pour les esquiver. Leurs pas mécaniques aident à les repérer. Leur résistance suit les difficultés, comme celle des drones ; chaque impulsion inflige 3, 6 ou 9 dégâts en Facile, Moyen ou Difficile. Leurs carcasses restent dans le décor. Le compteur **HOSTILES** regroupe les 25 gardes des deux étages et les deux boss ; tous les gardes du secteur doivent être neutralisés avant d'activer le relais.

Les ennemis proches partagent leurs repérages et cherchent des angles de tir accessibles. Les drones tentent de prendre des flancs différents ; les limiers se rapprochent et changent de position entre deux rafales. Vos tirs les alertent à proximité. Après une perte de vue, ils fouillent la dernière position connue : changez de couverture pour les surprendre. Les déplacements et les temps morts sont un peu plus agressifs en Moyen et Difficile ; les dégâts, la résistance et les préavis restent identiques. La zone de départ et les secteurs dormants conservent leurs protections.

Les hélices permettent aussi de repérer les drones à l'oreille ; les turbines de CERBÈRE ont une sonorité plus grave. L'activation d'un relais joue une confirmation près du terminal et déclenche le son de la porte qu'il ouvre. Cette porte peut être loin du relais : son moteur reste placé à son emplacement dans le décor. Un relais encore gardé émet un refus lorsque vous essayez de l'activer à proximité. Les kits consommés jouent une confirmation de réparation. Ces sons suivent la pause, et le redémarrage arrête ceux de la partie précédente.

Le premier étage occupe une enveloppe de **132 × 170 mètres**, répartie en **sept zones**. Le deuxième étage ajoute cinq zones à +14 mètres, jusqu’à 92 mètres de large et 154 mètres de long. L’enveloppe totale atteint **132 × 308 mètres**. L'enveloppe n'est pas une surface entièrement remplie : les bâtiments dessinent des annexes et des cours. Le parcours entre les relais impose plusieurs centaines de mètres de déplacement.

## Se repérer et survivre

- Le panneau à gauche indique l'objectif, la distance à vol d'oiseau, les ennemis restants et le chronomètre.
- La carte à droite garde le nord en haut. La carte change automatiquement d’étage. Le triangle représente le joueur ; le point orange indique le relais en cours. Les points verts indiquent les relais rétablis et le cyan indique l'extraction.
- Les pointillés cyan au sol suggèrent un parcours. Les ouvertures des murs et les deux entrées des annexes permettent d'autres trajets.
- Un relais ne s'active qu'à proximité, après la neutralisation des ennemis du secteur. Il restaure **100 points de santé**. Les deux premiers ouvrent une porte ; le troisième réveille le boss.
- Huit kits **RÉPARATION +40** rendent jusqu'à 40 points, sans dépasser 100. Ils sont consommés au contact uniquement si vous êtes blessé.
- En Moyen, trois impacts détruisent un drone et son projectile inflige 10 points de dégâts. Le tableau ci-dessus détaille les autres niveaux. Bougez et utilisez les installations pour couper sa ligne de tir.

**ZQSD/WASD** : déplacement ; **Maj maintenue** : courir ; **Ctrl maintenu** : s'accroupir ; **souris** : regarder ; **clic droit maintenu** : visée précise ; **Espace** : saut ; **clic gauche** : tir ; **R** : recharger ; **E** : relais ; **Échap** : pause et souris libre. La pause arrête aussi le chronomètre, l'ouverture des portes et l'extraction.

Le chargeur contient **30 impulsions**. Utilisez **R** pour recharger en **1,8 seconde**, à vide ou avant d'être à court. Le compteur en bas à droite avertit à cinq tirs restants ; une barre indique la recharge. Les réserves restent illimitées. Les tirs et la visée précise sont bloqués pendant cette manipulation, tandis que vos déplacements restent libres. La pause fige le rechargement et son son ; une nouvelle partie restaure un chargeur plein. Les relais soignent le joueur et les munitions se rechargent avec R.

La course est illimitée et permet aussi de prendre de l'élan avant un saut. Accroupi, vous avancez plus lentement avec une caméra et une collision plus basses ; vous pouvez toujours viser et tirer. Relâchez Ctrl pour vous relever : si un obstacle vous surplombe, le personnage attend d'avoir assez de place. Il faut être debout pour sauter ou courir. Les sentinelles et CERBÈRE visent votre hauteur réelle lorsque vous êtes à découvert.

Le clic droit centre le viseur de la carabine sur un point fin, avec un zoom modéré, une sensibilité réduite et un recul visuel plus contenu. Maintenez-le et tirez au clic gauche ; relâchez-le pour retrouver la vue normale. En visant, vous quittez le sprint et avancez à 4 m/s, ou 3 m/s si vous êtes accroupi. La pause annule le zoom ; relâchez le clic droit avant de le réutiliser après la reprise.

En cas de défaite, **Recommencer la mission** remet le joueur, les relais, les portes, les ennemis, les soins et les compteurs à leur état initial. Aucun point de sauvegarde n'est conservé après la fermeture du jeu.

Les drones abattus s'écrasent avec leur modèle entier, puis laissent une **épave persistante**. Leurs lumières s'éteignent et un choc métallique accompagne le contact avec le décor. Les carcasses restent dans leurs secteurs jusqu'à la fin de la mission, y compris celle de CERBÈRE ; elles arrêtent aussi les tirs. Le compteur est validé dès la neutralisation. La pause suspend les chutes, et recommencer nettoie toutes les épaves.

## Affronter CERBÈRE

Le boss se déplace dans la cour du cœur HELIX, contourne le réacteur et les obstacles, et reste dans cette arène. Sa jauge rouge et son repère sur la carte apparaissent à son réveil. Ses quatre turbines et les six canons de chacune de ses mitrailleuses sont animés.

Les **deux lasers rouges** annoncent une rafale. Déplacez-vous latéralement dès le verrouillage : il vise le point annoncé pendant toute la rafale. Les deux armes tirent alternativement, puis se refroidissent. À **50 % de vie**, la phase **SURCHAUFFE** raccourcit les pauses et allonge les rafales. Les murs et les couvertures assez hautes arrêtent ses projectiles.

| Niveau | Impacts de carabine | Dégâts par projectile | Rafale phase 1 / phase 2 | Préavis phase 1 |
| --- | --- | --- | --- | --- |
| Facile | 32 | 4 | 8 / 10 | 1,45 s |
| Moyen | 44 | 6 | 10 / 12 | 1,15 s |
| Difficile | 60 | 8 | 12 / 14 | 0,95 s |

Pour l'essayer immédiatement, lancez **Affronter Cerbere.cmd** dans `C:\code\jeux`, choisissez la difficulté puis **Affronter le boss**. Ce raccourci commence devant CERBÈRE avec 100 points de vie ; sa destruction permet ensuite de rejoindre l'extraction. **Recommencer** relance ce combat. Les raccourcis habituels et F5 conservent la mission complète.

Le modèle original est dans `art/boss/helix_boss.blend`, ouvrable avec **Ouvrir le boss dans Blender.cmd** ; son export autonome est `assets/models/helix_boss.glb`. Le guide `art/boss/README.md` décrit ses pièces et ses sources.

## Retrouver l'arène d'entraînement

Lancez **Jouer entrainement.cmd**, ou utilisez le bouton **Terrain d'entraînement** de l'accueil ou du bilan de mission. Le prototype initial avec ses trois drones et ses quatre cibles est conservé dans `scenes/main.tscn`. Pour revenir à la mission, relancez son raccourci ou utilisez F5 dans Godot.

## Modifier la mission

- `mission.tscn` assemble le personnage, les quinze drones, le boss séparé et le HUD. `boss_trial.tscn` propose un accès direct au combat. Les composants d'arme, de cible et de drone sont partagés avec l'entraînement.
- `map.tscn` contient le modèle d'architecture, les collisions éditables, les caisses, les relais, les portes et les soins.
- `layout.json` est le plan commun aux générateurs Blender et Godot. Les unités sont des mètres ; X correspond à l'est, Y à la hauteur et Z au sud.
- `mission.gd` gère les objectifs ; `director.gd` adapte la navigation des drones ; `gate.gd` anime les portes ; `minimap.gd` affiche le plan.

L'architecture Blender et ses sources de génération se trouvent dans `C:\code\jeux\art\mission`. Le guide de ce dossier précise comment régénérer le décor et ses collisions ensemble.


## Ascenseur, FENRIR et fichiers du deuxième étage

L’ascenseur ne s’active qu’après CERBÈRE, lorsque le joueur est entièrement dans la cabine et posé au sol. La porte d’entrée reste fermée pendant la montée ; à l’arrivée, seule la sortie du deuxième étage s’ouvre. Le palier est sûr jusqu’à l’entrée du chenil. Échap fige aussi la cabine et son moteur. Recommencer remet la cabine en bas, referme toutes les portes, restaure les soins et supprime toutes les épaves.

- `upper_map.tscn` : décor et collisions du nouvel étage, modules visibles dans l’éditeur.
- `upper_layout.json` : plan et emplacements des consoles ; `alpha_layout.json` limite les déplacements du boss à son antre.
- `elevator.tscn` et `elevator.gd` : cabine `AnimatableBody3D`, portes physiques, rails, moteur et son d’arrivée.
- `../../scenes/fenrir.tscn` et `../../scripts/fenrir.gd` : boss, collisions, canons, deux phases et carcasse persistante.
- `../../../art/fenrir/helix_fenrir.blend` : modèle Blender original ; le GLB importé est `assets/models/helix_fenrir.glb`.
- `../../../art/campaign/build_campaign.py` : reconstruction de l’étage ; appelé automatiquement par `art/mission/build_scenes.py`. L’export manuel du décor Blender conserve cet étage.

**Affronter Fenrir.cmd** lance un essai indépendant directement dans son antre. Ce raccourci permet de choisir la difficulté et de recommencer sans refaire le premier niveau ; il n’altère pas la progression de la campagne normale.

| FENRIR | Facile | Moyen | Difficile |
| --- | --- | --- | --- |
| Points de vie | 60 | 85 | 115 |
| Dégâts par laser | 6 | 9 | 12 |
| Préavis initial | 1,8 s | 1,5 s | 1,25 s |

Les projectiles sont arrêtés par les obstacles. La visée reste fixe pendant les rafales. Les dix gardes supplémentaires utilisent les mêmes déplacements, sons et carcasses que leurs homologues du premier étage, avec une navigation propre au plancher supérieur.
