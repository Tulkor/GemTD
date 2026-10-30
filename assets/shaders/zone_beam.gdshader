// Rahmen der Spielerzonen als Lichtstrahlen (Board3D._add_zone): ein heller Streifen am Boden und darüber ein
// Lichtvorhang, der nach oben ausläuft, mit langsam wandernden senkrechten Strahlen. Additiv, ohne Tiefe schreiben.
// intensity setzt Board3D: vor der ersten Welle voll, danach schwach, beim Bauversuch außerhalb kurz hell.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 2.4;
uniform float intensity = 1.0;
/// 0 = Streifen am Boden, 1 = senkrechter Vorhang (UV.y: 0 oben, 1 unten)
uniform float curtain = 0.0;
/// Länge der Seite in Einheiten, damit die Strahlen überall gleich breit sind
uniform float side_len = 10.0;

void fragment() {
	float a;
	if (curtain > 0.5) {
		float up = 1.0 - UV.y;
		float x = UV.x * side_len;
		// einzelne, scharf begrenzte senkrechte Strahlen verschiedener Breite über einem schwachen Schleier,
		// wandern langsam; nach oben laufen sie aus
		float rays = 0.12 + 0.75 * pow(0.5 + 0.5 * sin(x * 2.3 + TIME * 0.6), 8.0)
			+ 0.5 * pow(0.5 + 0.5 * sin(x * 5.9 - TIME * 0.9), 12.0);
		a = pow(1.0 - up, 1.6) * rays * 0.8;
	} else {
		// Streifen: heller Kern in der Mitte
		float d = abs(UV.y - 0.5) * 2.0;
		a = mix(1.0, 0.35, smoothstep(0.2, 1.0, d));
	}
	// der Vorhang verblasst schneller als der Streifen am Boden: schwach sieht man vor allem die Linie
	ALBEDO = color.rgb * energy * a * (curtain > 0.5 ? intensity * intensity : intensity);
}
