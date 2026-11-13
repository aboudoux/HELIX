shader_type spatial;
#include "res://missions/lunar_escape/material_detail.gdshaderinc"
uniform vec4 tint : source_color = vec4(0.18,0.21,0.23,1.0);
uniform bool leather = false;
uniform bool use_eva_photo = false;
uniform sampler2D eva_photo : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform vec2 photo_origin;
uniform vec2 photo_across;
uniform vec2 photo_down;
uniform bool sleeve = false;
uniform sampler2D fabric_albedo : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D fabric_rough : filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D fabric_height : filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 p;
varying vec3 n;
void vertex(){p=VERTEX*vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));n=NORMAL;}

vec3 sample_cloth_patch(vec2 point) {
	// Sample within the textile, away from the photograph's background and palm.
	vec2 tile = 1.0-mirror_tile(point);
	vec2 uv = sleeve ? vec2(.10,.23)+tile*vec2(.37,.51) : vec2(.18,.11)+tile*vec2(.33,.21);
	return texture(eva_photo,(photo_origin+uv.x*photo_across+uv.y*photo_down)/vec2(1004.0,1510.0)).rgb;
}

void fragment(){
	vec3 uvw=p*(leather?8.0:9.5);
	float tex=dot(scanned_detail(fabric_albedo,uvw,n),vec3(.333333));
	float height=scanned_detail(fabric_height,uvw,n).r;
	ALBEDO=tint.rgb*(leather?(.70+tex*.43):clamp(.63+tex*.65,.60,1.02));
	if (use_eva_photo) {
		vec3 weight = pow(abs(normalize(n)),vec3(4.0));
		weight /= dot(weight,vec3(1.0));
		vec3 patch = sample_cloth_patch(uvw.zy)*weight.x;
		patch += sample_cloth_patch(uvw.xz)*weight.y;
		patch += sample_cloth_patch(uvw.xy)*weight.z;
		ALBEDO = patch;
		height = mix(height,dot(patch,vec3(.2126,.7152,.0722)),.25);
	}
	ROUGHNESS=clamp(scanned_detail(fabric_rough,uvw,n).r,leather?.65:.8,.98);
	METALLIC=0.0;
	SPECULAR=0.18;
	NORMAL=restrained_bump(VERTEX,NORMAL,(height-.5)*(use_eva_photo?.0003:.00065),.12);
}
