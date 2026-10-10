// Edelstein-Material für Tower: leicht durchsichtig, an den Kanten dichter (Fresnel),
// mit innerem Leuchten und scharfem Glanzlicht.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(1.0);
/// Deckkraft in der Mitte der Flächen (zum Rand hin wird es dichter).
uniform float opacity = 0.38;
uniform float glow = 0.3;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 2.5);
	// Facetten: Flächen, die zur Kamera zeigen, wirken wie Blick ins Innere (dunkler, satter)
	vec3 deep = color.rgb * color.rgb;
	ALBEDO = mix(deep, color.rgb, 0.4 + 0.6 * fresnel);
	ALPHA = clamp(opacity + fresnel * 0.45, 0.0, 1.0);
	METALLIC = 0.0;
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	EMISSION = color.rgb * (glow + fresnel * 0.5);
	RIM = 0.4;
	RIM_TINT = 0.6;
}
