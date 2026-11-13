shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float heat : hint_range(0.0,1.0) = 0.0;
varying vec3 p;
void vertex() { p=VERTEX; }
void fragment() {
	float side=abs(dot(normalize(NORMAL),normalize(VIEW)));
	float flow=0.88+0.12*sin(p.y*11.0-TIME*21.0+sin(UV.x*43.0)*3.0);
	float fade=pow(1.0-smoothstep(-2.4,2.4,p.y),1.6);
	vec3 hot=mix(vec3(1.0,0.14,0.025),vec3(1.0,0.77,0.35),clamp(-p.y+0.5,0.0,1.0));
	ALBEDO=hot*1.35;
	ALPHA=heat*fade*flow*smoothstep(0.0,0.5,side)*0.44;
}
