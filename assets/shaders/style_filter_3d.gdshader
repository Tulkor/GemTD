// Stil-Filter als Bildschirm-Rechteck in der 3D-Szene (StyleFilter mit "keep_tall", eeveTD/YouTD): wird als
// Erstes im durchsichtigen Durchgang gezeichnet, liest das deckende Bild und die Tiefe. Was im Spielfeld
// (area, Welt-x/z) höher als keep_from über dem Boden steht (Tower, Gegner, Laternen), bleibt ungefiltert und
// sticht so aus dem ausgewaschenen Wald heraus. Effekte (durchsichtig) kommen danach und bleiben unberührt.
// Arbeitet vor dem Tonemapping: Farben werden für die Korrektur nach sRGB und zurück gerechnet.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

#include "res://assets/shaders/style_grade.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
/// Spielfeld in Welt-Einheiten (x, z, Breite, Tiefe); außerhalb wird alles gefiltert
uniform vec4 area = vec4(0.0, 0.0, 0.0, 0.0);
/// ab dieser Höhe über dem Boden ungefiltert (weich bis keep_full)
uniform float keep_from = 0.12;
uniform float keep_full = 0.4;
/// ungefilterte Teile leicht aufhellen, damit sie noch mehr herausstechen
uniform float keep_gain = 1.08;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0);
}

void fragment() {
	vec3 base = texture(screen, SCREEN_UV).rgb;
	// HDR (Glow-Spitzen) bleibt über 1 erhalten: nur der Anteil bis 1 wird umgefärbt
	vec3 lo = min(base, vec3(1.0));
	vec3 srgb = pow(lo, vec3(1.0 / 2.2));
	vec3 g = grade_screen(grade_color(srgb), SCREEN_UV, FRAGCOORD.xy, VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, TIME);
	vec3 graded = pow(max(g, vec3(0.0)), vec3(2.2)) + (base - lo);
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz / view.w, 1.0)).xyz;
	float keep = 0.0;
	if (area.z > 0.0 && world.x > area.x && world.z > area.y && world.x < area.x + area.z && world.z < area.y + area.w) {
		keep = smoothstep(keep_from, keep_full, world.y);
	}
	vec3 c = mix(base, graded, strength);
	ALBEDO = mix(c, base * keep_gain, keep);
	ALPHA = 1.0;
}
