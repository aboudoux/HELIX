# Contribuer à HELIX

## Ajouter ou modifier un asset

1. Créer une branche Git pour votre modification.
2. Ranger le fichier source Blender dans `art/<élément>/` et le modèle exporté utilisé par Godot dans `DroneArena/assets/models/`. Garder les textures, sons et licences nécessaires avec leurs fichiers source ou dans `DroneArena/assets/`.
3. Ouvrir `DroneArena/project.godot` avec Godot 4.7.2 pour vérifier l'import et la scène concernée. Les guides de `art/` décrivent les exports existants.
4. Commiter les fichiers source et les fichiers exportés utiles au jeu, puis ouvrir une pull request sur GitHub en expliquant ce qui a changé et comment le vérifier.

Les fichiers `.blend` et `.glb` sont suivis avec Git LFS. Installer Git LFS avant de cloner ou de pousser. Si plusieurs personnes doivent modifier le même fichier Blender, se coordonner avant de travailler : Git ne peut pas fusionner automatiquement ces fichiers binaires.

Ne pas commiter `.tools/`, les caches Godot, les sauvegardes Blender, `output/` ou `exports/`. Les chemins absolus `C:\code\jeux` présents dans certains guides correspondent à la machine de création ; les adapter à votre propre clone.
