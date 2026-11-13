shader_type spatial;
#include "res://missions/lunar_escape/material_detail.gdshaderinc"
uniform vec4 paint : source_color = vec4(.32,.39,.40,1);
uniform float metal = .5;
uniform float rubber = 0.0;
uniform int material_kind = 0;
uniform sampler2D scan_albedo : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D scan_rough : filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D scan_height : filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D dust_map : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float photo_scale=1.0;
varying vec3 p;
varying vec3 n;
void vertex(){p=VERTEX*vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));n=NORMAL;}
void fragment(){
 float fade=1.0-smoothstep(.01,.08,length(fwidth(p)));
 vec3 sampling=p*photo_scale+vec3(.13,.24,.19);
 float detail=dot(scanned_detail(scan_albedo,sampling,n),vec3(.333333));
 float scanned_rough=scanned_detail(scan_rough,sampling,n).r;
 float scanned_height=scanned_detail(scan_height,sampling,n).r;
 float dust_scan=dot(scanned_detail(dust_map,p*2.5,n),vec3(.333333));
 float dust=clamp(dust_scan*1.8,0.0,.75)*material_noise(p*2.4)*(1.0-smoothstep(-.45,1.1,p.y));
 float contrast=material_kind==0?clamp(detail/.054,.30,1.8):(.58+detail*1.12);
 ALBEDO=paint.rgb*(.57+.46*contrast);
 ALBEDO=mix(ALBEDO,vec3(.23,.25,.26),smoothstep(.095,.18,detail)*(1.0-rubber)*.24);
 ALBEDO=mix(ALBEDO,vec3(.24,.23,.21),dust*(.43+rubber*.24));
 METALLIC=(metal>.7?metal:.04)*(1.0-rubber)*(1.0-dust*.6);
 ROUGHNESS=clamp(mix(metal>.7?.35:.53,.91,rubber)+(scanned_rough-.5)*.35+dust*.25,.24,.98);
 NORMAL=restrained_bump(VERTEX,NORMAL,(scanned_height-.5)*(.001+rubber*.0014)*fade,.15);
}
