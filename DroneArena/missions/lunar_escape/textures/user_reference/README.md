# Textures adaptées des références de l’utilisateur

Créées avec l’outil intégré image_gen, à partir des deux images fournies le 13 novembre 2026. Il s’agit de nouvelles textures inspirées des références, pas des photographies originales ni de textures numérisées officielles.

- `lunar_rock_albedo.png` : régolithe gris, poussière, petits reliefs minéraux. Utilisé par le terrain et les surfaces rocheuses de la campagne.
- `eva_white_fabric.png` : tissu blanc cassé d’une combinaison spatiale. Utilisé par les personnages, survivants, manches et gants. Le relief est une approximation légère dérivée de la luminance, et non une carte de hauteur mesurée.

Images originales conservées à leur emplacement d’origine. Répétition avec filtrage anisotrope et mipmaps, microrelief limité ; pas de déplacement des collisions du terrain.

## Prompts exacts

### Sol

Use case: photorealistic-natural. Asset type: square seamless repeating ground albedo texture for Godot lunar game. Input image is MATERIAL REFERENCE ONLY. Create an orthographic directly overhead, evenly lit and de-shadowed texture derived from the reference's charcoal grey rocky lunar regolith, fine dust, tiny sharp stones, rough eroded mineral ridges and shallow irregular depressions. Physically plausible grey moon soil, dense photographic mineral microdetail. This tile represents approximately 3 metres of surface. No perspective, no horizon, no black holes or strong directional shadows, no giant boulders, no plants, roots, text, borders, panels or watermark. All four edges should tile seamlessly. Fill the entire square with material. Output the albedo colour texture only.

### Combinaison

Use case: photorealistic-natural. Asset type: square seamless repeating white astronaut suit fabric albedo texture for a 3D game. Input image is MATERIAL REFERENCE ONLY: use the off-white woven protective fabric of the astronaut's Apollo-style pressure suit, NOT the person, silhouette, moon, visor or equipment. Render a directly overhead orthographic macro material swatch approximately 35 cm across. Ivory white multilayer technical fabric, visible fine textile weave, soft shallow irregular wrinkles and tiny grey lunar dust wear in creases. Clean overall white, subtle grey detail, neutral diffuse illumination without baked cast shadows. Continuous edge-to-edge texture, seamless matching edges. No body parts, no human, no objects, no logos, no flags, no letters, no stitched rectangular panels, no horizon, no border, no watermark. Output only one square fabric albedo texture.

