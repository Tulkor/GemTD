// Nachbearbeitung über dem ganzen Bild (CameraRig.add_environment, Stilwerte "vignette"/"vignette_color"):
// zu den Rändern hin abgedunkelt und leicht in der Stilfarbe getönt, damit der Blick zur Mitte geht.
// Legt nur eine Farbe darüber (blend_mix mit Deckkraft): liest kein Bild, die Mitte bleibt unverändert.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

uniform float vignette = 0.35;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
/// wo die Abdunklung beginnt (0 = Mitte, 1 = Ecke)
uniform float inner = 0.45;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0);
}

void fragment() {
	vec2 p = (SCREEN_UV - 0.5) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
	float r = length(p) / length(vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0) * 0.5);
	float v = smoothstep(inner, 1.15, r) * vignette;
	ALBEDO = vignette_color.rgb;
	ALPHA = v;
}
