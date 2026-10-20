// Blockstadt (Shopping Maul): Quader in Petrol mit schwach erleuchteten Fenstern.
// Farbe kommt pro Instanz aus der MultiMesh (COLOR). Fenster liegen im Weltraster, damit sie bei
// jeder Gebäudegröße gleich groß sind; welche Fenster leuchten, hängt von Gebäude und Fenster ab.
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform vec4 window_color : source_color = vec4(0.85, 0.7, 0.42, 1.0);
uniform float window_energy = 0.55;
/// Anteil der erleuchteten Fenster
uniform float window_lit = 0.22;
uniform vec4 window_dark : source_color = vec4(0.04, 0.09, 0.1, 1.0);
/// Fensterraster in Einheiten (waagrecht, senkrecht)
uniform vec2 window_step = vec2(0.13, 0.17);
uniform vec2 window_size = vec2(0.5, 0.5);
/// Dächer etwas heller, Fuß der Gebäude dunkler (falscher Umgebungsschatten)
uniform float roof_light = 0.85;
uniform float foot_dark = 0.55;

varying vec3 world_pos;
varying vec3 world_nrm;
varying float seed;
varying float local_y;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 o = MODEL_MATRIX[3].xyz;
	seed = hash(o.xz * 3.17);
	local_y = world_pos.y;
}

void fragment() {
	vec3 col = COLOR.rgb;
	float emit = 0.0;
	if (world_nrm.y > 0.5) {
		col *= roof_light;
	} else if (world_nrm.y > -0.5) {
		// Seitenfläche: waagrechte Koordinate entlang der Wand
		float u = abs(world_nrm.x) > 0.5 ? world_pos.z : world_pos.x;
		vec2 g = vec2(u, world_pos.y) / window_step;
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float win = step(abs(f.x), window_size.x * 0.5) * step(abs(f.y), window_size.y * 0.5);
		// keine Fenster im Erdgeschoss-Streifen direkt am Boden
		win *= step(0.12, world_pos.y);
		float lit = step(1.0 - window_lit, hash(id + seed * 91.0 + world_nrm.xz * 7.0));
		col = mix(col, window_dark.rgb, win * 0.7);
		emit = win * lit;
		col *= mix(foot_dark, 1.0, smoothstep(0.0, 0.5, local_y));
	}
	ALBEDO = col;
	ROUGHNESS = 0.75;
	SPECULAR = 0.3;
	EMISSION = window_color.rgb * emit * window_energy;
}
