#include "res://missions/lunar_escape/material_detail.gdshaderinc"
uniform vec4 tint: source_color=vec4(.75,.79,.76,1);
uniform bool fabric=false;
uniform sampler2D scan_albedo : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D scan_rough : filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D scan_height : filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D fabric_albedo : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D fabric_rough : filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D fabric_height : filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 p;
varying vec3 n;
void vertex(){p=VERTEX*vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));n=NORMAL;}
void fragment(){
	vec3 cloth_uv=p*7.5;
	float textile=dot(scanned_detail(fabric_albedo,cloth_uv,n),vec3(.333333));
	float cloth_height=scanned_detail(fabric_height,cloth_uv,n).r;
	float cloth_rough=scanned_detail(fabric_rough,cloth_uv,n).r;
	float paint=dot(scanned_detail(scan_albedo,p*2.1+vec3(.2,.36,.61),n),vec3(.333333));
	ALBEDO=tint.rgb*(fabric?clamp(.64+textile*.65,.60,1.04):clamp(.76+paint*2.15,.74,1.1));
	METALLIC=fabric?0.0:.12;
	ROUGHNESS=fabric?clamp(cloth_rough,.78,.98):(.38+scanned_detail(scan_rough,p*2.1,n).r*.35);
	float relief=fabric?(cloth_height-.5)*.0008:(scanned_detail(scan_height,p*2.1,n).r-.5)*.001;
	NORMAL=restrained_bump(VERTEX,NORMAL,relief,.13);
}
