# HELIX — Les deux gardiens

**Version Web locale :** dans `C:\code\jeux`, double-cliquez sur **Jouer HELIX Web.cmd**. Le lanceur sert l'export sur `http://127.0.0.1:8765/` et ouvre le navigateur. Gardez sa fenêtre de serveur ouverte pendant la partie. Utilisez un navigateur de bureau avec WebGL2, un clavier et une souris. Cliquez sur **Commencer la mission**, puis sur **Reprendre la mission** après une pause : Échap libère la souris et met en pause. Les autres commandes sont celles du jeu PC. Fermer la fenêtre du serveur arrête la démo locale.

L'export est dans `..\exports\helix-web`. Ouvrir directement `index.html` par double-clic ne suffit pas : il faut le serveur local. Le lanceur utilise Python 3, déjà présent sur cette machine. **Exporter HELIX Web.cmd** reconstruit l'export avec Godot portable et les templates officiels 4.7.2. Les détails de validation et limites sont dans [WEB.md](WEB.md).

Le projet démarre sur une campagne de **deux étages**, dans une enveloppe totale de **132 × 308 mètres** : 25 gardes (16 drones et 9 chiens robots) et deux boss. Le premier niveau conserve ses sept zones, ses trois relais et CERBÈRE. Sa défaite déverrouille un véritable ascenseur qui monte de **14 mètres**. Le second niveau ajoute un chenil, une usine de limiers, deux consoles de sécurité et l’antre de **FENRIR**, le grand boss quadrupède à deux canons laser. L’extraction finale se trouve derrière son antre.

**Pour jouer :** lancez **Jouer DroneArena.cmd** puis **Commencer la mission**. Entrez entièrement dans la cabine après CERBÈRE et appuyez sur **E**. À l’étage supérieur, neutralisez les cinq gardes de chaque secteur et activez sa console avec **E**. Vainquez FENRIR, puis restez deux secondes dans la zone d’extraction cyan. Relais, consoles et arrivée de l’ascenseur restaurent la santé. La carte suit automatiquement l’étage.

**Affronter Fenrir.cmd** permet d’essayer directement le nouveau boss. **Ouvrir Fenrir dans Blender.cmd** ouvre son modèle original, conçu séparément du LIMIER : quatre pattes articulées, blindage, mâchoire dentée, dorsale, deux canons et deux repères de sortie. La campagne complète reste le lancement par défaut.

Le **LIMIER K-9** poursuit le joueur au sol, contourne les installations et s'arrête pour tirer deux impulsions laser roses après un avertissement rouge et sonore. Déplacez-vous latéralement pour esquiver. Ses quatre pattes sont articulées, ses pas sont audibles et sa carcasse reste au sol après sa neutralisation. Vous en trouverez un dans chaque secteur du premier étage, six au deuxième étage et un dans l’entraînement. **Ouvrir le chien robot dans Blender.cmd** permet de modifier le modèle original ; le guide est dans `art/hound/README.md`.

Les drones et CERBÈRE tirent des **impulsions laser rouge-orange allongées**, avec un cœur incandescent, à la place des boules lumineuses. Les avertissements, les vitesses des impulsions, les dégâts et les possibilités d'esquive sont conservés. Les lasers roses du LIMIER utilisent la même forme de trait. Chaque trait s'allonge derrière sa pointe, seulement sur la distance déjà parcourue, et s'arrête au contact du décor.

**Les ennemis cherchent maintenant des angles de tir et se coordonnent.** Les drones prennent des flancs différents, les limiers avancent et se replacent entre leurs rafales, et CERBÈRE choisit des positions accessibles autour des installations. Un impact les pousse à changer de côté. Un ennemi qui vous voit prévient ses alliés proches ; vos tirs attirent également les hostiles actifs à proximité. Si vous disparaissez derrière un obstacle, ils cherchent votre dernière position connue. Changez de couverture après avoir rompu la ligne de vue pour les semer ; tirer depuis votre nouvelle cachette peut vous révéler à nouveau.

