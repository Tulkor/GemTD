// Leichte Kontur um alles Deckende (CameraRig.add_environment, Stil-Wert "outline"): Bildschirm-Rechteck,
// das im Tiefenbild Kanten sucht. Ebene Flächen haben in 1/Tiefe keine Krümmung, nur Umrisse und Knicke
// geben einen Ausschlag; dort eine dünne, halb durchsichtige Linie.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float strength = 0.45;
/// Linienbreite in Pixeln
uniform float width = 1.0;
/// ab welchem Sprung (relativ) eine Linie entsteht
uniform float threshold = 0.012;
/// weiter entfernt als das (Einheiten) keine Linien mehr (Himmel, Hintergrund)
uniform float max_depth = 80.0;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0);
}

// Tiefe hier übergeben: die Tiefen-Textur geht im Compatibility-Renderer nur direkt in fragment()
float lin(vec2 uv, float d, mat4 inv_proj) {
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 px = width / VIEWPORT_SIZE;
	float zc = lin(SCREEN_UV, texture(depth_tex, SCREEN_UV).r, INV_PROJECTION_MATRIX);
	vec2 uv_zl = SCREEN_UV - vec2(px.x, 0.0);
	float zl = lin(uv_zl, texture(depth_tex, uv_zl).r, INV_PROJECTION_MATRIX);
	vec2 uv_zr = SCREEN_UV + vec2(px.x, 0.0);
	float zr = lin(uv_zr, texture(depth_tex, uv_zr).r, INV_PROJECTION_MATRIX);
	vec2 uv_zd = SCREEN_UV - vec2(0.0, px.y);
	float zd = lin(uv_zd, texture(depth_tex, uv_zd).r, INV_PROJECTION_MATRIX);
	vec2 uv_zu = SCREEN_UV + vec2(0.0, px.y);
	float zu = lin(uv_zu, texture(depth_tex, uv_zu).r, INV_PROJECTION_MATRIX);
	// Linie nur auf der vorderen Seite eines Sprungs (das nähere Objekt bekommt den Rand)
	float near = min(zc, min(min(zl, zr), min(zd, zu)));
	if (zc > near * 1.02 + 0.01 || near > max_depth) {
		discard;
	}
	float lap = abs(1.0 / zl + 1.0 / zr - 2.0 / zc) + abs(1.0 / zd + 1.0 / zu - 2.0 / zc);
	float e = smoothstep(threshold, threshold * 3.0, lap * zc);
	ALBEDO = color.rgb;
	ALPHA = e * strength * color.a;
}
