shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Faisceau lumineux vertical au-dessus d'un objet à collecter.
uniform vec4 color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform float intensity = 0.55;
uniform float height = 6.0;
varying float hf;
void vertex() {
	hf = clamp((VERTEX.y + height * 0.5) / height, 0.0, 1.0);
}
void fragment() {
	float pulse = 0.75 + 0.25 * sin(TIME * 3.0 - hf * 8.0);
	float facing = abs(dot(NORMAL, VIEW));
	float near_fade = smoothstep(5.0, 14.0, length(VERTEX));   // pas d'éblouissement près de la caméra
	ALBEDO = color.rgb;
	ALPHA = clamp(pow(1.0 - hf, 1.6) * pulse * intensity * near_fade * (0.2 + 0.5 * facing), 0.0, 1.0) * color.a;
}
