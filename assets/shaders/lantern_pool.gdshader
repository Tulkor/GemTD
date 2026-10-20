// Lichtkegel einer Laterne auf dem Boden (eeveTD bei Nacht): weicher, warmer Fleck, additiv.
// Billiger als den Boden von vielen OmniLights beleuchten zu lassen (GL-Renderer: Lichter pro Objekt begrenzt).
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 light_color : source_color = vec3(1.0, 0.5, 0.12);
uniform float strength = 1.0;
/// Radius (Anteil der Fläche) des hellen Kerns mit klarem Rand, danach läuft ein schwacher Schein weich aus
uniform float core = 0.45;
uniform float tail = 0.3;
/// Fuß des Laternenpfostens (UV); sein Schatten fällt von der Mitte (Laterne) weg
uniform vec2 post_uv = vec2(0.5);
/// 0..1: Flackern der Flamme (gemeinsamer Takt, je Laterne versetzt über phase)
uniform float flicker = 0.08;
uniform float phase = 0.0;
/// Wie stark der Boden darunter im Laternenlicht aufhellt (wie echtes Licht: Bodenhelligkeit × Lichtfarbe),
/// dazu ein kleiner Anteil reine Lichtfarbe, damit auch sehr dunkler Boden warm schimmert.
uniform float gain = 12.0;
uniform float glow = 0.12;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	// heller Kern, der nach außen etwas nachlässt, mit kurzem, klarem Rand; danach schwacher, weicher Schein
	float edge = 1.0 - smoothstep(core - 0.05, core + 0.04, r);
	float inner = mix(1.0, 0.65, smoothstep(0.0, core, r));
	float outer = tail * pow(1.0 - clamp((r - core) / (1.0 - core), 0.0, 1.0), 1.6);
	float fall = mix(outer, inner, edge);
	// Schatten des Pfostens: schmaler Streifen vom Fuß weg, wird nach außen breiter und weicher
	vec2 dir = post_uv - vec2(0.5);
	float len = length(dir);
	if (len > 0.001) {
		dir /= len;
		vec2 q = UV - post_uv;
		float t = dot(q, dir);
		float side = length(q - dir * t);
		float w = 0.016 + t * 0.07;
		float sh = (1.0 - smoothstep(w * 0.5, w, side)) * smoothstep(-0.004, 0.006, t);
		fall *= 1.0 - 0.8 * sh;
	}
	float f = 1.0 - flicker * (0.5 + 0.5 * sin(TIME * 7.3 + phase) * sin(TIME * 3.1 + phase * 1.7));
	// Helligkeit statt Farbe des Bodens: der ist nachts vom Mond blau, im Laternenlicht soll er warm werden
	float under = dot(texture(screen, SCREEN_UV).rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = (under * gain + glow) * light_color * fall * strength * f;
}