En **Moyen et Difficile**, les déplacements sont environ 10 % plus rapides et les temps morts entre attaques un peu plus courts. Le rythme du mode **Facile**, les points de vie, les dégâts et la durée des avertissements sont conservés. Le point annoncé par un laser reste fixe pendant le tir ou la rafale pour permettre l'esquive. Les secteurs futurs restent dormants, même si vous tirez depuis le quai sûr. La pause suspend aussi la mémoire et les décisions des ennemis.

**La base possède maintenant des plafonds techniques et des verrières donnant sur l'espace.** Les poutres, panneaux ventilés, néons cyan et ambre et luminaires éclairent les intérieurs. Le cargo, le refroidissement et la salle du boss ont de grandes verrières ; les annexes sont davantage couvertes. Le ciel nocturne montre des étoiles et une Voie lactée mauve sur fond noir. L'entraînement et le combat direct contre CERBÈRE utilisent la même ambiance. Pour les modifier, ouvrez `environment/mission_roofs.tscn` ou `environment/training_roofs.tscn` ; `environment/space.tres` contient les réglages du ciel.

Lancez **Jouer DroneArena.cmd** ou **Jouer Les trois relais.cmd**, choisissez **Facile**, **Moyen** ou **Difficile**, puis **Commencer la mission**. Neutralisez les ennemis de chaque secteur, approchez du relais et appuyez sur **E**. Chaque relais restaure votre santé. Les deux premiers ouvrent une porte ; le troisième réveille **CERBÈRE**, un boss massif à deux mitrailleuses rotatives. Détruisez-le pour débloquer l’ascenseur. Montez ensuite affronter FENRIR ; l’extraction finale se trouve au-delà de son antre. Le panneau d'objectif et la carte vous guident.

**Affronter Cerbere.cmd** permet d'essayer directement le boss avec la difficulté de votre choix. Ses lasers rouges annoncent les rafales : esquivez latéralement et tirez entre deux salves. À mi-vie, il passe en surchauffe et accélère ses attaques. **Ouvrir le boss dans Blender.cmd** ouvre son modèle original, exporté dans `assets/models/helix_boss.glb`.

| Niveau | Impacts pour détruire un drone | Dégâts d'un projectile ennemi | Rythme |
| --- | --- | --- | --- |
| Facile | 2 | 5 | Drones et projectiles plus lents, tirs plus espacés, avertissement plus long |
| Moyen | 3 | 10 | Ennemis mobiles, contournements et pression modérée |
| Difficile | 4 | 15 | Drones et projectiles plus rapides, tirs plus fréquents, avertissement plus court |

Le choix est mémorisé et s'applique aussi à l'entraînement. Le niveau actif est affiché à côté de la santé. Depuis **Échap**, vous pouvez préparer un autre niveau puis cliquer sur **Recommencer** : **Reprendre** conserve les réglages et la progression de la partie en cours. Après une défaite ou une victoire, choisissez le niveau avant de rejouer. Votre santé maximale reste de 100 et les objectifs ne changent pas.

**F5 lance la mission.** Le [guide de mission](missions/relay_run/README.md) explique le parcours, les soins et les fichiers à modifier. **Ouvrir la mission dans Blender.cmd** permet de voir le nouveau décor et **Exporter la mission vers Godot.cmd** d'exporter une modification manuelle de ses matériaux.

**Jouer entrainement.cmd** conserve l'arène initiale. Le guide ci-dessous décrit cet entraînement et les composants communs (arme, drone, cibles et éditeur).

# Guide de l'arène d'entraînement

L'entraînement oppose le joueur à **deux drones aériens et un chien robot LIMIER K-9**, avec une jauge de vie. Vous pouvez vous déplacer, viser, sauter, recharger et tirer pour sécuriser l'arène. Les quatre cibles d'entraînement restent disponibles.

## 1. Ouvrir le projet

