shader_type spatial;
render_mode cull_disabled;
#include "res://missions/lunar_escape/material_detail.gdshaderinc"
uniform float impact=0.0;
uniform int material_kind = 2;
uniform float photo_scale = 5.0;
uniform sampler2D scan_albedo : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D scan_rough : filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D scan_height : filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 p;
varying vec3 n;
void vertex(){p=VERTEX;n=NORMAL;}
void fragment(){
 float detail=dot(scanned_detail(scan_albedo,p*photo_scale,n),vec3(.333333));
 float wear=smoothstep(.63,.84,material_noise(p*vec3(72,8,46)));
 ALBEDO=mix(vec3(.065,.109,.125)*(.74+detail*.72),vec3(.29,.31,.32),wear*.10);
 METALLIC=material_kind==1?.62:.06;
 ROUGHNESS=.53+scanned_detail(scan_rough,p*photo_scale,n).r*.28;
 NORMAL=restrained_bump(VERTEX,NORMAL,(scanned_detail(scan_height,p*photo_scale,n).r-.5)*.0011,.13);
 EMISSION=vec3(.12,.7,.9)*impact*(.12+pow(1.0-abs(dot(NORMAL,VIEW)),3.0));
}
