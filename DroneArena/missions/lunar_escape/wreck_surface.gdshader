shader_type spatial;
render_mode cull_disabled;
#include "res://missions/lunar_escape/material_detail.gdshaderinc"
uniform vec4 original_paint: source_color = vec4(0.35,0.42,0.43,1.0);
uniform float heat: hint_range(0,1) = 0.0;
uniform float variation = 0.0;
uniform bool soft_part = false;
uniform sampler2D damage_map : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D damage_height : filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 p;
varying vec3 local_normal;
float hash(vec3 v){ return fract(sin(dot(v,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 v){
 vec3 i=floor(v), f=fract(v); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
 mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){
 p=VERTEX+vec3(variation);
 local_normal=NORMAL;
	float dent=smoothstep(0.62,0.88,noise(p*12.0));
 VERTEX-=NORMAL*dent*(soft_part?0.008:0.027);
}
void fragment(){
 float damaged=dot(scanned_detail(damage_map,p*1.35,local_normal),vec3(.333333));
 float damage_relief=scanned_detail(damage_height,p*1.35,local_normal).r;
 float burn=noise(p*5.5)*0.42+noise(p*17.0)*0.14+damaged*.44;
 float soot=smoothstep(0.32,0.69,burn);
 float peeled=smoothstep(0.40,0.66,damage_relief+noise(p*15.0)*.18);
 float pits=1.0-smoothstep(0.20,0.37,damage_relief);
 float fractures=1.0-smoothstep(0.006,0.025,abs(noise(p*9.0)-0.53));
 float hot_spots=smoothstep(0.53,0.76,noise(p*4.0+vec3(12.0)));
 float scratch=pow(max(0.0,sin(p.y*217.0+p.x*33.0)),28.0)*smoothstep(0.65,0.75,noise(p*11.0));
 float detail=1.0-smoothstep(0.006,0.024,length(fwidth(p)));
 vec3 metal=mix(vec3(0.18,0.20,0.21),vec3(0.32,0.33,0.32),noise(p*7.0));
 vec3 paint=mix(original_paint.rgb*0.65,metal,peeled);
 ALBEDO=mix(paint,vec3(0.022,0.026,0.028),soot*0.94);
 ALBEDO=mix(ALBEDO,vec3(0.005),pits*detail*0.8);
 ALBEDO+=vec3(0.17,0.19,0.20)*scratch*detail*(1.0-soot);
 if(soft_part){ ALBEDO=mix(vec3(0.018),vec3(0.065),burn); }
 METALLIC=soft_part?0.04:mix(0.76,0.12,soot);
 ROUGHNESS=clamp(0.48+soot*0.44+pits*0.15,0.4,0.97);
 EMISSION=vec3(1.0,0.16,0.015)*fractures*hot_spots*hot_spots*heat*0.55;
 float relief=(-pits*0.003-peeled*0.001-fractures*0.0015+(damage_relief-.5)*.002)*detail;
 NORMAL=restrained_bump(VERTEX,NORMAL,relief*.42,.20);
}
