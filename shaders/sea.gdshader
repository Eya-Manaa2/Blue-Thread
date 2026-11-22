shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Mer procédurale (compatible GL Compatibility / WebGL2).
// restoration : 0 = mer brune huileuse, 1 = mer turquoise.

uniform float restoration : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform vec3 dirty_deep : source_color = vec3(0.07, 0.09, 0.07);
uniform vec3 dirty_shallow : source_color = vec3(0.22, 0.22, 0.15);
uniform vec3 clean_deep : source_color = vec3(0.02, 0.20, 0.40);
uniform vec3 clean_shallow : source_color = vec3(0.08, 0.62, 0.68);
uniform vec3 sky_col : source_color = vec3(0.8, 0.6, 0.4);

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float shore(float x) { return -1.5 + 2.2 * sin(x * 0.06 + phase) + 1.0 * sin(x * 0.17); }

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;
	float amp = mix(0.16, 0.24, restoration);
	float a1 = w.x * 0.25 + t * 1.1;
	float a2 = w.z * 0.32 - t * 1.4 + w.x * 0.1;
	float a3 = (w.x + w.z) * 0.6 + t * 2.0;
	VERTEX.y += (sin(a1) * 0.5 + sin(a2) * 0.35 + sin(a3) * 0.15) * amp;
	float dx = cos(a1) * 0.125 + cos(a2) * 0.035 + cos(a3) * 0.09;
	float dz = cos(a2) * 0.112 + cos(a3) * 0.09;
	NORMAL = normalize(vec3(-dx * amp * 2.0, 1.0, -dz * amp * 2.0));
	wpos = w;
}

void fragment() {
	float d = wpos.z - shore(wpos.x);
	float depth = clamp(-d / 30.0, 0.0, 1.0);
	vec3 deep = mix(dirty_deep, clean_deep, restoration);
	vec3 shal = mix(dirty_shallow, clean_shallow, restoration);
	float n = vnoise(wpos.xz * 0.9 + vec2(TIME * 0.15, TIME * 0.05)) * 0.6 + vnoise(wpos.xz * 3.1 - vec2(TIME * 0.2, 0.0)) * 0.4;
	vec3 col = mix(shal, deep, sqrt(depth)) * (0.9 + 0.2 * n);

	// nappes d'huile irisées (disparaissent avec la restauration)
	float oil = (1.0 - smoothstep(0.0, 0.7, restoration)) * smoothstep(0.55, 0.78, vnoise(wpos.xz * 0.07 + vec2(TIME * 0.01, 0.0)));
	vec3 irid = 0.5 + 0.5 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + vnoise(wpos.xz * 0.45) * 2.0));
	col = mix(col, col * 0.55 + irid * 0.22, oil * 0.75);

	// écume le long du rivage
	float band = 1.4 + 0.7 * sin(TIME * 1.2 + wpos.x * 0.25);
	float f = 1.0 - smoothstep(0.0, band, -d);
	f *= smoothstep(0.25, 0.65, vnoise(wpos.xz * 2.6 + vec2(TIME * 0.35, 0.0)) + f * 0.35);
	vec3 foam_col = mix(vec3(0.70, 0.62, 0.48), vec3(0.96, 0.98, 1.0), restoration);
	col = mix(col, foam_col, clamp(f, 0.0, 1.0) * 0.9);

	// reflet du ciel en incidence rasante
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	col = mix(col, sky_col, fr * 0.3);

	ALBEDO = col;
	ROUGHNESS = mix(0.16, 0.05, restoration) + f * 0.5;
	SPECULAR = 0.8;
}
