// Feld im Neon-Stil: fast durchsichtiger violetter Boden mit leuchtendem Gitter.
// Blockierte Felder bleiben leer, ihre Ränder bekommen eine hellere Neonlinie.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

/// 1 = blockiertes Feld, ein Pixel pro Feld
uniform sampler2D blocked : filter_nearest, repeat_disable;
uniform vec2 cells = vec2(74.0, 74.0);
uniform float cell = 0.5;
/// Abstand der Gitterlinien in Feldern (2 = eine Towerbreite)
uniform float grid_cells = 2.0;
uniform vec4 line_color : source_color = vec4(1.0, 0.36, 0.86, 1.0);
uniform vec4 edge_color : source_color = vec4(0.75, 0.4, 1.0, 1.0);
uniform vec4 floor_color : source_color = vec4(0.09, 0.03, 0.22, 1.0);
uniform float floor_alpha = 0.4;
uniform float line_energy = 1.0;
uniform float edge_energy = 2.6;
/// Jede wievielte Gitterlinie hell ist; die übrigen werden mit minor_energy/minor_alpha gedämpft
uniform float major_every = 5.0;
uniform float minor_energy = 0.5;
uniform float minor_alpha = 0.6;
/// Linienbreite in Einheiten (1 = Towerbreite)
uniform float line_width = 0.014;
uniform float halo_width = 0.08;
/// zusätzliche feine Linien je Feld (Map-Editor), 0 = aus
uniform float fine_strength = 0.0;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float is_blocked(ivec2 c) {
	if (c.x < 0 || c.y < 0 || c.x >= int(cells.x) || c.y >= int(cells.y)) {
		return 1.0;
	}
	return step(0.5, texelFetch(blocked, c, 0).r);
}

// Röhre mit weißem Kern und weichem Lichthof; d = Abstand zur Linie in Einheiten,
// aa = Breite eines Pixels in Einheiten (nicht fwidth(d): d springt an Feldgrenzen)
vec4 tube(float d, float width, vec3 col, float energy, float aa) {
	float body = 1.0 - smoothstep(width, width + aa, d);
	float core_ = (1.0 - smoothstep(width * 0.3, width * 0.3 + aa, d)) * 0.7;
	float halo = exp(-d / halo_width) * 0.35;
	vec3 c = mix(col, vec3(1.0), core_) * energy;
	float a = max(body, halo);
	return vec4(mix(col * energy * 0.6, c, body), a);
}

void fragment() {
	vec2 g = world_xz / cell;
	ivec2 c = ivec2(floor(g));
	float b = is_blocked(c);
	vec2 f = fract(g);
	float aa = max(length(fwidth(world_xz)) * 0.7, 0.0005);

	vec3 col = floor_color.rgb;
	float alpha = floor_alpha * (1.0 - b);

	if (b < 0.5) {
		// Gitterlinien: jede major_every-te hell, die übrigen gedämpft
		vec2 gg = g / grid_cells;
		vec2 dg = abs(fract(gg + 0.5) - 0.5) * grid_cells * cell;
		vec4 l = tube(min(dg.x, dg.y), line_width, line_color.rgb, line_energy * minor_energy, aa);
		l.a *= minor_alpha;
		col = mix(col, l.rgb, l.a);
		alpha = max(alpha, l.a);
		vec2 gm = g / (grid_cells * major_every);
		vec2 dm = abs(fract(gm + 0.5) - 0.5) * grid_cells * major_every * cell;
		vec4 m = tube(min(dm.x, dm.y), line_width, line_color.rgb, line_energy, aa);
		col = mix(col, m.rgb, m.a);
		alpha = max(alpha, m.a);
		if (fine_strength > 0.0) {
			vec2 df = abs(fract(g + 0.5) - 0.5) / fwidth(g);
			float fl = (1.0 - clamp(min(df.x, df.y), 0.0, 1.0)) * fine_strength;
			col = mix(col, line_color.rgb, fl);
			alpha = max(alpha, fl);
		}
		// Ränder zu blockierten Feldern
		float de = 10.0;
		if (is_blocked(c + ivec2(-1, 0)) > 0.5) de = min(de, f.x);
		if (is_blocked(c + ivec2(1, 0)) > 0.5) de = min(de, 1.0 - f.x);
		if (is_blocked(c + ivec2(0, -1)) > 0.5) de = min(de, f.y);
		if (is_blocked(c + ivec2(0, 1)) > 0.5) de = min(de, 1.0 - f.y);
		vec4 e = tube(de * cell, line_width * 1.6, edge_color.rgb, edge_energy, aa);
		col = mix(col, e.rgb, e.a);
		alpha = max(alpha, e.a);
	}
	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
