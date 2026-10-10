// Kontur per "umgedrehter Hülle": das Modell entlang geglätteter Normalen aufgebläht,
// nur die Rückseiten gezeichnet. Läuft im Transparenz-Durchgang nach dem Stein (render_priority),
// damit der Stein mit seinem Tiefenwert die Hülle innen verdeckt und nur der Rand sichtbar bleibt.
shader_type spatial;
render_mode unshaded, blend_mix, cull_front, shadows_disabled, depth_draw_never;

uniform vec4 color : source_color = vec4(0.72, 0.45, 1.0, 1.0);
uniform float energy = 1.8;
/// Dicke in Einheiten (1 = Towerbreite), unabhängig von der Modellgröße
uniform float width = 0.02;

void vertex() {
	float scale = length(MODEL_MATRIX[0].xyz);
	VERTEX += normalize(NORMAL) * width / max(scale, 0.0001);
}

void fragment() {
	ALBEDO = color.rgb * energy;
	ALPHA = 1.0;
}
