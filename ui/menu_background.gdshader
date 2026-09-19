shader_type canvas_item;

// Cluck County at last light: the pit's own palette, one stop below the round.
//
// The 3D farm is a bright toy world at noon, and the shell's menu labels are
// authored light-on-dark, so the menu cannot simply be the pit. It is the same
// fairground instead — bunting, mown stripes, the fence along the far edge, the
// pit's sky and a lamp over the goal — painted at the value the shared screens
// need. Peak brightness is kept inside the studio backdrop's own budget.
//
// Every moving term is multiplied by `speed`, so the reduced-motion switch in
// ui/components/background.gd freezes the picture without changing it.

uniform vec4 top_color : source_color = vec4(0.086, 0.141, 0.122, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.027, 0.051, 0.039, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.831, 0.361, 1.0);
// Set from ui/components/background.gd so the lamps stay round.
uniform vec2 aspect = vec2(1.0, 1.0);
uniform float speed : hint_range(0.0, 1.0) = 0.07;

// Read straight off the pit: sky dome, barn walls and the two coop colours.
uniform vec4 sky_color : source_color = vec4(0.310, 0.765, 0.969, 1.0);
uniform vec4 cream_color : source_color = vec4(1.0, 0.973, 0.906, 1.0);
uniform vec4 red_coop : source_color = vec4(1.0, 0.420, 0.341, 1.0);
uniform vec4 blue_coop : source_color = vec4(0.302, 0.639, 1.0, 1.0);
uniform float horizon : hint_range(0.3, 0.9) = 0.62;

float hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

// One bunting flag: the cord's height at this column, and the pennant under it.
float pennant(vec2 uv, float cord_y, float count, float drop) {
	float cell = uv.x * count;
	float f = fract(cell) - 0.5;
	float edge = cord_y + drop * (1.0 - abs(f) * 2.0);
	return step(cord_y, uv.y) * step(uv.y, edge);
}

void fragment() {
	vec2 uv = UV;
	vec2 p = (uv - vec2(0.5)) * aspect;
	float t = TIME * speed;

	// Turf shadow overhead, churned dirt at the foot of the frame.
	vec3 col = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, uv.y));

	// --- Sky -------------------------------------------------------------
	// The pit's blue, drained to the value the shell's labels can sit on.
	float sky = smoothstep(horizon, horizon - 0.58, uv.y);
	col = mix(col, mix(col, sky_color.rgb, 0.17), sky);

	// Fat toy clouds. Each wraps well outside the frame, so there is no seam.
	float clouds = 0.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 at = vec2(
			fract(0.16 + fi * 0.37 + t * (0.030 + fi * 0.008)) * 1.5 - 0.25,
			0.13 + fi * 0.075
		);
		vec2 d = (uv - at) * vec2(1.0, 3.6);
		clouds += smoothstep(0.155, 0.02, length(d));
	}
	col += cream_color.rgb * clouds * sky * 0.055;

	// --- Fairground bunting ----------------------------------------------
	// scenery.gd strings the same garland over the pit: two coop colours and
	// a dirt-gold flag every third pennant.
	// The garland hangs clear of the title's cap height: the cord sits at most
	// at 0.034 and the pennants are 0.030 deep, so the tips stop above the
	// 0.069 where the shared menu's fixed-colour heading starts, and the cord
	// itself keeps air above it rather than running off the frame edge.
	float sway = sin(t * 1.7) * 0.006;
	float cord_y = 0.020 + sin(uv.x * PI) * 0.014 + sin(uv.x * 7.0 + t * 2.3) * 0.002;
	col += cream_color.rgb * smoothstep(0.0034, 0.0, abs(uv.y - cord_y)) * 0.42;

	float count = 21.0;
	float flag = pennant(vec2(uv.x + sway, uv.y), cord_y, count, 0.030);
	float slot = mod(floor((uv.x + sway) * count), 3.0);
	vec3 flag_color = slot < 1.0 ? red_coop.rgb
		: (slot < 2.0 ? blue_coop.rgb : glow_color.rgb);
	// Replace rather than tint: added over this backdrop the coop colours went
	// olive, so the pennants take the cloth's own hue and keep a lit top edge.
	col = mix(col, flag_color * 0.60, flag * 0.88);
	col += cream_color.rgb * flag * smoothstep(0.010, 0.0, uv.y - cord_y) * 0.16;

	// --- The far fence and the mown field ---------------------------------
	// Soft and low-contrast on purpose: a crisp full-width rail read as a
	// rendering seam behind the button column rather than as distance.
	float below = clamp((uv.y - horizon) / max(1.0 - horizon, 0.001), 0.0, 1.0);
	float rail = smoothstep(0.011, 0.0, abs(uv.y - horizon + 0.012));
	float bay = uv.x * aspect.x * 26.0;
	float post_h = 0.013 + hash(vec2(floor(bay), 3.0)) * 0.010;
	float posts = step(0.66, fract(bay))
		* smoothstep(post_h, 0.0, abs(uv.y - horizon + 0.016));
	col += cream_color.rgb * (rail * 0.032 + posts * 0.030);

	// Stripes converge toward the fence, so the field reads as ground rather
	// than as wallpaper — the same distance cue the pit's cut grass gives.
	float lane = (uv.x - 0.5) * aspect.x / max(below, 0.05);
	float mown = step(0.5, fract(lane * 2.6)) * smoothstep(0.0, 0.25, below);
	col += vec3(0.055, 0.11, 0.045) * mown * 0.10;

	// --- Lamps over the goal lines ----------------------------------------
	vec2 lamp = vec2(0.74 + sin(t * 0.9) * 0.02, horizon - 0.075);
	col += glow_color.rgb * exp(-length((uv - lamp) * aspect) * 4.6) * 0.155;
	vec2 far_lamp = vec2(0.19, horizon + 0.14);
	col += glow_color.rgb * exp(-length((uv - far_lamp) * aspect) * 7.0) * 0.055;

	// --- Dust hanging over the pit ----------------------------------------
	vec2 drift = vec2(uv.x * 9.0 + t * 0.35, uv.y * 9.0 - t * 0.22);
	vec2 cell = floor(drift);
	float mote = smoothstep(0.34, 0.0, length(fract(drift) - 0.5)) * step(0.93, hash(cell));
	col += glow_color.rgb * mote * (0.10 + 0.06 * sin(t * 5.0 + hash(cell) * 12.0))
		* smoothstep(0.15, 0.55, uv.y);

	col *= clamp(1.0 - dot(p, p) * 0.34, 0.35, 1.0);

	float grain = fract(sin(dot(uv * vec2(1024.0, 768.0), vec2(12.9898, 78.233))) * 43758.5453);
	col += (grain - 0.5) * 0.012;

	COLOR = vec4(col, 1.0);
}
