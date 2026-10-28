// Sprites der Treffer- und Schuss-Effekte (fx_player.gd). Lage und Größe rechnet fx_player.gd pro Partikel,
// hier nur Bildausschnitt (Sprite-Sheet), Farbe und Farbton-Drehung.
// INSTANCE_CUSTOM: x = Bild im Sheet, y = Farbton-Drehung (0..1), z = Sättigung (Faktor)
// Eingebunden von fx_add.gdshader (additiv, setzt FX_ADD) und fx_mix.gdshader (Alpha).

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 tiles = vec2(1.0, 1.0);
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);
uniform float brightness = 1.0;
// Weiche Kanten: Sprites blenden aus, wo sie in Boden, Gegner oder Tower stoßen (statt harter Schnittkante).
// Vulkan (Forward+): der Tiefenwert geht unverändert als z in INV_PROJECTION_MATRIX (umgekehrtes Z, 1 = nah)
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float soft = 0.15;
// Leuchtkraft der additiven Sprites (fx_add): satte Farbe am Rand statt blassem Weiß, dazu ein heller Kern
// über 1 (HDR), den das Leuchten (Glow) der Umgebung aufgreift. 0 = wie im Sheet (Lichtschein am Boden).
// halo: schwache, farbige Ränder (geringe Deckkraft) anheben, damit Strahlen und Treffer einen sichtbaren
// Farbschein bekommen.
uniform float vivid = 0.8;
uniform float hot = 1.5;
uniform float halo = 0.5;

varying vec4 custom;

void vertex() {
	custom = INSTANCE_CUSTOM;
}

vec3 hue_rotate(vec3 c, float turns) {
	// Drehung um die Graue Achse (Rodrigues), erhält die Helligkeit grob
	float a = turns * 6.2831853;
	vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

void fragment() {
	float frame = floor(custom.x + 0.001);
	vec2 cell = vec2(mod(frame, tiles.x), floor(frame / tiles.x));
	vec2 uv = (UV * uv_scale + uv_offset);
	uv = (fract(uv) + cell) / tiles;
	vec4 t = texture(tex, uv) * COLOR;
	vec3 rgb = t.rgb;
	if (abs(custom.y) > 0.001) {
		rgb = max(hue_rotate(rgb, custom.y), vec3(0.0));
	}
#ifdef FX_ADD
	float peak = max(rgb.r, max(rgb.g, rgb.b));
	if (peak > 0.0001) {
		// Farbton mit voller Helligkeit kräftiger machen, im hellsten Teil weiß glühend und über 1
		vec3 hue = rgb / peak;
		hue = max(mix(vec3(dot(hue, vec3(0.299, 0.587, 0.114))), hue, 1.0 + vivid), vec3(0.0));
		float core = pow(clamp(peak * t.a, 0.0, 1.0), 4.0);
		rgb = mix(hue, vec3(1.0), core * 0.75) * peak * (1.0 + hot * core);
	}
#endif
	float grey = dot(rgb, vec3(0.299, 0.587, 0.114));
	rgb = mix(vec3(grey), rgb, custom.z) * brightness;
	ALBEDO = rgb;
	float a = clamp(t.a, 0.0, 1.0);
#ifdef FX_ADD
	// Schein nur innerhalb des Sprites anheben und zu den Kanten des Rechtecks weich auslaufen lassen,
	// sonst zeichnen sich die fast durchsichtigen Ränder des Sheets als eckiger Kasten ab
	vec2 inner = min(UV, 1.0 - UV);
	float edge_fade = smoothstep(0.0, 0.35, inner.y) * smoothstep(0.0, 0.12, inner.x);
	a = mix(a, sqrt(a), halo * (1.0 - a) * edge_fade);
#endif
	float fade = 1.0;
	if (soft > 0.0) {
		float d = texture(depth_tex, SCREEN_UV).r;
		vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
		float scene = -v.z / v.w;
		fade = clamp((scene + VERTEX.z) / soft, 0.0, 1.0);
	}
	ALPHA = a * fade;
}