Dans le dossier `C:\code\jeux`, double-cliquez sur **Ouvrir DroneArena.cmd**. Godot démarre avec le projet et la scène principale. Le premier lancement peut prendre un peu de temps pour préparer les shaders et les ressources.

Godot 4.7.2 standard est déjà décompressé dans `.tools\godot` à côté du projet. Aucun compte ni installation supplémentaire n'est nécessaire. Pour importer le projet sur une autre machine, utilisez **Importer** dans Godot et choisissez le fichier `DroneArena\project.godot`.

## 2. Lancer et explorer

Lancez **Jouer entrainement.cmd**, ou ouvrez `scenes/main.tscn` dans Godot et utilisez **F6**, puis cliquez sur **Entrer dans l'arène**. Vous pouvez aussi sélectionner le bouton au clavier et appuyer sur Entrée.

| Commande | Action |
| --- | --- |
| ZQSD ou WASD | Se déplacer |
| Flèches directionnelles | Autre possibilité pour se déplacer |
| Maj maintenue + déplacement | Courir, sans limite d'endurance |
| Ctrl maintenu | S'accroupir et se déplacer plus lentement |
| Souris | Regarder autour de soi |
| Espace | Sauter |
| Clic gauche | Tirer une impulsion |
| Clic droit maintenu | Visée précise dans le viseur de la carabine |
| R | Recharger la carabine en 1,8 seconde |
| Maintenir le clic gauche | Enchaîner les tirs, à cinq impulsions par seconde |
| Échap | Mettre en pause, libérer la souris ou reprendre |
| Reprendre l'exploration | Revenir dans le jeu depuis le menu de pause |
| Recommencer l'arène | Nouvelle partie : position, santé, drones et compteurs réinitialisés |
| F8 dans l'éditeur | Arrêter le jeu |

Le jeu se met aussi en pause si sa fenêtre perd le focus, par exemple avec Alt+Tab. Dans Godot, si le jeu est affiché dans le panneau intégré **Jeu**, cliquez à l'intérieur pour lui donner le focus. Pour jouer directement dans une fenêtre séparée, double-cliquez sur **Jouer DroneArena.cmd**.

**Courir et s'accroupir fonctionnent dans l'entraînement, la mission et le combat direct contre CERBÈRE.** La marche reste à 6 m/s, la course atteint 9,5 m/s et le déplacement accroupi 3 m/s. Relâchez Maj pour marcher. Ctrl abaisse progressivement la caméra et réduit réellement la collision du personnage ; relâchez-le pour vous relever. Si un plafond bloque le passage, vous restez accroupi jusqu'à avoir assez de place. Vous pouvez viser et tirer dans cette position ; pour sauter ou courir, relevez-vous d'abord. La pause fige également la posture, et recommencer remet le personnage debout.

**Maintenez le clic droit pour viser précisément**, puis utilisez le clic gauche pour tirer. La carabine se centre pour aligner son viseur avec un point fin à l'écran ; le zoom modéré agrandit les cibles, la souris devient moins sensible et le recul visuel est réduit. La transition est progressive. Relâchez le clic droit pour retrouver la vue normale. En visant, vous quittez le sprint et avancez à 4 m/s ; accroupi, vous restez à 3 m/s. Les tirs gardent leur cadence, leur portée et leurs dégâts habituels, et les obstacles continuent de les arrêter.

La pause, la perte de focus, la défaite et le redémarrage annulent la visée. Si vous gardez le clic droit pendant un menu, relâchez-le puis appuyez à nouveau pour viser après la reprise. Cette commande fonctionne aussi dans la mission et contre CERBÈRE.

