shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
void fragment() {
 float t = UV.y;
 float wave = sin(UV.x * 39.0 + t * 23.0 - TIME * 22.0) * sin(t * 47.0 - TIME * 31.0);
 float edge = pow(max(sin(UV.x * 3.14159), 0.0), 1.4);
 float flame = edge * pow(1.0 - t, 0.7) * smoothstep(0.0, 0.16, t) * (0.7 + wave * 0.3);
 ALBEDO = mix(vec3(0.25, 0.65, 1.0), vec3(1.0, 0.22, 0.035), t);
 EMISSION = ALBEDO * (2.4 + (1.0 - t) * 2.0);
 ALPHA = flame;
}
