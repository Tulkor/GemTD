// Lichtkegel einer Laterne auf dem Boden (eeveTD bei Nacht): weicher, warmer Fleck, additiv.
// Billiger als den Boden von vielen OmniLights beleuchten zu lassen (GL-Renderer: Lichter pro Objekt begrenzt).
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 light_color : source_color = vec3(1.0, 0.7, 0.35);
uniform float strength = 0.7;
/// 0..1: Flackern der Flamme (gemeinsamer Takt, je Laterne versetzt über phase)
uniform float flicker = 0.08;
uniform float phase = 0.0;

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float fall = pow(clamp(1.0 - r, 0.0, 1.0), 2.2);
	float f = 1.0 - flicker * (0.5 + 0.5 * sin(TIME * 7.3 + phase) * sin(TIME * 3.1 + phase * 1.7));
	ALBEDO = light_color * fall * strength * f;
}
