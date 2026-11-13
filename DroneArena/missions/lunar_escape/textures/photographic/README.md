# Textures photographiques PBR — Poly Haven

Téléchargées le 13 novembre 2026, en 2K JPG, sans achat ni installation de logiciel. Les fichiers originaux sont conservés. Leur téléchargement est vérifié par MD5 avec les empreintes de l'API Poly Haven. `sources.json` contient les URL et les empreintes de chaque fichier.

Licence commune : [CC0 — Poly Haven](https://polyhaven.com/license), redistribution et utilisation commerciale autorisées.

| Matière | Auteurs | Usage dans HELIX |
| --- | --- | --- |
| [Blue Metal Plate](https://polyhaven.com/a/blue_metal_plate) | Rob Tuytel | Murs, coques, panneaux des drones, armes et plaques de combinaison. L'intensité photographique est recolorée dans le shader pour conserver les teintes HELIX. |
| [Denim Fabric 05](https://polyhaven.com/a/denim_fabric_05) | colormass (photographie), Rico Cilliers (traitement) | Trame textile des combinaisons, manches et gants ; recolorée, à environ 27 cm par répétition. Sert de référence de tissu tissé, pas de simulation d'un textile spatial certifié. |
| [Leather White](https://polyhaven.com/a/leather_white) | Rob Tuytel | Grain des renforts de paume et des manchettes, teinté graphite. |

Chaque matière utilise trois cartes : couleur diffuse (sRGB), rugosité et hauteur (données linéaires). La hauteur produit un microrelief limité, sans déplacer les silhouettes. Projection triplanaire à l'échelle métrique et mipmaps pour limiter les étirements et le scintillement.

Le verre n'utilise pas une photo opaque : il conserve sa transparence et calcule la réflexion de Fresnel, avec une faible variation de rugosité tirée de la carte photographique du métal. Les vitrages possèdent toujours leurs collisions. Les coques opaques sont rendues et projettent des ombres sur leurs deux faces.
