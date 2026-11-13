float material_hash(vec3 p){p=fract(p*vec3(.1031,.11369,.13787));p+=dot(p,p.yzx+19.19);return fract((p.x+p.y)*p.z);}
float material_noise(vec3 p){
	vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(mix(material_hash(i),material_hash(i+vec3(1,0,0)),f.x),mix(material_hash(i+vec3(0,1,0)),material_hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(material_hash(i+vec3(0,0,1)),material_hash(i+vec3(1,0,1)),f.x),mix(material_hash(i+vec3(0,1,1)),material_hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
vec3 restrained_bump(vec3 position,vec3 normal,float height,float limit){
	vec3 dx=dFdx(position),dy=dFdy(position);
	vec3 sx=cross(dy,normal),sy=cross(normal,dx);float determinant=dot(dx,sx);
	if(abs(determinant)<0.00000001){return normal;}
	vec3 gradient=(dFdx(height)*sx+dFdy(height)*sy)/determinant;
	gradient*=min(1.0,limit/max(length(gradient),0.00001));
	return normalize(normal-gradient);
}
vec2 mirror_tile(vec2 uv){return abs(fract(uv*0.5)*2.0-1.0);}
vec3 scanned_detail(sampler2D map,vec3 p,vec3 n){
	vec3 w=pow(abs(normalize(n)),vec3(7.0));w/=max(dot(w,vec3(1.0)),.0001);
	return texture(map,p.yz).rgb*w.x+texture(map,p.xz).rgb*w.y+texture(map,p.xy).rgb*w.z;
}
vec3 mapped_detail(sampler2D map,vec3 p,vec3 n){
	vec3 w=pow(abs(n),vec3(5.0));w/=max(w.x+w.y+w.z,.0001);
	return texture(map,mirror_tile(p.yz)).rgb*w.x+texture(map,mirror_tile(p.xz)).rgb*w.y+texture(map,mirror_tile(p.xy)).rgb*w.z;
}
