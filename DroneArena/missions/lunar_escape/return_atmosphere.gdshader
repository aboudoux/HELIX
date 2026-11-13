shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform float strength = 1.0;
void fragment() {
	float limb = pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),4.5);
	ALBEDO = vec3(0.16,0.43,0.85);
	ALPHA = limb*0.52*strength;
}
