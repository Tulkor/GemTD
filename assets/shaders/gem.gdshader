// Edelstein-Material für Tower: leicht durchsichtig, an den Kanten dichter (Fresnel),
// mit innerem Leuchten, scharfem Glanzlicht und Licht von unten (leuchtender Sockel).
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(1.0);
/// Deckkraft in der Mitte der Flächen (zum Rand hin wird es dichter).
uniform float opacity = 0.62;
uniform float glow = 0.25;
/// Höhe der Sockel-Oberseite (Welt-Y); darüber wird der Stein von unten angestrahlt.
uniform float base_top = 0.14;
uniform float under_light = 0.85;
uniform float under_height = 0.45;
/// 0 = Neon-Look (Blick ins Innere dunkel, Ränder hell); 1 = bei Tageslicht normal vom Licht schattiert
/// wie polierter Stein (eeveTD, Druidenhain), sonst wirkt der Kristall flach.
uniform float daylight = 0.0;

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 2.5);
	// Flächen, die zur Kamera zeigen, wirken wie Blick ins Innere (dunkler, satter)
	vec3 deep = color.rgb * color.rgb;
	ALBEDO = mix(mix(deep, color.rgb, 0.4 + 0.6 * fresnel), color.rgb * 0.85, daylight);
	ALPHA = mix(clamp(opacity + fresnel * 0.45, 0.0, 1.0), 1.0, daylight);
	METALLIC = 0.0;
	ROUGHNESS = mix(0.08, 0.35, daylight);
	SPECULAR = mix(0.9, 0.35, daylight);
	// Licht von unten: stark am Fuß, nach oben abnehmend; nach unten zeigende Flächen extra hell
	float under = 1.0 - smoothstep(base_top, base_top + under_height, world_y);
	float down = max(0.0, -(INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y);
	vec3 lit = mix(color.rgb, vec3(1.0), 0.35);
	EMISSION = color.rgb * (glow + fresnel * 0.5) + lit * under_light * (under * under + down * 0.6 * under);
	RIM = 0.4;
	RIM_TINT = 0.6;
}
