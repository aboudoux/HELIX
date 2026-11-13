# Texture photographique demandée

`eva_user_photo.png` est une copie non modifiée de la photographie 1024 × 1536 fournie par l'utilisateur le 13 novembre 2026 (`codex-clipboard-7dd02952-a36b-41bd-8f7f-1222f57cfac4.png`). Aucun remplacement par une image générée.

`eva_photo_finish.gd` associe des régions précises de cette photographie au plastron, au torse, aux manches, aux pantalons, aux gants et aux bottes. Les coordonnées de référence sont exprimées dans un repère 1004 × 1510 puis normalisées par le shader. Les côtés et le dos utilisent un échantillon de tissu de la même photo, car ces faces ne sont pas montrées dans l'image fournie. Le casque conserve son matériau de verre dynamique.

Le modèle reste un personnage 3D articulé : les membres ont un maillage à plis irréguliers et les textiles suivent les articulations. La photographie contient un éclairage déjà présent ; son utilisation ne constitue pas un scan PBR ni une reconstruction exacte du modèle 3D de référence. La luminance sert de microrelief léger, sans déplacement des collisions.

Les fichiers `eva_reference_fabric.png` et `EVA_REFERENCE.md` documentent l'ancienne approximation. Les parties visibles des survivants utilisent désormais directement `eva_user_photo.png` via `eva_photo.gdshader`.
