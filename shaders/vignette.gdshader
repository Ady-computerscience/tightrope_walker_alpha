shader_type canvas_item;

void fragment() {
	vec2 from_center = (UV - vec2(0.5)) * vec2(1.0, 0.85);
	float edge = smoothstep(0.27, 0.72, length(from_center));
	COLOR = vec4(vec3(0.05, 0.04, 0.09), edge * 0.18);
}
