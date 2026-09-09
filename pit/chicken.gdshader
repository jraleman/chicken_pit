shader_type spatial;
render_mode cull_back, diffuse_burley, specular_disabled;

uniform float flap = 0.0;
uniform float flap_skew = 0.0;
uniform float head_dip = 0.0;
uniform float foot_step = 0.0;
uniform float foot_kick = 0.0;

mat3 turn_x(float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

mat3 turn_z(float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
}

void vertex() {
	float part = UV2.x;
	if (part > 0.5 && part < 2.5) {
		float side = part < 1.5 ? 1.0 : -1.0;
		vec3 hinge = vec3(-0.25, 1.02, side * 0.30);
		mat3 rotation = turn_x(-side * (flap + side * flap_skew));
		VERTEX = hinge + rotation * (VERTEX - hinge);
		NORMAL = rotation * NORMAL;
	} else if (part > 2.5 && part < 3.5) {
		vec3 hinge = vec3(0.20, 1.02, 0.0);
		mat3 rotation = turn_z(head_dip);
		VERTEX = hinge + rotation * (VERTEX - hinge);
		NORMAL = rotation * NORMAL;
	} else if (part > 3.5) {
		float side = part < 4.5 ? 1.0 : -1.0;
		vec3 hip = vec3(-0.08, 0.43, side * 0.22);
		mat3 rotation = turn_z(side * foot_step * foot_kick);
		VERTEX = hip + rotation * (VERTEX - hip);
		NORMAL = rotation * NORMAL;
		VERTEX.x += foot_step * side;
		VERTEX.y += abs(foot_step) * 0.35;
	}
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.92;
}
