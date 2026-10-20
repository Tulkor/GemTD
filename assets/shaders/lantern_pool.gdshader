// Lichtkegel einer Laterne auf dem Boden (eeveTD bei Nacht): weicher, warmer Fleck, additiv.
// Billiger als den Boden von vielen OmniLights beleuchten zu lassen (GL-Renderer: Lichter pro Objekt begrenzt).
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 light_color : source_color = vec3(1.0, 0.6, 0.16);
uniform float strength = 1.0;
/// Anteil des Radius, ab dem der Fleck zum Rand hin ausläuft (größer = klarerer Rand)
uniform float core = 0.62;
/// 0..1: Flackern der Flamme (gemeinsamer Takt, je Laterne versetzt über phase)
uniform float flicker = 0.08;
uniform float phase = 0.0;
/// Wie stark der Boden darunter im Laternenlicht aufhellt (wie echtes Licht: Bodenfarbe × Lichtfarbe),
/// dazu ein kleiner Anteil reine Lichtfarbe, damit auch sehr dunkler Boden warm schimmert.
uniform float gain = 14.0;
uniform float glow = 0.2;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	// heller Kern, der nach außen nur leicht nachlässt, dann ein kurzer, klarer Übergang zum Rand
	float fall = mix(1.0, 0.55, smoothstep(0.0, core, r)) * (1.0 - smoothstep(core, 1.0, r));
	float f = 1.0 - flicker * (0.5 + 0.5 * sin(TIME * 7.3 + phase) * sin(TIME * 3.1 + phase * 1.7));
	vec3 under = texture(screen, SCREEN_UV).rgb;
	ALBEDO = (under * light_color * gain + light_color * glow) * fall * strength * f;
}