La carabine **H-01** possède un chargeur de **30 impulsions**. Le compteur en bas à droite affiche les tirs restants ; il devient orange à cinq impulsions ou moins et rouge à vide. Appuyez sur **R** pour recharger en **1,8 seconde**, même avant d'avoir vidé le chargeur. Une animation, des sons de manipulation et une barre indiquent la progression. Les réserves sont illimitées, mais il faut recharger manuellement : à vide, le clic produit seulement un bruit de mécanisme. Pendant la recharge, vous pouvez vous déplacer, courir ou vous accroupir ; les tirs et la visée précise sont suspendus. Le clic droit maintenu retrouve la visée à la fin. La pause fige l'animation, le son et le délai ; recommencer redonne un chargeur plein. Ces règles s'appliquent à l'entraînement, à la mission et à CERBÈRE, dans les trois difficultés.

Visez avec le réticule au centre de l'écran. Les anneaux lumineux cyan repèrent les quatre cibles. Une cible touchée se rabat, affiche **TOUCHÉ**, puis se relève après **deux secondes de jeu**. Le réticule affiche brièvement une croix orange et le compteur de touches augmente. Une même cible peut être touchée à nouveau lorsqu'elle s'est relevée.

Les murs et obstacles arrêtent les tirs. Le recul est visuel : il ne déplace pas le réticule. Un flash, une trace lumineuse, un impact et un son accompagnent le tir. Une confirmation sèche et discrète accompagne les touches.

Les tirs disposent d'un claquement marqué et d'un corps grave, avec plusieurs variantes pour les rafales. Chaque impact sur un drone produit un choc métallique à son emplacement. Un drone abattu tombe avec son modèle entier, puis fait entendre un choc au contact du décor. Les tirs ennemis possèdent leur propre son spatialisé. Un limiteur protège la marge du mix lorsque plusieurs sons se superposent. Tous ces sons sont synthétisés pour le projet, sans banque externe. Le guide `art/audio/README.md` explique leur fabrication.

Les drones font également entendre leurs **hélices**, placées dans l'espace et atténuées avec la distance. CERBÈRE possède un grondement plus grave. Les moteurs restent silencieux avant l'activation d'un secteur et s'arrêtent à la destruction du drone. Dans la mission, **E sur un relais** produit une confirmation ou un refus s'il est encore gardé ; les **portes** jouent leur déverrouillage, leur moteur et leur butée pendant leur ouverture. Un son confirme aussi les kits de réparation consommés. La pause suspend ces sons et recommencer remet leur état à zéro. L'extrait `art/audio/preview_mechanical.wav` présente les hélices et les interactions enregistrées dans Godot.

Les impacts sur les drones arrachent aussi des fragments de blindage, des boulons et des fils, avec des étincelles et une légère fumée au point touché. Ces petits fragments rebondissent puis disparaissent progressivement. **Le tir fatal provoque un écrasement, sans explosion** : les lumières du drone s'éteignent, ses hélices ralentissent et sa carcasse tombe, rebondit puis reste au sol pendant toute la partie. Les épaves solides arrêtent les tirs et restent présentes lors des changements de secteur, y compris celle de CERBÈRE. Elles sont retirées au redémarrage ou en quittant la scène. La pause fige également leur chute. Le guide `art/effects/README.md` présente les impacts et les épaves.

**Échap** suspend également les drones, les projectiles, les cibles et les effets. Après avoir cliqué sur Reprendre, relâchez le bouton de la souris avant de tirer à nouveau. **Recommencer l'arène** remet aussi votre santé, les drones, les cibles et les compteurs à zéro.

## Combattre les sentinelles

Vous commencez avec **100 points de vie**, affichés en haut à gauche en chiffres et sous forme de jauge. Les trois sentinelles se rapprochent de vous, contournent les grands obstacles et volent au-dessus des petits. Elles commencent à tirer après un court délai au début de la partie.

