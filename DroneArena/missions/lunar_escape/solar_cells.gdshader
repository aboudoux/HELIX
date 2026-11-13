shader_type spatial;
// Silicon cell grid and silver conductors, distinct from painted sheet metal.
uniform sampler2D dust_map : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
void fragment(){
 vec2 cell=fract(UV*6.0);
 vec2 width=max(fwidth(UV*6.0),vec2(.001));
 float gap=1.0-smoothstep(.018,.018+max(width.x,width.y),min(min(cell.x,1.0-cell.x),min(cell.y,1.0-cell.y)));
 float bus=1.0-smoothstep(.012,.012+width.x*3.0,abs(fract(cell.x*3.0)-.5));
 float fingers=1.0-smoothstep(.04,.04+width.y*18.0,abs(fract(cell.y*18.0)-.5));
 float variation=fract(sin(dot(floor(UV*6.0),vec2(12.98,78.23)))*43758.54);
 ALBEDO=mix(vec3(.012,.025,.047)*(0.85+variation*.25),vec3(.29,.33,.36),max(bus*.65,fingers*.23));
 ALBEDO=mix(ALBEDO,vec3(.005),gap);
 float dust=clamp((texture(dust_map,UV*1.7).r-.10)*1.15,0.0,.34);
 ALBEDO=mix(ALBEDO,vec3(.19,.18,.16),dust*.32);
 METALLIC=.35;ROUGHNESS=.19+dust*.38;CLEARCOAT=.65;CLEARCOAT_ROUGHNESS=.11+dust*.24;
}
