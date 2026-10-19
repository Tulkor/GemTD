// Feld im Neon-Stil: fast durchsichtiger violetter Boden mit leuchtendem Gitter.
// Blockierte Felder bleiben leer, ihre Ränder bekommen eine hellere Neonlinie.
// Andere Stile (FieldStyle) setzen nur Parameter: ohne weißen Kern und Lichthof wirkt das Raster
// wie gemalt (Druidenhain über Gras), mit Marmor, doppelten Hauptlinien und Rauten wie Art déco.
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
/// Ursprung des Gitters in Feldern (erstes freies Feld), damit die hellen Linien am Feldrand liegen
uniform vec2 grid_origin = vec2(0.0);
/// helle Linien über der Glow-Schwelle, damit sie wie der Außenrand leicht scheinen
uniform float major_energy = 2.0;
uniform float minor_energy = 0.5;
uniform float minor_alpha = 0.6;
/// Raster der einzelnen Felder (halbe Towerbreite, Tower lassen sich darauf versetzen), noch dunkler
uniform float cell_energy = 0.42;
uniform float cell_alpha = 0.5;
/// Sperrzone um Spawn, Ziel und Checkpoints: durchsichtig rot mit Neonrand
uniform vec4 zone_color : source_color = vec4(1.0, 0.12, 0.22, 1.0);
uniform float zone_alpha = 0.34;
uniform float zone_edge_energy = 3.0;
/// Linienbreite in Einheiten (1 = Towerbreite)
uniform float line_width = 0.014;
uniform float halo_width = 0.08;
/// zusätzliche feine Linien je Feld (Map-Editor), 0 = aus
uniform float fine_strength = 0.0;
/// Anteil des weißen Kerns der Linien (Neon 0.7, gemalte Linien 0)
uniform float core_white = 0.7;
/// Deckkraft der hellen Hauptlinien
uniform float major_alpha = 1.0;
/// 1 = Hauptlinien doppelt (zwei dünne parallele Linien, Art déco)
uniform float major_double = 0.0;
/// Rauten an den Kreuzungen der Hauptlinien, halbe Diagonale in Einheiten (0 = keine)
uniform float diamond_size = 0.0;
/// Marmor-Adern im Boden (0 = glatt)
uniform float marble = 0.0;
/// Fläche der blockierten Felder (0 = durchsichtig wie bisher)
uniform vec4 blocked_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float blocked_alpha = 0.0;
/// Rand der Sperrzone; Deckkraft 0 = in zone_color
uniform vec4 zone_edge_color : source_color = vec4(0.0);

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
	vec3 c = mix(col, vec3(1.0), core_ * core_white / 0.7) * energy;
	float a = max(body, halo);
	return vec4(mix(col * energy * 0.6, c, body), a);
}

