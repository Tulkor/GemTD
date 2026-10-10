// Felsbrocken: rauchig durchsichtig mit "dunklem Licht" im Inneren.
// Flächen, auf die man frontal blickt (Blick ins Innere), werden dunkel und deckend,
// die Ränder bleiben heller und durchsichtiger.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(0.55, 0.45, 0.78, 1.0);
uniform vec4 core_color : source_color = vec4(0.03, 0.01, 0.07, 1.0);
uniform float edge_alpha = 0.45;
uniform float core_alpha = 0.92;
/// Wie weit der dunkle Kern zu den Rändern reicht (höher = kleinerer Kern)
uniform float core_falloff = 1.6;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float core = pow(facing, core_falloff);
	float rim = pow(1.0 - facing, 3.0);
	ALBEDO = mix(color.rgb, core_color.rgb, core);
	ALPHA = mix(edge_alpha, core_alpha, core);
	ROUGHNESS = 0.15;
	SPECULAR = 0.7;
	// schwacher violetter Saum, damit die Kontur vor dem dunklen Feld sichtbar bleibt
	EMISSION = color.rgb * rim * 1.6;
}
