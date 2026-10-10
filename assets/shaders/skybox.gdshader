// Skybox aus sechs Bildern (Sternenhimmel), als Cubemap übergeben,
// dazu ein violetter Schimmer am Horizont.
shader_type sky;

uniform samplerCube cube : filter_linear;
uniform float brightness = 0.7;
uniform vec4 horizon : source_color = vec4(0.32, 0.12, 0.62, 1.0);
uniform float horizon_strength = 0.55;

void sky() {
	vec3 stars = texture(cube, EYEDIR).rgb * brightness;
	float h = exp(-abs(EYEDIR.y) * 5.0);
	COLOR = stars + horizon.rgb * h * horizon_strength;
}