- **Viseur rouge et indication VERROUILLAGE** : le drone prépare son tir pendant 0,9 seconde en Facile, 0,6 en Moyen et 0,4 en Difficile. Déplacez-vous latéralement pour esquiver sa position de visée.
- **Projectile orange** : il se déplace réellement et inflige **5, 10 ou 15 points de dégâts** selon la difficulté. Un obstacle situé sur sa trajectoire l'arrête. Les obstacles trop bas pour masquer le joueur n'offrent pas une couverture complète.
- **Deux, trois ou quatre impacts de carabine** neutralisent un drone, selon le niveau choisi. La petite barre au-dessus de lui diminue à chaque touche ; le tir fatal coupe ses moteurs et provoque sa chute. Son épave reste dans l'arène jusqu'à la prochaine partie.
- Votre écran rougit brièvement lorsque vous êtes touché. La jauge devient rouge à **30 points de vie ou moins**. Une protection de 0,35 seconde évite d'additionner des impacts simultanés.
- À **zéro**, le jeu s'arrête sur **Signal perdu**. Cliquez sur **Recommencer l'arène** pour repartir avec toute votre vie et les trois drones. Échap ne permet pas de reprendre une partie perdue.

Le compteur **Drones neutralisés** est séparé du compteur des cibles d'entraînement. Une fois les trois ennemis détruits, **ZONE SÉCURISÉE** s'affiche et vous pouvez continuer à explorer. Ils ne réapparaissent pas avant une nouvelle partie. Cette étape ne comporte pas de régénération automatique ni de trousse de soin.

**F5 lance la mission. F6 lance uniquement la scène sélectionnée.** Pour l'entraînement, utilisez F6 lorsque l'onglet `scenes/main.tscn` est sélectionné : les scènes `arena.tscn`, `player.tscn` et `cover.tscn` sont des éléments du jeu, pas des jeux complets.

## 3. Reconnaître l'éditeur

- **Au centre, la vue 3D** montre le décor. Pour naviguer dans cette vue, maintenez le bouton droit de la souris et déplacez la souris. La molette permet de zoomer.
- **À gauche, Scène** présente l'arbre des objets : `Main`, `Arena`, `Player` et `Interface`. Une scène est un assemblage d'objets, appelés « nœuds » dans Godot.
- **En bas à gauche, Système de fichiers** contient les scènes, les scripts et les matériaux du projet.
- **À droite, Inspecteur** permet de changer les propriétés de l'objet sélectionné : position, taille, couleur, etc.
- **En bas, Sortie et Débogueur** affichent les messages et les erreurs éventuelles.

Pour bien voir un objet dans l'éditeur, sélectionnez-le dans l'arbre de scène puis appuyez sur **F** avec le pointeur dans la vue 3D.

## 4. Votre première modification : changer une couleur du décor

Le décor détaillé est maintenant créé dans Blender et importé au format GLB.

1. Dans `C:\code\jeux`, double-cliquez sur **Ouvrir le decor dans Blender.cmd**.
2. Sélectionnez une bande orange d'une caisse ou d'un mur. Dans **Material Properties / Propriétés de matériau**, sélectionnez **HX_Orange_Securite** et modifiez **Base Color / Couleur de base**.
3. Enregistrez le fichier Blender avec **Ctrl+S**, puis lancez **Exporter le decor vers Godot.cmd** dans le dossier du jeu.
4. Revenez dans Godot pour laisser la réimportation se terminer, puis relancez avec **F5**.

Le matériau est partagé par les pièces orange du décor : elles changent ensemble. Le guide `art/arena/README.md` détaille les pièces et l'export. Les positions et les collisions restent réglées dans Godot.

## 5. Organisation du projet

