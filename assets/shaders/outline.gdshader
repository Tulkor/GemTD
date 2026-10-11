// Kontur per "umgedrehter Hülle": das Modell entlang geglätteter Normalen aufgebläht,
// nur die Rückseiten gezeichnet. Läuft im Transparenz-Durchgang nach dem Objekt (render_priority),
// damit das Objekt mit seinem Tiefenwert die Hülle innen verdeckt und nur der Rand sichtbar bleibt.
shader_type spatial;
render_mode unshaded, blend_mix, cull_front, shadows_disabled, depth_draw_never;

uniform vec4 color : source_color = vec4(0.72, 0.45, 1.0, 1.0);
uniform float energy = 1.8;
/// Dicke in Einheiten (1 = Towerbreite), unabhängig von der Modellgröße
uniform float width = 0.02;
/// Unterhalb dieser Höhe (Welt-Y) wird nichts gezeichnet: kein Leuchtband unter dem Boden
uniform float floor_y = 0.004;

varying float world_y;

void vertex() {
	float scale = length(MODEL_MATRIX[0].xyz);
	VERTEX += normalize(NORMAL) * width / max(scale, 0.0001);
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	if (world_y < floor_y) {
		discard;
	}
	ALBEDO = color.rgb * energy;
	ALPHA = 1.0;
}
