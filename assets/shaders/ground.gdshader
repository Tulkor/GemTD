// Map-Boden: zwei Grasarten und Erde, überblendet.
// Erde liegt dort, wo die Splat-Textur es sagt (Laufweg, Spawn, Ziel, Checkpoints, "_"-Felder),
// die Ränder werden mit Rauschen ausgefranst. Die beiden Grasarten wechseln großflächig per Rauschen.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_b : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
/// Normal-Maps (aus der Helligkeit der Fotos abgeleitet), damit das Licht Struktur zeigt.
uniform sampler2D grass_a_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_b_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength = 1.0;
/// Erde-Anteil je Rasterfeld (0..1), ein Pixel pro Feld.
uniform sampler2D splat : filter_linear, repeat_disable;
/// Größe der Map in Einheiten.
uniform vec2 map_size = vec2(37.0, 37.0);
/// Kantenlänge einer Texturkachel in Einheiten (1 Einheit = 1 Towerbreite).
uniform float grass_tile = 1.5;
uniform float dirt_tile = 2.2;
/// Fotos sind sehr satt und hell; etwas abdunkeln und entsättigen, damit Tower und Gegner auffallen.
uniform float brightness = 0.72;
uniform float saturation = 0.75;
/// Farbstich über alles (Druidenhain: etwas moosiger)
uniform vec3 tint = vec3(1.0);
/// Deckkraft des Bodens; 0 = unsichtbar (nur Rasterlinien bleiben sichtbar).
uniform float ground_alpha = 1.0;
/// Rasterlinien (für den Map-Editor), 0 = aus.
uniform float grid_strength = 0.0;
uniform float cell = 0.5;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

// Zwei gedrehte, unterschiedlich große Abtastungen derselben Textur, per Rauschen gemischt:
// so fällt die Wiederholung der Kacheln nicht auf.
const mat2 ROT = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));

vec3 sample_varied(sampler2D t, vec2 p, float n) {
	vec3 a = texture(t, p).rgb;
	vec3 b = texture(t, ROT * p * 0.71 + vec2(0.37, 0.13)).rgb;
	return mix(a, b, smoothstep(0.3, 0.7, n));
}

void fragment() {
	vec2 p = world_xz;
	float n_tile = fbm(p * 0.35);
	vec2 uv_ga = p / grass_tile;
	vec2 uv_gb = p / (grass_tile * 1.15) + vec2(0.5);
	vec2 uv_dt = p / dirt_tile;
	vec3 ga = sample_varied(grass_a, uv_ga, n_tile);
	vec3 gb = sample_varied(grass_b, uv_gb, 1.0 - n_tile);
	vec3 dt = sample_varied(dirt, uv_dt, n_tile);
	vec3 na = sample_varied(grass_a_normal, uv_ga, n_tile);
	vec3 nb = sample_varied(grass_b_normal, uv_gb, 1.0 - n_tile);
	vec3 nd = sample_varied(dirt_normal, uv_dt, n_tile);

	// Grasarten: kleine, unregelmäßige Flecken (keine großen einfarbigen Flächen)
	float g_mix = smoothstep(0.3, 0.7, fbm(p * 0.45 + vec2(3.7, 1.2)));
	g_mix = 0.2 + 0.6 * g_mix;  // nie ganz eine Sorte: weiche, unauffällige Wechsel
	vec3 grass = mix(ga, gb * 1.15, g_mix);
	vec3 grass_n = mix(na, nb, g_mix);

	// Erde: Splat-Wert plus ausfransender Rand
	float w = texture(splat, p / map_size).r;
	float edge = fbm(p * 1.1 + vec2(11.0, 5.0)) - 0.5;
	float d = smoothstep(0.4, 0.6, w + edge * 0.55);
	// vereinzelt abgetretene Stellen im Gras
	float worn = smoothstep(0.66, 0.78, fbm(p * 0.16 + vec2(40.0, 7.0)));
	d = max(d, worn * 0.45);
	// Übergang: Gras hält sich in den Senken der Erde (helle Erde zuerst sichtbar)
	float dirt_h = dot(dt, vec3(0.33));
	float blend = clamp((d - 0.5) * 2.5 + 0.5 + (dirt_h - 0.35) * 0.8 * (1.0 - abs(d * 2.0 - 1.0)), 0.0, 1.0);
	vec3 col = mix(grass, dt, blend);
	vec3 nrm = mix(grass_n, nd, blend);
	// Vertiefungen (dunkle Stellen im Foto) zusätzlich abdunkeln
	float cavity = smoothstep(0.05, 0.45, dot(col, vec3(0.299, 0.587, 0.114)));
	col *= mix(0.7, 1.0, cavity);

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation) * brightness * tint;
	// leichte großflächige Helligkeitsschwankung
	col *= 0.94 + 0.12 * fbm(p * 0.12 + vec2(-8.0, 2.0));

	float alpha = ground_alpha;
	if (grid_strength > 0.0) {
		vec2 g = abs(fract(p / cell + 0.5) - 0.5) / fwidth(p / cell);
		float line = 1.0 - clamp(min(g.x, g.y), 0.0, 1.0);
		// auf sichtbarem Boden dunkle Linien, auf durchsichtigem helle
		col = mix(col * (1.0 - grid_strength * line), vec3(0.55, 0.65, 0.8), (1.0 - ground_alpha) * line);
		alpha = max(alpha, grid_strength * line);
	}

	ALBEDO = col;
	ALPHA = alpha;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = mix(0.85, 0.95, blend);
	SPECULAR = 0.35;
}
