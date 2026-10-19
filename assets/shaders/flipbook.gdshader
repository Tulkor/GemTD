shader_type spatial;
// Endlos laufendes Sprite-Sheet als Billboard (z. B. Flamme auf Lagerfeuer und Kohlenbecken).
// Läuft rein über TIME, braucht kein Skript pro Bild.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D sheet : source_color, filter_linear, repeat_disable;
uniform vec2 grid = vec2(16.0, 4.0);
uniform float frames = 64.0;
uniform float fps = 30.0;
uniform float offset = 0.0;  // Startbild, damit nebeneinander stehende Flammen nicht gleich flackern
uniform vec4 tint : source_color = vec4(1.0);
uniform float energy = 1.5;

void vertex() {
	// Billboard um die senkrechte Achse, Größe aus der Skalierung des Knotens
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vec3 right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 world = MODEL_MATRIX[3].xyz + right * VERTEX.x * sc.x + up * VERTEX.y * sc.y;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	float f = mod(floor(TIME * fps + offset), frames);
	vec2 cell = vec2(mod(f, grid.x), floor(f / grid.x));
	vec4 c = texture(sheet, (UV + cell) / grid);
	ALBEDO = c.rgb * tint.rgb * energy;
	ALPHA = c.a * tint.a;
}
