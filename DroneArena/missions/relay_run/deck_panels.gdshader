shader_type spatial;
varying vec3 world_point;
void vertex() {
	world_point = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec2 p = world_point.xz;
	vec2 tile = mod(p,vec2(4.0,6.0));
	float edge = min(min(tile.x,4.0-tile.x),min(tile.y,6.0-tile.y));
	float joint = 1.0-smoothstep(0.02,0.065,edge);
	float brushed = sin(p.x*190.0+p.y*2.0)*0.006;
	vec3 paint = vec3(0.105,0.15,0.19)+brushed;
	paint *= mix(1.0,0.25,joint);
	vec2 screw = min(tile,vec2(4.0,6.0)-tile)-vec2(0.18);
	float bolt = 1.0-smoothstep(0.025,0.045,length(screw));
	paint = mix(paint,vec3(0.32,0.38,0.4),bolt);
	float rib = step(0.91,fract((p.x+p.y)*7.0));
	float lane = 1.0-smoothstep(2.5,3.0,abs(p.x));
	paint += vec3(0.012)*rib*lane;
	ALBEDO = paint;
	METALLIC = 0.65;
	ROUGHNESS = 0.58;
}
