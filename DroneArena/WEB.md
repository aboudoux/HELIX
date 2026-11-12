# HELIX Web — démonstration locale

Cette première adaptation utilise le jeu GDScript existant. La scène principale reste la campagne des deux gardiens ; le terrain d'entraînement est accessible depuis son accueil.

## Jouer

1. Dans `C:\code\jeux`, lancer **Jouer HELIX Web.cmd**.
2. Garder la fenêtre du serveur ouverte. Adresse : <http://127.0.0.1:8765/>.
3. Cliquer sur **Commencer la mission**. Ce geste autorise la capture de souris et l'audio.
4. **Échap** met en pause et libère le pointeur. Cliquer sur **Reprendre la mission** pour reprendre.
5. Fermer la fenêtre du serveur ou utiliser Ctrl+C pour l'arrêter.

Le serveur écoute uniquement `127.0.0.1`. Aucun site public ni déploiement externe n'a été créé. Ne pas ouvrir `index.html` en `file://`. Pour revenir de l'entraînement à la campagne, recharger la page du navigateur.

Clavier et souris : ZQSD/WASD ou flèches, souris pour regarder, clic gauche pour tirer, clic droit maintenu pour viser, R pour recharger, Maj pour courir, Ctrl pour s'accroupir, Espace pour sauter, E pour les interactions. En cas de refus de capture après Échap, attendre un instant puis cliquer de nouveau sur Reprendre ; le navigateur peut imposer ce délai.

## Ce qui a changé

- `project.godot` : réglages spécifiques `.web` pour Compatibility/WebGL2 et MSAA 2×. Le PC garde Forward+ et son anticrénelage initial.
- Audio Web en Stream, avec une latence demandée de 80 ms : le mixage du moteur, le limiteur et la spatialisation restent utilisables. Ce réglage est un compromis, pas une mesure de la latence réelle.
- `scripts/web_support.gd`, instancié uniquement sur Web par `main.gd` : pause après perte de capture, reprise par clic, protection contre le déplacement initial du pointeur, masquage du bouton Quitter, désactivation Web du glow et du SSAO et police de symboles embarquée.
- `export_presets.cfg` : export release sans threads ni GDExtension, sans PWA/service worker, incluant explicitement les JSON et excluant les tests.
- `tools/serve_web.py`, `tools/export-web.ps1` et deux lanceurs `.cmd` : lancer ou reconstruire la démo locale.

La sauvegarde préalable des originaux est dans `C:\code\jeux\.tools\backups\web-20261023-154919` (`project.godot`, `scripts/main.gd`, `LISEZ-MOI.md`). Les scènes, les règles de combat et les modèles d'origine n'ont pas été modifiés.

## Reconstruction

Lancer **Exporter HELIX Web.cmd**, ou :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\code\jeux\tools\export-web.ps1
```

L'export produit est dans `C:\code\jeux\exports\helix-web`. Conserver ensemble ses fichiers et leurs noms. Il pèse environ 74 Mio sans compression HTTP. Les templates Web officiels correspondant au moteur `4.7.2.stable.official.ed1daf0bf` ont été extraits dans `%APPDATA%\Godot\export_templates\4.7.2.stable`. Sur une autre machine, il faut Python 3 pour ce lanceur et les templates correspondants pour reconstruire. L'archive officielle est conservée dans `.tools\godot`.

## Vérifications et limites

Les preuves de cette session sont sous `C:\code\jeux\output\playwright` : captures `web-menu-final.png`, `web-aim.png`, `web-reload.png`, `web-pause.png`, `web-enemies.png`, `web-combat.png`, journaux d'export, contrôles navigateur et suites PC.

Chrome 155 sous Windows, canvas de 1280 × 800, coordonnées d'interface de 1440 × 900, RTX 3090 confirmée dans le navigateur via ANGLE/Direct3D11 :

- Export release réussi ; les JSON des deux étages apparaissent dans le journal du paquet. La campagne démarre dans un véritable navigateur local avec WebGL2 et sans erreur de console lors des contrôles finaux.
- 17/17 contrôles automatisés via Playwright réussis : accueil, capture effective du pointeur, souris, déplacement, sprint, accroupissement, saut, visée, tir en maintien, sortie WebAudio active, recharge, Échap, recharge figée en pause, reprise, fin de recharge, libération du pointeur sans touche et perte de focus.
- Le passage de l'accueil de campagne à l'entraînement, son démarrage et sa capture de souris ont aussi été vérifiés dans le navigateur. Le chargement normal sans `?diagnostics=1` n'expose pas la télémétrie de test. Les résultats sont dans `browser-training.json` et `browser-runtime.log`.
- La sortie audio a été mesurée dans WebAudio (contexte actif à 48 kHz, signal non nul). Cela prouve une sortie audio ; la qualité perçue, la latence de bout en bout et la précision de toute la spatialisation ne sont pas certifiées.
- Combat de campagne effectué par déplacements, rotations et tirs du navigateur : quatre ennemis du premier secteur neutralisés, santé descendue à 58/100, projectiles, impacts, débris et épaves visibles. Après contournement des obstacles de l'annexe, activation physique du premier relais avec E : passage à l'objectif suivant (`stage=1`) et santé restaurée à 100/100. Les outils ne donnent ni invulnérabilité ni téléportation. Les tentatives de progression sont conservées dans les journaux `browser-combat.json` et `browser-relay.json`.
- En regardant le quai, échantillons d'environ 40–54 images/s sur les passages de vérification. Pendant le combat, courts échantillons de 24 à 109 images/s selon l'angle et les effets. Il y a jusqu'à environ 4 700 appels de rendu dans les vues chargées. Ces observations locales ne sont ni un benchmark général ni une garantie de fluidité ; une baisse ponctuelle a été observée lors d'une destruction.
- Non-régression PC sans fenêtre : contrôles généraux 60/60, mobilité 44/44, visée 45/45, recharge 48/48, campagne 52/52, audio 19/19. Vérification graphique PC supplémentaire : 68/68, Vulkan/Forward+ confirmé sur RTX 3090.

La campagne complète n'a pas été terminée dans le navigateur : boss, ascenseur, étage supérieur et extraction restent à valider en Web de bout en bout. Les suites PC couvrent leur logique, mais ne remplacent pas cette preuve navigateur. Firefox, Safari, mobiles, manettes, faible mémoire, chargement sur Internet et GPU modestes n'ont pas été validés. Aucune commande tactile n'est fournie. Glow et SSAO sont absents du rendu Web. Le jeu peut présenter des à-coups lors de la première utilisation de shaders ou de nouveaux effets, et Stream peut ajouter de la latence audio.

Pour inspecter le canvas pendant les essais, `?diagnostics=1` expose `window.helixDiagnostics` en lecture seule (position, état de partie, munitions, ennemis, FPS). Sans ce paramètre, ces mesures ne sont pas publiées dans la page. Les scripts `tools/web-check-*.js` sont des parcours Playwright locaux de vérification, pas des fonctions du jeu.

Référence technique : [export Web Godot](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html). La police DejaVu utilisée pour les symboles provient de la distribution Matplotlib et conserve sa [licence](assets/fonts/LICENSE_DEJAVU.txt), également copiée à côté de l'export.
