shader_type spatial;
render_mode unshaded, cull_back, blend_add, depth_draw_never;
#include "res://missions/lunar_escape/material_detail.gdshaderinc"
uniform bool inner = false;
uniform float plume_length = 10.0;
varying float along;
void vertex() {
	along=clamp(0.5-VERTEX.y/plume_length,0.0,1.0);
	float curl=sin(along*39.0-TIME*24.0+atan(VERTEX.z,VERTEX.x)*4.0);
	VERTEX.xz*=1.0+curl*(0.012+along*0.13);
}
void fragment() {
	float t=along;
	float flow=sin(t*54.0-TIME*29.0+sin(UV.x*31.4159)*2.0);
	float turbulence=material_noise(vec3(cos(UV.x*TAU)*4.0,sin(UV.x*TAU)*4.0,t*22.0-TIME*12.0))*2.0-1.0;
	float diamonds=pow(max(0.0,sin(t*26.0)),6.0)*exp(-t*5.0);
	float end_fade=pow(1.0-t,1.6)*(1.0-smoothstep(0.65,1.0,t));
	float nozzle=smoothstep(0.0,0.04,t);
	vec3 hot=mix(vec3(0.42,0.66,1.0),vec3(1.0,0.43,0.10),smoothstep(0.05,0.8,t));
	if(inner){hot=mix(vec3(0.92,0.97,1.0),vec3(1.0,0.73,0.36),t);}
	float pulse=0.84+flow*0.04+turbulence*(.06+t*.22);
	float soft_edge=smoothstep(0.03,0.78,abs(dot(normalize(NORMAL),normalize(VIEW))));
	ALBEDO=hot*(inner?2.6:1.7)*(1.0+diamonds*0.65);
	ALPHA=end_fade*nozzle*pulse*soft_edge*(inner?0.78:0.4);
}
