// Kontaktschatten: weiche Abdunklung des Bodens direkt unter Towern und Steinen (eine Art
// Umgebungsverdeckung), damit sie auf dem Boden stehen statt darüber zu schweben.
// Fläche = quadratisches PlaneMesh, etwas größer als die Grundfläche; schwarz mit weichem Alpha.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

/// wie dunkel es direkt unter dem Objekt wird (0 = gar nicht, 1 = schwarz)
uniform float strength = 0.45;
/// halbe Kantenlänge der Grundfläche im Verhältnis zur Fläche (1 = ganze Fläche)
uniform float inner = 0.6;
/// Breite des Auslaufs nach außen, gleiche Einheit
uniform float soft = 0.4;

void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	// abgerundetes Quadrat: Abstand zur Grundfläche (negativ innen)
	vec2 q = p - vec2(inner - 0.15);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 0.15;
	float k = 1.0 - smoothstep(-soft * 0.6, soft, d);
	ALBEDO = vec3(0.0);
	ALPHA = strength * k * k;
}