| Élément | Rôle |
| --- | --- |
| `scenes/main.tscn` | Assemble le décor, le personnage et l'interface |
| `scenes/arena.tscn` | Sol, murs, obstacles, éclairage et signalétique |
| `scenes/player.tscn` | Corps du personnage, tête et caméra |
| `scenes/weapon.tscn` | Carabine, mains, flash et sons ; suit la caméra |
| `scenes/target.tscn` | Cible d'entraînement réutilisable |
| `scenes/drone.tscn` | Corps, rotors, œil lumineux et barre de vie des sentinelles |
| `assets/models/helix_sentinel.glb` | Modèle détaillé des sentinelles, exporté depuis Blender |
| `assets/models/helix_carbine.glb` | Carabine détaillée et mains gantées, exportées depuis Blender |
| `assets/models/helix_arena.glb` | Sol, murs, marches, réacteur et bâtiments du fond |
| `assets/models/helix_cover.glb`, `helix_storage.glb` | Modèles des caisses, montés sur les collisions existantes |
| `assets/models/helix_target_base.glb`, `helix_target_plate.glb` | Pied fixe et disque basculant des cibles détaillées |
| `scenes/enemy_bolt.tscn` | Projectile ennemi visible |
| `scenes/cover.tscn`, `tower.tscn` | Obstacles réutilisables |
| `scripts/player.gd` | Déplacements, saut et visée |
| `scripts/main.gd` | Accueil, pause et reprise |
| `scripts/difficulty.gd` | Trois niveaux de difficulté et mémorisation du choix |
| `scripts/weapon.gd` | Cadence, détection des impacts et effets de tir |
| `scripts/target.gd` | Cible touchée et réapparition |
| `scripts/drone.gd` | Poursuite, verrouillage, tirs et destruction |
| `scripts/drone_wreck.gd` | Chute physique, choc métallique et épaves persistantes |
| `scripts/drone_director.gd` | Carte de vol et réinitialisation des trois ennemis |
| `scripts/enemy_bolt.gd` | Trajet du projectile, collision et dégâts |
| `audio/` | Sons originaux du tir et de la touche |
| `materials/` | Matériaux des cibles, effets et autres éléments Godot |

Tous les objets du décor sont enregistrés dans les scènes et visibles dans l'éditeur. Ils ne sont pas fabriqués au lancement par un script caché.

Pour découvrir l'arme dans l'éditeur, ouvrez `scenes/weapon.tscn` depuis Système de fichiers : `Model/VisualModel` contient l'instance du modèle Blender. Revenez à `main.tscn` ou utilisez **F5** pour tester le jeu complet. Dans la scène de l'arme, les propriétés **Fire Interval** et **Max Range** règlent respectivement le délai entre les tirs et leur portée.

La carabine détaillée **HELIX H-01** comporte une coque biseautée, un garde-main ventilé, des bobines, une batterie lumineuse, un viseur ouvert et des mains gantées. Double-cliquez sur **Ouvrir l'arme dans Blender.cmd**, dans `C:\code\jeux`, pour ouvrir sa source `art/carbine/helix_carbine.blend`. Les pièces y restent séparées et modifiables ; `art/carbine/README.md` explique comment exporter les changements. Le marqueur `Model/Muzzle`, le flash, la lumière et les sons restent dans Godot. Le script de tir est inchangé.

Pour découvrir les ennemis, ouvrez `scenes/drone.tscn`. Les rotors et le corps sont des objets modifiables. Dans `main.tscn`, développez **Drones** et sélectionnez une sentinelle pour changer sa vitesse (**Move Speed**), son délai entre les tirs (**Fire Interval**) ou son activation du tir (**Attack Enabled**). La carte de vol se reconstruit au début d'une partie et après **Recommencer l'arène**, à partir des collisions du décor.

Le drone utilise maintenant le modèle détaillé **HELIX S-07**, sous `Hull/VisualModel`. Sa source Blender est enregistrée dans `C:\code\jeux\art\sentinel\helix_sentinel.blend`. Double-cliquez sur **Ouvrir le drone dans Blender.cmd** dans le dossier du jeu pour le modifier. Le guide `art/sentinel/README.md` explique l'export et les pivots à conserver. Le GLB contient les matériaux et les hélices ; les collisions, les indicateurs de vie et le comportement restent gérés par la scène Godot.

