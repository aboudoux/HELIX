shader_type spatial;
#include "res://missions/lunar_escape/material_detail.gdshaderinc"

uniform sampler2D photograph : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D weave_height : filter_linear_mipmap_anisotropic, repeat_enable;
// Coordinates refer to the supplied full-body photo, not an AI approximation.
uniform vec2 photo_origin = vec2(360.0,820.0);
uniform vec2 photo_across = vec2(60.0,0.0);
uniform vec2 photo_down = vec2(0.0,75.0);
uniform vec3 part_size = vec3(1.0);
uniform vec3 part_center = vec3(0.0);
uniform bool fabric = true;
uniform bool patch_on_front = true;
uniform float joint_flex = 0.0;
uniform float soil_amount = 0.0;
varying vec3 local_point;
varying vec3 local_normal;

void vertex() {
	if(fabric){
		float end_zone=smoothstep(.20,.48,abs((VERTEX.y-part_center.y)/max(part_size.y,.01)));
		float ripple=sin(VERTEX.y*110.0+VERTEX.x*24.0)*min(joint_flex,1.5)*.0018*end_zone;
		VERTEX+=vec3(NORMAL.x,0.0,NORMAL.z)*ripple;
	}
	local_point=VERTEX-part_center;
	local_normal=NORMAL;
}

void fragment() {
	vec2 front=clamp(vec2(.5-local_point.x/part_size.x,.5-local_point.y/part_size.y),vec2(0.0),vec2(1.0));
	vec2 uv=(photo_origin+front.x*photo_across+front.y*photo_down)/vec2(1004.0,1510.0);
	vec3 detail=texture(photograph,uv).rgb;
	// Unseen sides use real cloth sampled from the same photo, without stamping
	// the front control panel onto the back of the astronaut.
	vec3 weights=pow(abs(local_normal),vec3(4.0));
	weights/=max(dot(weights,vec3(1.0)),.0001);
	vec2 crop=vec2(360.0,820.0)/vec2(1004.0,1510.0);
	vec2 span=vec2(80.0,75.0)/vec2(1004.0,1510.0);
	vec3 cloth=texture(photograph,crop+mirror_tile(local_point.yz*5.0)*span).rgb*weights.x;
	cloth+=texture(photograph,crop+mirror_tile(local_point.xz*5.0)*span).rgb*weights.y;
	cloth+=texture(photograph,crop+mirror_tile(local_point.xy*5.0)*span).rgb*weights.z;
	float facing=patch_on_front?smoothstep(.12,.65,-local_normal.z):0.0;
	vec3 color=mix(cloth,detail,facing);
	float dust=soil_amount*smoothstep(.2,.8,material_noise(local_point*27.0));
	ALBEDO=mix(color,vec3(.32,.31,.29),dust);
	METALLIC=fabric?0.0:.14;
	ROUGHNESS=fabric?clamp(.84+.12*dot(color,vec3(.333)),.84,.96):.53;
	RIM=fabric?.08:0.0;
	RIM_TINT=.7;
	float height=dot(color,vec3(.2126,.7152,.0722));
	float weave=scanned_detail(weave_height,local_point*8.0,local_normal).r;
	NORMAL=restrained_bump(VERTEX,NORMAL,height*(fabric?.0018:.0008)+(fabric?(weave-.5)*.00065:0.0),.21);
}
