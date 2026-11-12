# Deuxième étage de HELIX

`build_campaign.py` est appelé automatiquement par `art/mission/build_scenes.py`. Il génère `upper_map.tscn`, les plans de navigation, `elevator.tscn`, la scène du boss et les nouveaux nœuds de `mission.tscn`. Le premier niveau et ses collisions sont conservés par le générateur historique. L’export manuel Blender du premier niveau ne modifie pas ces scènes.

Les sorties sont générées : pour conserver une variante manuelle, copiez-la avant une reconstruction. Pour modifier durablement les salles, modifiez ce générateur. Le comportement de la mission reste dans `missions/relay_run/mission.gd` et n’est jamais généré.

Le plancher supérieur est à +14 m. Le palier comporte un trou réel pour la cabine de 6 × 8 m. Celle-ci est un `AnimatableBody3D` qui transporte le contrôleur du joueur par la physique. Aucun déplacement du joueur par script n’est utilisé pendant le trajet. La porte sud ferme avant la montée ; la porte nord s’ouvre à l’arrivée. Le raccourci de test de FENRIR place explicitement le joueur dans son antre et reste distinct du parcours normal.

Les dix nouveaux gardes sont répartis en deux secteurs de cinq (deux drones et trois limiers chacun). Leurs grilles de navigation sont échantillonnées sur le plancher supérieur ; le grand boss possède une enveloppe de marche distincte, adaptée à son gabarit.

Vérifications : `tests/verify_mission.gd` (premier niveau), `verify_campaign.gd` (montée, parcours physique complet du deuxième étage et victoire), `verify_elevator.gd` (confinement, réinitialisation en mouvement et raccourci FENRIR). Les tests peuvent être exécutés en mode `--headless` ou avec l’affichage natif pour produire les captures.