Le décor détaillé partage le style du drone et de l'arme. Sa source complète est `C:\code\jeux\art\arena\helix_arena.blend`. **Ouvrir le decor dans Blender.cmd** permet de modifier ses pièces ; **Exporter le decor vers Godot.cmd** exporte ensuite la source enregistrée vers les trois GLB. Les quatre caisses basses et les deux caisses hautes restent des scènes réutilisables : déplacer `Obstacle_A01`, par exemple, déplace le modèle avec sa collision. Les cibles, les textes de signalétique et l'éclairage restent gérés par Godot. Les 21 collisions ont été conservées, ainsi que les passages et la carte de vol des drones.

Les quatre cibles utilisent désormais le modèle détaillé **HELIX T-07**. Dans `scenes/target.tscn`, **BaseVisual** contient le pied fixe et **Plate/PlateVisual** le disque qui bascule. Le collider et le script de réaction aux tirs sont inchangés. **Ouvrir la cible dans Blender.cmd** ouvre `art/target/helix_target.blend` ; **Exporter la cible vers Godot.cmd** exporte ensuite les deux parties depuis la source enregistrée. Le guide `art/target/README.md` explique les matériaux, les origines et les dimensions à garder. Les noms et les états restent affichés par Godot, au-dessus de la couronne.

## Vérifications techniques

Depuis PowerShell, dans `C:\code\jeux` :

```powershell
# Import et vérification des ressources/scripts.
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path '.\DroneArena' --import

# Tests du projet et de sa physique, sans fenêtre.
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path '.\DroneArena' --script res://tests/verify.gd --fixed-fps 60

# Drones, dégâts, couverture, esquive, défaite et nouvelle partie.
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path '.\DroneArena' --script res://tests/verify_combat.gd --fixed-fps 60

# Modèle GLB, taille, axes, pivots, animation et intégration.
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path '.\DroneArena' --script res://tests/verify_glb.gd --fixed-fps 60

# Carabine GLB, ombres, échelle, canon et alignement durant le recul.
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path '.\DroneArena' --script res://tests/verify_carbine.gd --fixed-fps 60

# Chargeur, R, recharge, pause et victoire sur le boss avec plusieurs chargeurs.
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path '.\DroneArena' --script res://tests/verify_reload.gd --fixed-fps 60

# Perception, radio, bruit des tirs, mémoire, flancs opposés et pause de l'IA.
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path '.\DroneArena' --script res://tests/verify_tactics.gd --fixed-fps 60

# Décor GLB, 21 collisions et carte de vol identiques au relevé initial.
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path '.\DroneArena' --script res://tests/verify_arena.gd --fixed-fps 60

# Cible GLB, collision, pied fixe, bascule, pause et retour après un tir.
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path '.\DroneArena' --script res://tests/verify_target.gd --fixed-fps 60

# Même scénario avec rendu Forward+ et capture souris native.
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --path '.\DroneArena' --script res://tests/verify.gd --fixed-fps 60 --resolution 1280x800
```

La vérification graphique écrit ses captures dans `tests/artifacts/`. Le mode sans fenêtre ne peut pas vérifier la capture du pointeur : ce contrôle est réservé au lancement graphique.

Le scénario vérifie également le tir au clic et en maintien, la cadence, la visée sur une cible, l'arrêt des tirs sur un mur ou lorsque le canon dépasse derrière une paroi, le rabattement et le retour des cibles, les sons déclenchés, la libération des effets et l'absence de tir dans les menus.

`verify.gd` isole les contrôles et la carabine du combat. `verify_combat.gd` vérifie les déplacements et attaques réels des drones, les protections du joueur et le cycle de partie. Pour lancer cette seconde suite avec le rendu graphique, retirez `--headless` et ajoutez `--resolution 1280x800`.

Le projet utilise le rendu **Forward+**. Si Godot signale une erreur de pilote graphique, gardez le message exact pour le diagnostic ; aucune modification de votre pilote n'est effectuée par ce projet.

La licence MIT du moteur Godot et ses crédits sont disponibles sur https://godotengine.org/license/. Le décor et l'interface de ce prototype n'utilisent aucun pack d'assets externe.
