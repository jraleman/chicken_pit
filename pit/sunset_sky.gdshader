shader_type spatial;
render_mode unshaded, cull_front, fog_disabled;

uniform vec4 zenith_color : source_color = vec4(0.4, 0.49, 0.65, 1.0);
uniform vec4 horizon_color : source_color = vec4(1.0, 0.82, 0.62, 1.0);
uniform vec3 sun_direction = vec3(0.48, -0.12, -0.7);
varying vec3 sky_ray;

void vertex() {
	sky_ray = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD;
}

void fragment() {
	vec3 direction = normalize(sky_ray);
	float height = smoothstep(-0.55, 0.25, direction.y);
	vec3 paint = mix(horizon_color.rgb, zenith_color.rgb, height);
	float facing_sun = max(dot(direction, normalize(sun_direction)), 0.0);
	float halo = pow(facing_sun, 16.0) * 0.35;
	float disc = pow(facing_sun, 512.0) * 0.35;
	ALBEDO = mix(paint, vec3(1.0, 0.8, 0.5), halo + disc);
}
