# Refonte des matières — références recherchées le 13 novembre 2026

Ce document décrit la première passe. Voir [Scans photographiques de la campagne lunaire](../scanned/README.md) pour les cartes et usages de la passe suivante.

Les recherches web servent à observer les matériaux réels. Les photographies de NASA, Boston Dynamics et Heckler & Koch ne sont pas redistribuées dans le jeu. Les cartes de matière ajoutées proviennent des bibliothèques CC0 ci-dessous. Aucun achat, Blender ou nouvel outil installé.

## Références visuelles et applications

| Famille | Référence consultée | Application dans HELIX |
| --- | --- | --- |
| Habitat, portes, mobilier | [NASA — laboratoire Destiny](https://www.nasa.gov/international-space-station/destiny-laboratory-module/) | Panneaux peints satinés, joints sombres, équipements distincts. Les couleurs HELIX sont conservées. |
| Sol lunaire | [NASA — empreinte Apollo 11](https://science.nasa.gov/resource/apollo-11-bootprint/), [galerie de la surface lunaire](https://science.nasa.gov/moon/image-galleries/views-from-the-lunar-surface/) | Grain minéral gris et mat, relief fin, variation à deux échelles. Dense Sand est une approximation terrestre désaturée, pas un scan lunaire. Les roches gardent un grain plus grossier. |
| Véhicules | [NASA — Lunar Terrain Vehicle](https://www.nasa.gov/moonbase/lunar-terrain-vehicle/) | Peinture, métal exposé, roues/chenilles sombres et poussière différenciés. La moto et le char restent des véhicules fictifs. |
| Robots | [Boston Dynamics — anatomie de Spot](https://support.bostondynamics.com/s/article/about-the-spot-robot) | Séparation entre capots peints, mécanismes métalliques et éléments souples ; référence de matériaux, sans copier le robot. |
| Armes | [Heckler & Koch — HK416](https://www.heckler-koch.com/en/Products/Military%20and%20Law%20Enforcement/Assault%20rifles/HK416) | Métal usiné, corps sombre, polymère et grip mat distincts. Pas de modification du fonctionnement. |
| Combinaisons | [NASA — galerie des combinaisons](https://www.nasa.gov/gallery/spacesuit-gallery/), photo fournie par l'utilisateur | La texture photographique explicitement demandée reste sur les survivants ; les matériaux de tissu et de verre restent séparés. |
| Fusée et panache | [NASA — guide visuel SLS](https://www.nasa.gov/wp-content/uploads/2022/03/sls-reference-guide-2022-v2-508-0.pdf) | Coque peinte, métal des mécanismes ; turbulence du panache moins périodique et structure lumineuse concentrée près de la tuyère. Adaptation artistique à la fusée fictive, pas une simulation du SLS. |

## Cartes intégrées

| Asset | Source / auteur | Usage |
| --- | --- | --- |
| Metal032 | [ambientCG](https://ambientcg.com/view?id=Metal032), Lennart Demes | Métal et microstructure de peinture. Asset PBR **procédural**, pas une photographie. Couleur, rugosité et hauteur en 2K JPG. |
| Metal Plate | [Poly Haven](https://polyhaven.com/a/metal_plate), Rob Tuytel | Sols et marches antidérapants, recolorés en graphite ; le relief provient de la carte de hauteur. |
| Rubber Tiles | [Poly Haven](https://polyhaven.com/a/rubber_tiles), Amal Kumar | Rugosité et grain des pièces en caoutchouc, roues et poignées. |
| Dense Sand | [Poly Haven](https://polyhaven.com/a/dense_sand), Dimitrios Savva | Détail du régolithe gris et substrat brun des bacs hydroponiques, avec traitements distincts. |
| Rusty Metal 04 | [Poly Haven](https://polyhaven.com/a/rusty_metal_04), Amal Kumar | Relief irrégulier et marques des épaves. La couleur rouille n'est pas appliquée : le shader produit du métal brûlé et de la suie. |
| Denim Fabric 05 | [Poly Haven](https://polyhaven.com/a/denim_fabric_05), colormass / Rico Cilliers | Tissu des sièges, couvertures, matelas et oreillers, recoloré. Asset déjà présent dans `../photographic/`. |

`gravelly_sand_*` est une piste téléchargée puis écartée du rendu lunaire après inspection (brindilles visibles). Elle n'est pas utilisée par les shaders. Les anciens fichiers de texture sont conservés lorsqu'ils sont encore employés par un autre système.

Licences : [Poly Haven CC0](https://polyhaven.com/license), [ambientCG CC0](https://docs.ambientcg.com/license/). Les fichiers peuvent être redistribués avec le jeu. `sources.json` contient les URL et les MD5 des cartes Poly Haven, vérifiés au téléchargement. `ambient_sources.json` conserve les SHA-256 des fichiers extraits du paquet ambientCG original.

## Intégration et validation

Les cartes couleur sont lues en sRGB ; la hauteur et la rugosité en linéaire. Mipmaps et filtrage anisotrope limitent le scintillement. La projection triplanaire emploie l'échelle des objets. Le relief est un microrelief visuel, sans modification des collisions. Le verre et les cellules photovoltaïques utilisent des shaders spécifiques ; une photo opaque ne serait pas adaptée à leur transparence ou à leur taille.

`tests/verify_researched_materials.gd` contrôle les familles de matériaux et la conservation de la combinaison photographique, puis capture les décors et équipements sous Vulkan. `tests/verify_power_tablet.gd` contrôle que les matières émissives et la panne de Karen fonctionnent toujours.
