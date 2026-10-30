// Gras- und Erdfleck unter Bäumen (Randgruppen TD, Lukas 2026-10-29): runde Scheibe mit unregelmäßigem,
// weichem Rand, Gras und Erde in Weltkoordinaten gemischt, damit benachbarte Flecken nahtlos ineinanderlaufen.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float grass_tile = 1.5;
uniform float dirt_tile = 2.2;
uniform float brightness = 0.6;
uniform float saturation = 0.75;
/// Anteil Erde (0 = nur Gras)
uniform float dirt_share = 0.4;

varying vec3 world;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 u = fract(p);
	u = u * u * (3.0 - 2.0 * u);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz;
	float n = noise(p * 2.3) * 0.65 + noise(p * 7.0) * 0.35;
	vec3 g = texture(grass, p / grass_tile).rgb;
	vec3 d = texture(dirt, p / dirt_tile).rgb;
	float dm = smoothstep(0.5 - dirt_share * 0.5, 0.75 - dirt_share * 0.5, 1.0 - n);
	vec3 c = mix(g, d, dm) * brightness;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(vec3(l), c, saturation);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	float r = length(UV - 0.5) * 2.0;
	ALPHA = 1.0 - smoothstep(0.55 + n * 0.25, 1.0, r + (n - 0.5) * 0.3);
}
