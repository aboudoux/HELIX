shader_type spatial;
render_mode cull_disabled;
varying float height;
void vertex() {
	height=VERTEX.y;
	VERTEX.xz *= 1.0+sin(UV.x*150.79645)*0.012;
}
void fragment() {
	if(height<0.001){discard;}
	float panel=fract(UV.x*12.0);
	vec3 fabric=mix(vec3(0.80,0.82,0.79),vec3(0.80,0.25,0.06),step(0.5,panel));
	float seam=smoothstep(0.0,0.018,min(panel,1.0-panel));
	ALBEDO=fabric*mix(0.68,1.0,seam);
	ROUGHNESS=0.96;
	SPECULAR=0.15;
}
