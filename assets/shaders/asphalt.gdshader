shader_type spatial;
// Asphalt der Straßen zwischen den Häusern (Randgruppen TD): dunkles Grau mit feinem Korn, Flicken und
// leichten Flecken, alles in Weltkoordinaten, damit aneinanderliegende Flächen nahtlos ineinander übergehen.

uniform vec3 base_color : source_color = vec3(0.11, 0.11, 0.12);

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = world_xz;
	float grain = hash(floor(p * 60.0)) * 0.08;
	float patches = smoothstep(0.55, 0.6, noise(p * 0.35 + vec2(5.0, 2.0))) * 0.05;
	float stains = noise(p * 1.7) * 0.06;
	ALBEDO = base_color * (0.9 + grain + stains) - patches;
	ROUGHNESS = 0.92;
}
