shader_type sky;

uniform vec4 sky_top_color : source_color;
uniform vec4 horizon_color : source_color;
uniform vec4 moon_color : source_color;
uniform vec3 moon_direction;
uniform float moon_strength = 0.36;
uniform float horizon_height = -0.18;

void sky() {
	float sky_blend = smoothstep(horizon_height, 0.8, EYEDIR.y);
	vec3 color = mix(horizon_color.rgb, sky_top_color.rgb, sky_blend);
	float alignment = dot(EYEDIR, normalize(moon_direction));
	float halo = smoothstep(cos(0.10472), 1.0, alignment);
	float disk = smoothstep(cos(0.017453), cos(0.013963), alignment);
	color = mix(color, moon_color.rgb, halo * halo * moon_strength * 0.5);
	color = mix(color, moon_color.rgb, disk);
	COLOR = color;
}
