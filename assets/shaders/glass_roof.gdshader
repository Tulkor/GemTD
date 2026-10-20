// Glasdach über den Gängen von Shopping Maul, Vorbild Grand Palais: hohes Tonnengewölbe aus Glas in
// kleinen Feldern, Eisenrahmen in Grün (Hauptbögen, Sprossen), Messingband am Rand.
// Maske (R = Gang, nearest) und Gewölbe (G = Höhe 0..1, linear) liegen in "mask", ein Pixel pro Feld.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

uniform sampler2D mask : filter_nearest, repeat_disable;
uniform sampler2D vault : filter_linear, repeat_disable;
uniform vec2 cells = vec2(1.0);
uniform float cell = 0.5;
uniform float rise = 0.7;
uniform vec4 glass_color : source_color = vec4(0.55, 0.78, 0.78, 1.0);
uniform float glass_alpha = 0.07;
uniform vec4 iron : source_color = vec4(0.3, 0.46, 0.4, 1.0);
uniform vec4 brass : source_color = vec4(0.85, 0.72, 0.48, 1.0);
/// Abstand der Hauptbögen und der Sprossen (Glasfelder) in Einheiten
uniform float rib_step = 1.5;
uniform float pane_step = 0.22;

varying vec3 world_pos;
varying float height01;

float vault_at(vec2 xz) {
	return texture(vault, xz / (cells * cell)).g;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = vault_at(wp.xz);
	VERTEX.y += h * rise;
	float e = cell;
	float hx = (vault_at(wp.xz + vec2(e, 0.0)) - vault_at(wp.xz - vec2(e, 0.0))) * rise / (2.0 * e);
	float hz = (vault_at(wp.xz + vec2(0.0, e)) - vault_at(wp.xz - vec2(0.0, e))) * rise / (2.0 * e);
	NORMAL = normalize(vec3(-hx, 1.0, -hz));
	world_pos = wp;
	height01 = h;
}

float line(float v, float step_, float width) {
	float d = abs(fract(v / step_ + 0.5) - 0.5) * step_;
	float aa = fwidth(v) * 0.75;
	return 1.0 - smoothstep(width - aa, width + aa, d);
}

void fragment() {
	ivec2 c = ivec2(floor(world_pos.xz / cell));
	if (c.x < 0 || c.y < 0 || c.x >= int(cells.x) || c.y >= int(cells.y) || texelFetch(mask, c, 0).r < 0.5) {
		discard;
	}
	float rib = max(line(world_pos.x, rib_step, 0.04), line(world_pos.z, rib_step, 0.04));
	float pane = max(line(world_pos.x, pane_step, 0.007), line(world_pos.z, pane_step, 0.007));
	// First: Längsträger oben auf dem Gewölbe
	float ridge = smoothstep(0.985, 0.995, height01);
	float edge = 1.0 - smoothstep(0.06, 0.12, height01);
	float frame = max(max(rib, ridge), pane * 0.55);
	float metal = max(frame, edge);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(mix(glass_color.rgb, iron.rgb, frame), brass.rgb, edge);
	ALPHA = clamp(glass_alpha + fres * 0.18 + metal * 0.85, 0.0, 1.0);
	METALLIC = metal * 0.8;
	ROUGHNESS = mix(0.05, 0.35, metal);
	SPECULAR = 0.8;
}
