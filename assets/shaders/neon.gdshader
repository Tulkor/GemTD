// Neonröhre: Mitte (zur Kamera zeigend) weiß, Rand in der Röhrenfarbe, überhellt für den Glow.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.31, 0.78, 1.0);
uniform float energy = 3.0;
/// Breite des weißen Kerns (0..1)
uniform float core = 0.15;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float c = smoothstep(1.0 - core, 1.0, facing);
	vec3 col = mix(color.rgb, vec3(1.0), c);
	ALBEDO = col * energy * mix(0.55, 1.0, facing);
}
