// Skybox aus sechs Bildern (Sternenhimmel), als Cubemap übergeben.
shader_type sky;

uniform samplerCube cube : filter_linear;
uniform float brightness = 0.8;

void sky() {
	COLOR = texture(cube, EYEDIR).rgb * brightness;
}
