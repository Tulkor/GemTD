shader_type spatial;
// Endlos laufendes Sprite-Sheet als Billboard (z. B. Flamme auf Lagerfeuer und Kohlenbecken).
// Läuft rein über TIME, braucht kein Skript pro Bild. Die Bilder gehen weich ineinander über,
// die Farbe folgt einer Feuer-Skala (dunkelrot → orange → gelb → weiß glühend, Kern über 1 für das Glow),
// dazu leichtes Flackern der Helligkeit und weiche Kanten, wo die Flamme in Modell oder Boden steckt.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D sheet : source_color, filter_linear, repeat_disable;
uniform vec2 grid = vec2(16.0, 4.0);
uniform float frames = 64.0;
uniform float fps = 30.0;
uniform float offset = 0.0;  // Startbild, damit nebeneinander stehende Flammen nicht gleich flackern
uniform vec4 tint : source_color = vec4(1.0);
uniform float energy = 1.5;
/// Anteil der Feuer-Skala gegenüber den Farben im Sheet (0 = Sheet)
uniform float ramp = 0.6;
/// Kern über 1 heben (HDR), 0 = aus
uniform float hot = 1.2;
uniform float flicker = 0.18;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float soft = 0.12;

void vertex() {
	// Billboard um die senkrechte Achse, Größe aus der Skalierung des Knotens
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 world = MODEL_MATRIX[3].xyz + right * VERTEX.x * sc.x + up * VERTEX.y * sc.y;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

vec4 frame_at(vec2 uv, float f) {
	vec2 cell = vec2(mod(f, grid.x), floor(f / grid.x));
	return texture(sheet, (uv + cell) / grid);
}

void fragment() {
	float ft = TIME * fps + offset;
	float f0 = mod(floor(ft), frames);
	vec4 c = mix(frame_at(UV, f0), frame_at(UV, mod(f0 + 1.0, frames)), fract(ft));
	float heat = clamp(max(c.r, max(c.g, c.b)) * c.a * 1.15, 0.0, 1.0);
	vec3 fire = mix(vec3(0.75, 0.08, 0.01), vec3(1.0, 0.45, 0.06), smoothstep(0.05, 0.45, heat));
	fire = mix(fire, vec3(1.0, 0.85, 0.35), smoothstep(0.4, 0.75, heat));
	fire = mix(fire, vec3(1.0, 0.97, 0.85), smoothstep(0.75, 1.0, heat));
	vec3 rgb = mix(c.rgb, fire, ramp) * (1.0 + hot * smoothstep(0.7, 1.0, heat));
	float fl = 1.0 - flicker * 0.5 + flicker * 0.5 * (sin(TIME * 13.0 + offset) * sin(TIME * 7.3 + offset * 1.7) + 1.0);
	ALBEDO = rgb * tint.rgb * energy * fl;
	float fade = 1.0;
	if (soft > 0.0) {
		float d = texture(depth_tex, SCREEN_UV).r;
		vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
		fade = clamp((-v.z / v.w + VERTEX.z) / soft, 0.0, 1.0);
	}
	ALPHA = c.a * tint.a * fade;
}
