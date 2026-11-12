shader_type spatial;
// Habillage des tôles, en mètres : joints, nervures et petites diodes.
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
    vec2 p = local_position.xz;
    vec2 cell = abs(fract((p + vec2(0.0, 0.1)) / vec2(3.0, 4.0)) - 0.5);
    float seam = max(step(0.489, cell.x), step(0.490, cell.y));
    float inset = step(0.40, cell.x) * step(cell.x, 0.44);
    float grille = step(0.18, cell.x) * step(cell.x, 0.34) * step(0.31, cell.y) * step(cell.y, 0.40);
    float fin = step(0.60, fract(p.y * 14.0));
    ALBEDO = mix(vec3(0.13, 0.165, 0.20), vec3(0.017, 0.025, 0.036), seam);
    ALBEDO *= 1.0 - inset * 0.30 - grille * fin * 0.60;
    METALLIC = 0.64;
    ROUGHNESS = 0.58;
    float diode = step(0.445, cell.x) * step(cell.x, 0.46) * step(0.25, cell.y) * step(cell.y, 0.34);
    EMISSION = vec3(0.04, 0.9, 1.0) * diode * 1.7;
}
