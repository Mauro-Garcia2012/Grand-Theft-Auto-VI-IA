// Vice City sky: gradient (day / sunset / night), sun & moon discs, stars, animated fbm clouds.
shader_type sky;
render_mode use_debanding;

uniform vec3 top_color : source_color = vec3(0.18, 0.42, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.62, 0.78, 0.92);
uniform vec3 ground_color : source_color = vec3(0.3, 0.35, 0.4);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_size = 0.9997;
uniform float night = 0.0;
uniform float cloud_cover = 0.35;
uniform float cloud_dark = 0.0;
uniform vec3 moon_dir = vec3(0.3, 0.6, -0.7);
// animation clock set by sky_cycle.gd instead of TIME: phones keep it still, so the sky (and the
// lighting cubemap made from it) only needs to be redrawn when it really changes
uniform float sky_time = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i), b = hash(i + vec2(1, 0)), c = hash(i + vec2(0, 1)), d = hash(i + vec2(1, 1));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		float t = pow(clamp(h, 0.0, 1.0), 0.45);
		col = mix(horizon_color, top_color, t);
	} else {
		col = mix(horizon_color, ground_color, clamp(-h * 4.0, 0.0, 1.0));
	}
	// sun
	vec3 sd = LIGHT0_DIRECTION;
	float sdot = dot(d, sd);
	if (LIGHT0_ENABLED) {
		float disc = smoothstep(sun_size, sun_size + 0.0002, sdot);
		float glow = pow(max(sdot, 0.0), 180.0) * 0.6 + pow(max(sdot, 0.0), 12.0) * 0.18;
		col += sun_color * (disc * 18.0 + glow) * LIGHT0_ENERGY;
	}
	// stars & moon
	if (night > 0.01 && h > 0.0) {
		vec3 sp = floor(d * 380.0);
		float s = step(0.9965, hash3(sp));
		float tw = 0.6 + 0.4 * sin(sky_time * 3.0 + hash3(sp) * 50.0);
		col += vec3(s * tw) * night * smoothstep(0.0, 0.25, h) * (1.0 - cloud_cover);
		float md = dot(d, normalize(moon_dir));
		col += vec3(0.85, 0.88, 1.0) * smoothstep(0.9993, 0.9996, md) * night * 3.0;
		col += vec3(0.4, 0.45, 0.7) * pow(max(md, 0.0), 60.0) * night * 0.4;
	}
	// clouds on a virtual plane
	if (h > 0.01) {
		vec2 uv = d.xz / (h + 0.08) * 1.4;
		uv += vec2(sky_time * 0.006, sky_time * 0.003);
		float n = fbm(uv * 1.2);
		float c = smoothstep(1.0 - cloud_cover - 0.25, 1.0 - cloud_cover + 0.25, n);
		c *= smoothstep(0.01, 0.2, h);
		vec3 lit = mix(vec3(1.0), horizon_color * 1.1 + sun_color * 0.25, 0.35);
		lit = mix(lit, vec3(0.35, 0.36, 0.4), cloud_dark);
		lit = mix(lit, vec3(0.08, 0.07, 0.12), night * 0.85);
		float shade = fbm(uv * 2.4 + 3.0);
		vec3 ccol = lit * (0.75 + 0.35 * shade);
		// sunset rim
		ccol += sun_color * pow(max(sdot, 0.0), 8.0) * 0.5 * (1.0 - night);
		col = mix(col, ccol, c * 0.92);
	}
	COLOR = col;
}
