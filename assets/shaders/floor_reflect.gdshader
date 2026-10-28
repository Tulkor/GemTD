// Spiegelung auf dem Spielfeld (Board3D, Stärke je Stil "reflect"): eigene Fläche knapp über dem Boden,
// sucht entlang des gespiegelten Blickstrahls im Tiefenbild nach Towern und Gegnern (Screen-Space) und
// zeigt deren Farbe leicht verschwommen. Der Compatibility-Renderer hat keine eingebauten Spiegelungen.
// Sieht nur Deckendes (Tower, Gegner, Steine); Effekte und Durchsichtiges spiegeln sich nicht.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
/// Deckkraft der Spiegelung (0 = aus)
uniform float strength = 0.3;
/// so weit (Einheiten) sucht der Strahl, weiter entfernte Teile blenden aus
uniform float max_dist = 5.0;
/// Dicke, die ein Objekt hinter seiner Vorderseite haben darf (sonst spiegelt sich, was davor steht)
uniform float thickness = 0.6;
/// Unschärfe (Mipmap-Stufe der Bildschirm-Textur)
uniform float blur = 1.5;
uniform vec4 tint : source_color = vec4(1.0);

const int STEPS = 20;

vec2 project(vec3 v, mat4 proj) {
	vec4 c = proj * vec4(v, 1.0);
	return c.xy / c.w * 0.5 + 0.5;
}

// Tiefe hier übergeben: Tiefen- und Bildschirm-Textur gehen im Compatibility-Renderer nur direkt in fragment()
float scene_z(vec2 uv, float d, mat4 inv_proj) {
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
	return v.z / v.w;
}

void fragment() {
	vec3 n = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec3 r = reflect(normalize(VERTEX), n);
	float hit = 0.0;
	vec2 uv = SCREEN_UV;
	float t_prev = 0.0;
	float t_hit = 0.0;
	for (int i = 1; i <= STEPS; i++) {
		// Schritte nah am Boden dichter (Füße der Tower), weiter weg gröber
		float t = max_dist * pow(float(i) / float(STEPS), 1.6);
		vec3 q = VERTEX + r * t;
		vec2 s = project(q, PROJECTION_MATRIX);
		if (s.x < 0.0 || s.y < 0.0 || s.x > 1.0 || s.y > 1.0 || q.z > -0.05) {
			break;
		}
		float behind = scene_z(s, texture(depth_tex, s).r, INV_PROJECTION_MATRIX) - q.z;
		if (behind > 0.0 && behind < thickness) {
			// Treffer: zwischen letztem und diesem Schritt halbieren
			float a = t_prev;
			float b = t;
			for (int k = 0; k < 4; k++) {
				float m = (a + b) * 0.5;
				vec3 qm = VERTEX + r * m;
				vec2 sm = project(qm, PROJECTION_MATRIX);
				if (scene_z(sm, texture(depth_tex, sm).r, INV_PROJECTION_MATRIX) - qm.z > 0.0) {
					b = m;
				} else {
					a = m;
				}
			}
			t_hit = b;
			uv = project(VERTEX + r * b, PROJECTION_MATRIX);
			hit = 1.0;
			break;
		}
		t_prev = t;
	}
	// zum Bildrand und mit dem Abstand ausblenden, flacher Blick spiegelt stärker (Fresnel)
	vec2 edge = smoothstep(vec2(0.0), vec2(0.08), uv) * smoothstep(vec2(0.0), vec2(0.08), 1.0 - uv);
	float fade = edge.x * edge.y * (1.0 - smoothstep(max_dist * 0.5, max_dist, t_hit));
	float fresnel = mix(0.6, 1.0, pow(1.0 - clamp(dot(-normalize(VERTEX), n), 0.0, 1.0), 2.0));
	ALBEDO = textureLod(screen_tex, uv, blur).rgb * tint.rgb;
	ALPHA = hit * fade * fresnel * strength;
}
