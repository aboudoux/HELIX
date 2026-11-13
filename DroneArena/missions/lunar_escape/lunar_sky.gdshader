shader_type sky;
render_mode disable_fog;

uniform sampler2D earth_map : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 earth_direction = vec3(0.24, 0.58, -0.78);
// Angular radius: a distant planet, independent of the player's position.
uniform float earth_radius = 0.0166;
uniform vec3 sunlight = vec3(-0.562, 0.407, 0.720);

float star_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void sky() {
	vec3 ray = normalize(EYEDIR);
	COLOR = vec3(0.0003, 0.0005, 0.0012);
	// Faint stars are also infinitely distant, never meshes over the terrain.
	vec2 grid = SKY_COORDS * vec2(900.0, 450.0);
	float seed = star_hash(floor(grid));
	float star = (1.0 - smoothstep(0.04, 0.22, length(fract(grid) - 0.5))) * step(0.9985, seed);
	COLOR += vec3(star * 0.22);
	vec3 forward = normalize(earth_direction);
	vec3 right = normalize(cross(forward, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(right, forward);
	float facing = dot(ray, forward);
	if (facing > 0.99) {
		vec2 disc = vec2(dot(ray, right), dot(ray, up)) / (facing * tan(earth_radius));
		float radius2 = dot(disc, disc);
		if (radius2 < 1.0) {
			vec3 normal = vec3(disc, sqrt(max(0.0, 1.0 - radius2)));
			// Longitude offset presents Africa/Atlantic, without baking sunlight into the map.
			vec2 uv = vec2(atan(normal.z, normal.x) / TAU + 0.56, acos(normal.y) / PI);
			vec3 albedo = texture(earth_map, uv).rgb;
			vec3 world_normal = right * normal.x + up * normal.y - forward * normal.z;
			float day = max(0.0, dot(world_normal, normalize(sunlight)));
			vec3 planet = albedo * (0.008 + day * 1.4);
			float rim = pow(1.0 - normal.z, 4.0) * smoothstep(-0.1, 0.25, dot(world_normal, normalize(sunlight)));
			planet += vec3(0.05, 0.19, 0.40) * rim * 0.55;
			COLOR = mix(COLOR, planet, 1.0 - smoothstep(0.988, 1.0, radius2));
		}
	}
}
