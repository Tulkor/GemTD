// Farbkorrektur des Stil-Filters (StyleFilter), gemeinsam für style_filter.gdshader (über dem fertigen Bild)
// und style_filter_3d.gdshader (vor den durchsichtigen Effekten, Tower ausgenommen). Erwartet sRGB-Werte 0..1.

/// Gesamtstärke (0 = Bild unverändert)
uniform float strength : hint_range(0.0, 1.0) = 1.0;
/// Farbe der dunklen und der hellen Bildteile (Split-Toning, 0,5 = neutral), Stärke split
uniform vec3 shadow_tint : source_color = vec3(0.5);
uniform vec3 highlight_tint : source_color = vec3(0.5);
uniform float split = 0.0;
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float brightness = 1.0;
/// Farbton (0..1), der seine Sättigung behält bzw. verstärkt wird (Messing, Laternen); Breite des Bereichs
uniform float hue_target = 0.1;
uniform float hue_width = 0.0;
uniform float hue_sat = 1.0;
uniform float hue_gain = 1.0;
/// Zeilenraster wie auf einem Röhrenbildschirm: Stärke und Abstand in Pixeln
uniform float scanlines = 0.0;
uniform float scan_px = 3.0;
/// Filmkorn
uniform float grain = 0.0;
/// Dunst von oben (in der Spielansicht = hinten, weit weg): Farbe, Stärke, ab welcher Höhe (0 oben, 1 unten)
uniform vec3 haze_color : source_color = vec3(0.0);
uniform float haze = 0.0;
uniform float haze_reach = 0.5;
/// Dunst von unten (Bodennebel am vorderen Bildrand), gleiche Farbe
uniform float haze_low = 0.0;
/// Ränder abdunkeln in dieser Farbe (zusätzlich zur Vignette des Spielfelds)
uniform vec3 edge_color : source_color = vec3(0.0);
uniform float edge = 0.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

/// Farben (Sättigung, Split-Toning, Kontrast, Helligkeit) ohne Dunst und Ränder.
vec3 grade_color(vec3 c) {
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	// Sättigung: ausgewählter Farbton nach hue_sat/hue_gain, der Rest nach saturation
	float sel = 0.0;
	if (hue_width > 0.0) {
		vec3 hsv = rgb2hsv(c);
		float dh = abs(hsv.x - hue_target);
		dh = min(dh, 1.0 - dh);
		sel = (1.0 - smoothstep(hue_width * 0.5, hue_width, dh)) * smoothstep(0.08, 0.25, hsv.y);
	}
	float sat = mix(saturation, hue_sat, sel);
	c = mix(vec3(lum), c, sat) * mix(1.0, hue_gain, sel);
	if (split > 0.0) {
		float w = smoothstep(0.0, 1.0, clamp(lum, 0.0, 1.0));
		vec3 tone = mix(shadow_tint, highlight_tint, w) - 0.5;
		c += tone * split * (1.0 - abs(w - 0.5));
	}
	c = (c - 0.5) * contrast + 0.5;
	return c * brightness;
}

/// Dunst oben/unten, dunkle Ränder, Zeilenraster und Korn (uv 0..1, frag in Pixeln, aspect = Breite/Höhe).
vec3 grade_screen(vec3 c, vec2 uv, vec2 frag, float aspect, float time) {
	if (haze > 0.0) {
		c = mix(c, haze_color, (1.0 - smoothstep(0.0, haze_reach, uv.y)) * haze);
	}
	if (haze_low > 0.0) {
		c = mix(c, haze_color, smoothstep(0.75, 1.05, uv.y) * haze_low);
	}
	if (edge > 0.0) {
		vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
		float r = length(p) / length(vec2(aspect, 1.0) * 0.5);
		c = mix(c, edge_color, smoothstep(0.55, 1.2, r) * edge);
	}
	if (scanlines > 0.0) {
		c *= 1.0 - scanlines * (0.5 + 0.5 * cos(frag.y / scan_px * 6.2831853));
	}
	if (grain > 0.0) {
		c += (hash(frag + fract(time) * 91.7) - 0.5) * grain;
	}
	return max(c, vec3(0.0));
}
