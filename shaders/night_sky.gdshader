shader_type sky;

uniform vec4 sky_top_color : source_color;
uniform vec4 sky_mid_color : source_color;
uniform vec4 horizon_color : source_color;
uniform vec4 sun_color : source_color;
uniform vec3 sun_direction;
uniform float sun_strength = 0.0;
uniform vec4 moon_color : source_color;
uniform vec3 moon_direction;
uniform float moon_strength = 0.0;

void sky() {
	vec3 color = mix(horizon_color.rgb, sky_mid_color.rgb, smoothstep(-0.18, 0.30, EYEDIR.y));
	color = mix(color, sky_top_color.rgb, smoothstep(0.08, 0.85, EYEDIR.y));
	float above_horizon = smoothstep(-0.015, 0.015, EYEDIR.y);
	float sun_alignment = dot(EYEDIR, normalize(sun_direction));
	float sun_halo = smoothstep(cos(0.18), 1.0, sun_alignment);
	float sun_disk = smoothstep(cos(0.024), cos(0.019), sun_alignment);
	color = mix(color, sun_color.rgb, sun_halo * sun_halo * sun_strength * 0.42 * above_horizon);
	color = mix(color, sun_color.rgb, sun_disk * sun_strength * above_horizon);
	float moon_alignment = dot(EYEDIR, normalize(moon_direction));
	float moon_halo = smoothstep(cos(0.10472), 1.0, moon_alignment);
	float moon_disk = smoothstep(cos(0.017453), cos(0.013963), moon_alignment);
	color = mix(color, moon_color.rgb, moon_halo * moon_halo * moon_strength * 0.5 * above_horizon);
	color = mix(color, moon_color.rgb, moon_disk * clamp(moon_strength * 2.0, 0.0, 1.0) * above_horizon);
	COLOR = color;
}
