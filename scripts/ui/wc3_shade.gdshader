// Abdunklung über dem 3D-Hintergrund des Hauptmenüs: Ränder dunkler (Vignette), links leicht, rechts hinter der Säule stärker.
shader_type canvas_item;

void fragment() {
	vec2 uv = UV;
	float side = mix(0.25, 0.0, smoothstep(0.0, 0.4, uv.x)) + mix(0.0, 0.45, smoothstep(0.4, 1.0, uv.x));
	vec2 d = (uv - vec2(0.35, 0.5)) / vec2(0.8, 0.75);
	float vig = smoothstep(0.55, 1.0, length(d)) * 0.75;
	float a = 1.0 - (1.0 - side) * (1.0 - vig);
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
