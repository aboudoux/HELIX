#include "res://missions/lunar_escape/material_detail.gdshaderinc"
uniform vec4 base_color : source_color = vec4(.45,.49,.52,1);
uniform float metalness = .35;
uniform float surface_roughness = .55;
uniform float grain_strength = .22;
uniform float regolith = 0.0;
uniform int architecture_detail = 0;
uniform float photo_scale = 0.4;
uniform int material_kind = 0;
uniform sampler2D scan_albedo : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D scan_rough : filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D scan_height : filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D fine_albedo : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D fine_height : filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D coarse_albedo : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D coarse_height : filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 p;
varying vec3 object_normal;
void vertex(){p=VERTEX*vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));object_normal=NORMAL;}
void fragment(){
 float fade=1.0-smoothstep(.012,.06,length(fwidth(p)));
 float noise=material_noise(p*5.0);
 float brushing=material_noise(p*vec3(240.0,5.0,190.0));
 vec3 photo_p=p*photo_scale+vec3(.19,.36,.61);
 vec3 scan=scanned_detail(scan_albedo,photo_p,object_normal);
 float photograph=dot(scan,vec3(.2126,.7152,.0722));
 float scanned_roughness=scanned_detail(scan_rough,photo_p,object_normal).r;
 float scanned_height=scanned_detail(scan_height,photo_p,object_normal).r;
 ALBEDO=base_color.rgb*(.94+clamp((photograph-.25)*.65,-.15,.19));
 METALLIC=metalness;
 ROUGHNESS=clamp(surface_roughness+(scanned_roughness-.5)*.38+(brushing-.5)*.04*fade,.25,.98);
 float height=(scanned_height-.5)*mix(.00045,.0018,clamp(grain_strength,0.0,1.0));
 SPECULAR=.45;
 if(material_kind==0){
  float marks=clamp(photograph/.054,.34,1.85);
  float bare=smoothstep(.095,.185,photograph);
  ALBEDO=mix(base_color.rgb*(.58+marks*.39),vec3(.24,.26,.27),bare*.26);
  METALLIC=.04;ROUGHNESS=clamp(surface_roughness+(scanned_roughness-.5)*.34+(1.0-marks)*.06,.35,.86);
 }
 if(material_kind==1){METALLIC=max(.70,metalness);ROUGHNESS=clamp(surface_roughness*.48+scanned_roughness*.42,.24,.64);height*=.68;}
 if(material_kind==2){METALLIC=0.0;ROUGHNESS=.64+(scanned_roughness-.5)*.22;height=(scanned_height-.5)*.00045;}
 if(material_kind==3){METALLIC=0.0;ROUGHNESS=.78+scanned_roughness*.17;ALBEDO=base_color.rgb*(.76+photograph*.6);height=(scanned_height-.5)*.0011;}
 if(material_kind==4){METALLIC=.08;ROUGHNESS=clamp(scanned_roughness,.50,.88);ALBEDO=base_color.rgb*(.58+photograph*2.8);height=(scanned_height-.5)*.0032;}
 if(material_kind==5){METALLIC=0.0;ROUGHNESS=clamp(scanned_roughness,.77,.97);ALBEDO=base_color.rgb*(.68+photograph*.62);height=(scanned_height-.5)*.0016;}
 if(material_kind==6){METALLIC=0.0;ROUGHNESS=.98;ALBEDO=base_color.rgb*(.75+photograph*.8);height=(scanned_height-.5)*.003;}
 if(material_kind==8){
  float midrib=1.0-smoothstep(.01,.035,abs(UV.x-.5));
  float veins=pow(max(0.0,cos((UV.y+abs(UV.x-.5)*.46+noise*.04)*54.0)),21.0)*fade;
  float mottling=material_noise(p*48.0);
  vec3 green=mix(base_color.rgb*.72,base_color.rgb*1.16,mottling);
  ALBEDO=mix(green,vec3(.24,.37,.11),midrib*.20+veins*.10);
  METALLIC=0.0;ROUGHNESS=.47+mottling*.24;SSS_STRENGTH=.23;height=(midrib+veins*.4)*.00045;
 }
 if(architecture_detail==1){METALLIC=.02;ROUGHNESS=clamp(ROUGHNESS,.46,.64);}
 if(architecture_detail==2){ROUGHNESS=max(.42,ROUGHNESS);}
 if(architecture_detail==5){
  // Keep the white photograph and pick out its fine grain against the softer plaster scan.
  vec3 white_photo=mapped_detail(scan_albedo,photo_p,object_normal);
  float grain=dot(white_photo,vec3(.2126,.7152,.0722));
  float plaster=clamp((scanned_height-.72)*.48,-.09,.075);
  float grain_tone=clamp(.91+(grain-.83)*.85,.72,1.06);
  float wear=smoothstep(.52,.78,material_noise(p*vec3(2.5,.75,2.5)));
  float foot_scuffs=(1.0-smoothstep(-1.8,-.85,p.y))*wear;
  ALBEDO=white_photo*(grain_tone+plaster-foot_scuffs*.12);
  METALLIC=0.0;ROUGHNESS=clamp(.69+scanned_roughness*.24+foot_scuffs*.12,.72,.97);SPECULAR=.32;
  height=((scanned_height-.5)*.0029+(grain-.83)*.00082)*fade;
 }
 if(architecture_detail==6){
  // Recolour the photographed steel, retaining the scuffs from the scan.
  float scratches=smoothstep(.074,.17,photograph);
  float mottling=material_noise(p*vec3(12.0,6.0,10.0));
  ALBEDO=base_color.rgb*(.78+clamp(photograph/.065,.35,1.45)*.22);
  float wear_strength=mix(.09,.26,smoothstep(.04,.22,dot(base_color.rgb,vec3(.2126,.7152,.0722))));
  ALBEDO=mix(ALBEDO,vec3(.36,.38,.39),scratches*wear_strength*(.50+.50*mottling));
  METALLIC=.05+scratches*.17;
  ROUGHNESS=clamp(.47+(scanned_roughness-.5)*.53+scratches*.10,.38,.76);
  height=(scanned_height-.5)*.00165;
 }
 if(architecture_detail==7){
  // Worktops and shelf liners use the fine grain of the grip scan.
  float stipple=clamp((scanned_height-.5)*1.15,-.22,.22);
  ALBEDO=base_color.rgb*(.82+photograph*.34+stipple*.45);
  METALLIC=0.0;ROUGHNESS=.58+scanned_roughness*.22;SPECULAR=.30;
  height=(scanned_height-.5)*.00125;
 }
 if(architecture_detail==8 || architecture_detail==9){
  float weave=clamp((photograph-.13)*2.1,-.25,.30);
  float wrinkles=material_noise(p*vec3(12.0,8.0,21.0));
  ALBEDO=base_color.rgb*(.88+weave+(wrinkles-.5)*.22);
  ROUGHNESS=clamp(.75+scanned_roughness*.23,.81,.98);
  METALLIC=0.0;SPECULAR=.27;RIM=.13;RIM_TINT=.65;
  height=(scanned_height-.5)*.0018+(wrinkles-.5)*.0015;
  if(architecture_detail==9){
   vec2 hem_distance=abs(abs(UV-.5)-vec2(.456));
   float hem=1.0-smoothstep(.0015,.0045,min(hem_distance.x,hem_distance.y));
   float stitches=smoothstep(.05,.55,cos((hem_distance.x<hem_distance.y?UV.y:UV.x)*760.0));
   float folds=sin(p.z*23.0+wrinkles*.9);
   ALBEDO*=1.0+(folds*.032-hem*(.20-stitches*.13))*fade;
   height+=(folds*.0012+hem*.001)*fade;
  }
 }
 if(architecture_detail==4 || architecture_detail==5){
  vec2 edge=min(UV,vec2(1.0)-UV);
  float border=1.0-smoothstep(.006,.012,min(edge.x,edge.y));
  float screw=1.0-smoothstep(.006,.010,length(edge-vec2(.047)));
  ALBEDO*=1.0-border*.12-screw*.42;
  height-=screw*.0006;
 }
 if(regolith>.5){
  METALLIC=0.0;
  ROUGHNESS=clamp(scanned_roughness,.82,.99);
  if(material_kind==7){
   ALBEDO=vec3(.095+photograph*.64)*vec3(1.01,1.0,.97);
   height=(scanned_height-.5)*.012*fade;
  }else{
   vec3 wide=p*.145+vec3(.17,.76,.34);
   vec3 near=p*1.45+vec3(.42,.13,.62);
   float near_fade=1.0-smoothstep(.011,.095,length(fwidth(p)));
   float dust=dot(scanned_detail(fine_albedo,near,object_normal),vec3(.2126,.7152,.0722));
   float coarse=dot(scanned_detail(coarse_albedo,wide,object_normal),vec3(.2126,.7152,.0722));
   float broad_height=scanned_detail(coarse_height,wide,object_normal).r;
   float deposit=material_noise(p*.074)*.68+material_noise(p*.31)*.32;
   float shaded_grains=clamp((scanned_height-.46)*.15,-.065,.065);
   float tint=clamp(.58+base_color.r*2.35,.65,1.06);
   float lunar_gray=clamp(.055+photograph*.84+(coarse-.18)*.72+(dust-.21)*.35*near_fade+shaded_grains,.06,.39);
   ALBEDO=vec3(lunar_gray)*mix(.67,1.25,deposit)*tint;
   height=(broad_height-.5)*.055+((scanned_height-.5)*.019+(scanned_detail(fine_height,near,object_normal).r-.5)*.005*near_fade)*fade;
  }
 }
 NORMAL=restrained_bump(VERTEX,NORMAL,height,regolith>.5?.24:(architecture_detail>=5?.21:.12));
}
