# Matières de la campagne

Deux images de matière créées avec l'outil intégré de génération d'images (pas la CLI), le 13 novembre 2026, puis intégrées dans les shaders Godot :

- `coated_alloy.png` : peinture satinée aéronautique, réutilisée et teintée pour les panneaux, portes, équipements, armures, armes et véhicules.
- `regolith_albedo.png` : poussière et fragments minéraux du terrain lunaire.

L'éclairage, les reflets, la rugosité, le tissu et les microreliefs sont calculés dans Godot. Ces images ne remplacent pas les géométries et ne constituent pas des scans photogrammétriques. L'échantillonnage triplanaire et les répétitions réfléchies limitent les étirements et les raccords visibles.

## Prompts utilisés

### Sol lunaire

Use case: photorealistic-natural. Asset type: seamless tileable PBR albedo texture for the regolith of a lunar exploration videogame, a single material image, NOT a scene. 2048x2048 square top-down orthographic texture of a two metre square patch of dry lunar regolith: fine angular grey silicate dust and tiny irregular charcoal-grey mineral fragments, occasional small shallow irregular depressions, fine powder partly covering embedded angular pebbles, subtle natural mottling. Neutral grey desaturated palette, moderate contrast, uniform diffuse shadow-free illumination, no directional baked light, no horizon, no footprints, no objects, no lettering, no craters larger than 20 cm, no vignette. Seamlessly tileable opposite edges. Authentic fine geological detail; designed to repeat across large ground surfaces.

### Alliage peint

Use case: photorealistic-natural. Asset type: one seamless tileable material texture, neutral albedo for a high quality sci-fi videogame. Square 2048x2048, orthographic flat texture covering exactly 1 metre of satin powder-coated light neutral grey aerospace aluminium. Refined fine paint microtexture, faint superficial scuffs, a few hairline scratches, sparse tiny flecks of exposed aluminium, very restrained accumulated dust. Predominantly clean manufactured surface with authentic subtle wear, NOT grunge, NOT rust, NOT camouflage. Uniform diffuse illumination with no highlights or shadows baked into the image. No seams, no panel edges, no screws, no text, no symbols, no objects, no perspective, no vignette. Seamlessly tileable all edges. Natural detail and delicate contrast suitable for tinting ivory, grey, graphite and muted green in a physically based shader.
