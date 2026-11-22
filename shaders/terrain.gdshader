shader_type spatial;
render_mode cull_back, diffuse_burley;
// Sol de plage : COLOR.r = humidité, COLOR.g = masque d'herbe, COLOR.b = masque de pollution.

uniform float restoration : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sand_col : source_color = vec3(0.70, 0.58, 0.42);
uniform vec3 wet_col : source_color = vec3(0.36, 0.29, 0.21);
uniform vec3 pol_col : source_color = vec3(0.20, 0.19, 0.18);
uniform vec3 grass_col : source_color = vec3(0.34, 0.52, 0.20);

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = vnoise(wpos.xz * 0.3) * 0.55 + vnoise(wpos.xz * 1.6) * 0.3 + vnoise(wpos.xz * 8.0) * 0.15;
	vec3 c = sand_col * (0.82 + 0.34 * n);
	float wet = clamp(COLOR.r, 0.0, 1.0);
	c = mix(c, wet_col * (0.9 + 0.2 * n), wet);
	float pol = COLOR.b * (1.0 - smoothstep(0.05, 0.85, restoration + n * 0.15));
	c = mix(c, pol_col * (0.75 + 0.5 * n), clamp(pol, 0.0, 1.0) * 0.92);
	float g = COLOR.g * smoothstep(0.3, 0.9, restoration + (n - 0.5) * 0.35);
	c = mix(c, grass_col * (0.7 + 0.6 * n), clamp(g, 0.0, 1.0));
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.3, wet * 0.85);
	SPECULAR = 0.25 + wet * 0.35;
}
