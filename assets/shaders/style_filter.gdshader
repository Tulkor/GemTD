// Stil-Filter je Modus (StyleFilter, Schalter „Stil-Filter“ in den Einstellungen): liest das fertige 3D-Bild
// (nach Glow und Tonemapping) und färbt es nach. Liegt auf CanvasLayer -1, die Oberfläche bleibt unberührt.
// Ein Durchgang mit höchstens 7 Texturzugriffen, Teile mit Stärke 0 überspringt der Shader.
shader_type canvas_item;

#include "res://assets/shaders/style_grade.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
/// Kanten nachschärfen (Unschärfemaske über 4 Nachbarn)
uniform float sharpen = 0.0;
/// Farbsäume zum Rand hin in Pixeln (Rot nach außen, Blau nach innen)
uniform float chroma = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 base = texture(screen, uv).rgb;
	vec3 c = base;
	if (chroma > 0.0) {
		vec2 dir = (uv - 0.5) * chroma * px * 2.0;
		c.r = texture(screen, uv + dir).r;
		c.b = texture(screen, uv - dir).b;
	}
	if (sharpen > 0.0) {
		vec3 n = texture(screen, uv + vec2(px.x, 0.0)).rgb + texture(screen, uv - vec2(px.x, 0.0)).rgb
			+ texture(screen, uv + vec2(0.0, px.y)).rgb + texture(screen, uv - vec2(0.0, px.y)).rgb;
		c += (c - n * 0.25) * sharpen;
	}
	c = grade_screen(grade_color(c), uv, FRAGCOORD.xy, px.y / px.x, TIME);
	COLOR = vec4(mix(base, c, strength), 1.0);
}
