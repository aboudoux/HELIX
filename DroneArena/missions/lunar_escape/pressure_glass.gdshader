shader_type spatial;
render_mode cull_disabled,depth_prepass_alpha;
#include "res://missions/lunar_escape/material_detail.gdshaderinc"
uniform sampler2D imperfections : filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 tint : source_color=vec4(.66,.83,.86,1.0);
varying vec3 p;
varying vec3 n;
void vertex(){p=VERTEX*vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));n=NORMAL;}
void fragment(){
 float fresnel=pow(1.0-clamp(abs(dot(normalize(NORMAL),normalize(VIEW))),0.0,1.0),5.0);
 float smudge=smoothstep(.42,.76,scanned_detail(imperfections,p*1.15,n).r);
 ALBEDO=tint.rgb;
 METALLIC=0.0;
 SPECULAR=.5;
 ROUGHNESS=.035+smudge*.13;
 ALPHA=.045+fresnel*.46+smudge*.018;
 NORMAL=restrained_bump(VERTEX,NORMAL,smudge*.000040,.019);
}