float is_zone(ivec2 c) {
	if (c.x < 0 || c.y < 0 || c.x >= int(cells.x) || c.y >= int(cells.y)) {
		return 0.0;
	}
	return step(0.5, texelFetch(blocked, c, 0).g);
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 u = fract(p);
	u = u * u * (3.0 - 2.0 * u);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Marmor: dunkle Grundfläche mit feinen hellen Adern
vec3 marble_color(vec3 base, vec2 p) {
	float n = noise(p * 0.7) * 0.6 + noise(p * 1.9) * 0.3 + noise(p * 5.0) * 0.1;
	float vein = 1.0 - smoothstep(0.0, 0.035, abs(sin((p.x * 0.6 + p.y * 0.35 + n * 5.0) * 3.14159)));
	return base * (0.85 + n * 0.3) + vec3(0.22, 0.3, 0.28) * vein * 0.35;
}

void fragment() {
	vec2 g = world_xz / cell;
	ivec2 c = ivec2(floor(g));
	float b = is_blocked(c);
	vec2 f = fract(g);
	float aa = max(length(fwidth(world_xz)) * 0.7, 0.0005);

	vec3 col = floor_color.rgb;
	if (marble > 0.0) {
		col = mix(col, marble_color(col, world_xz), marble);
	}
	float alpha = floor_alpha * (1.0 - b);
	if (b > 0.5) {
		col = blocked_color.rgb;
		alpha = blocked_alpha;
	}

	if (b < 0.5) {
		// Gitterlinien: jede major_every-te hell, die übrigen gedämpft
		vec2 go = g - grid_origin;
		vec2 dc = abs(fract(go + 0.5) - 0.5) * cell;
		vec4 cl = tube(min(dc.x, dc.y), line_width * 0.9, line_color.rgb, line_energy * cell_energy, aa);
		cl.a *= cell_alpha;
		col = mix(col, cl.rgb, cl.a);
		alpha = max(alpha, cl.a);
		vec2 gg = go / grid_cells;
		vec2 dg = abs(fract(gg + 0.5) - 0.5) * grid_cells * cell;
		vec4 l = tube(min(dg.x, dg.y), line_width, line_color.rgb, line_energy * minor_energy, aa);
		l.a *= minor_alpha;
		col = mix(col, l.rgb, l.a);
		alpha = max(alpha, l.a);
		vec2 gm = go / (grid_cells * major_every);
		vec2 dm = abs(fract(gm + 0.5) - 0.5) * grid_cells * major_every * cell;
		float dmm = min(dm.x, dm.y);
		if (major_double > 0.5) {
			dmm = abs(dmm - line_width * 3.0);
		}
		vec4 m = tube(dmm, line_width * 1.2, line_color.rgb, line_energy * major_energy, aa);
		m.a *= major_alpha;
		col = mix(col, m.rgb, m.a);
		alpha = max(alpha, m.a);
		if (diamond_size > 0.0) {
			// Raute an jeder Kreuzung der Hauptlinien, gefüllt, mit dunklem Innenrand
			float dd = (dm.x + dm.y) / diamond_size;
			float fill = 1.0 - smoothstep(1.0 - aa / diamond_size, 1.0, dd);
			float inner = smoothstep(0.55, 0.55 + aa / diamond_size, dd) * (1.0 - smoothstep(0.7, 0.7 + aa / diamond_size, dd));
			vec3 dcol = mix(line_color.rgb * line_energy * major_energy, floor_color.rgb, inner * 0.8);
			col = mix(col, dcol, fill * major_alpha);
			alpha = max(alpha, fill * major_alpha);
		}
		if (fine_strength > 0.0) {
			vec2 df = abs(fract(g + 0.5) - 0.5) / fwidth(g);
			float fl = (1.0 - clamp(min(df.x, df.y), 0.0, 1.0)) * fine_strength;
			col = mix(col, line_color.rgb, fl);
			alpha = max(alpha, fl);
		}
		// Sperrzone um die Wegpunkte: rote Fläche, Neonrand zu bebaubaren Feldern
		if (is_zone(c) > 0.5) {
			col = mix(col, zone_color.rgb, zone_alpha);
			alpha = max(alpha, zone_alpha + floor_alpha * 0.5);
			float dz = 10.0;
			if (is_zone(c + ivec2(-1, 0)) < 0.5) dz = min(dz, f.x);
			if (is_zone(c + ivec2(1, 0)) < 0.5) dz = min(dz, 1.0 - f.x);
			if (is_zone(c + ivec2(0, -1)) < 0.5) dz = min(dz, f.y);
			if (is_zone(c + ivec2(0, 1)) < 0.5) dz = min(dz, 1.0 - f.y);
			vec3 zc = zone_edge_color.a > 0.0 ? zone_edge_color.rgb : zone_color.rgb;
			vec4 z = tube(dz * cell, line_width * 1.8, zc, zone_edge_energy, aa);
			col = mix(col, z.rgb, z.a);
			alpha = max(alpha, z.a);
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
