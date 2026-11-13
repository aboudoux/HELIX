# HELIX

Jeu de tir à la première personne réalisé avec Godot. Le projet jouable est dans [`DroneArena`](DroneArena) ; les scènes et modèles Blender d'origine sont dans [`art`](art).

## Ouvrir le projet

1. Installer Git LFS, puis cloner ce dépôt avec Git. Vérifier que les fichiers `.blend` et `.glb` ont bien été téléchargés, et non seulement leurs pointeurs LFS (`git lfs pull` si nécessaire).
2. Installer Godot **4.7.2** et ouvrir `DroneArena/project.godot`.
3. Installer Blender **4.5.14** pour modifier les modèles `.blend`.

Les lanceurs Windows `.cmd` et le script d'export Web utilisent des versions portables de Godot et Blender placées dans `.tools/godot` et `.tools/blender`. Ce dossier local n'est pas inclus dans le dépôt. Le projet Godot peut aussi être ouvert directement dans une installation classique de Godot.

**Jouer DroneArena.cmd** ou **F5** dans Godot ouvre **Le silence de Karen**, la campagne lunaire de survie. Retrouvez les survivants et le journal de bord avant de repartir vers la Terre. Le jeu démarre à la première personne et le briefing dispose d’une voix française intégrée.

Le guide du jeu est dans [`DroneArena/LISEZ-MOI.md`](DroneArena/LISEZ-MOI.md). L'export navigateur se reconstruit avec [`tools/export-web.ps1`](tools/export-web.ps1) après installation des modèles d'export Godot correspondants ; le dossier `exports/` est généré localement.

## Contribuer

Voir [`CONTRIBUTING.md`](CONTRIBUTING.md) pour ajouter des assets et proposer des changements.
