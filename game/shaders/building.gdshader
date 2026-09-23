// Procedural facade shader for instanced box buildings (unit cube, origin at bottom center).
// COLOR = base wall color; INSTANCE_CUSTOM = (style/10, seed, accent hue, unused)
// Styles: 0 glass tower, 1 art deco, 2 stucco low-rise, 3 warehouse + murals, 4 condo,
//         5 house, 6 plain, 7 hangar, 8 shipping container
// Window patterns are filtered with screen-space derivatives to avoid moire at distance.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

global uniform float night_factor;

varying vec3 wpos;
varying vec3 wnorm;
varying vec4 params;
varying vec3 base_col;
varying vec3 osize;
varying float base_y;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i), b = hash(i + vec2(1, 0)), c = hash(i + vec2(0, 1)), d = hash(i + vec2(1, 1));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
// anti-aliased 1D band [a, b] inside a repeating cell coordinate f (0..1)
float band(float f, float a, float b, float w) {
	return clamp(smoothstep(a - w, a + w, f) - smoothstep(b - w, b + w, f), 0.0, 1.0);
}
// window mask with fade to its average coverage when cells get smaller than ~2 pixels
float wmask(vec2 f, vec2 fw, vec4 r) {
	vec2 w = fw * 0.75;
	float m = band(f.x, r.x, r.y, w.x) * band(f.y, r.z, r.w, w.y);
	float avg = (r.y - r.x) * (r.w - r.z);
	float fade = smoothstep(0.18, 0.45, max(fw.x, fw.y));
	return mix(m, avg, fade);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	params = INSTANCE_CUSTOM;
	base_col = COLOR.rgb;
	osize = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	base_y = MODEL_MATRIX[3].y;
}

void fragment() {
	int style = int(params.x * 10.0 + 0.5);
	float seed = params.y;
	vec3 accent = hsv2rgb(vec3(params.z, 0.65, 0.95));
	vec3 col = base_col;
	float rough = 0.85;
	float metal = 0.0;
	vec3 emit = vec3(0.0);
	float h = wpos.y - base_y;
	float top = osize.y;
	if (wnorm.y > 0.5) {
		float n = noise(wpos.xz * 0.7) * 0.5 + noise(wpos.xz * 3.1) * 0.25;
		col = vec3(0.42, 0.41, 0.4) * (0.75 + n * 0.5);
		if (style == 5) col = vec3(0.55, 0.28, 0.2) * (0.8 + n * 0.4);
		if (style == 6 || style == 8) col = base_col * (0.8 + n * 0.3);
		// rooftop helipad-ish marking on tall towers
		if (style == 0 && top > 90.0) {
			vec2 c = abs(fract(wpos.xz / 18.0) - 0.5);
			col = mix(col, vec3(0.9, 0.85, 0.2), step(max(c.x, c.y), 0.3) * step(0.25, max(c.x, c.y)));
		}
		rough = 0.95;
	} else if (wnorm.y < -0.5) {
		col = base_col * 0.4;
	} else {
		vec3 tangent = normalize(cross(vec3(0.0, 1.0, 0.0), wnorm));
		float u = dot(wpos, tangent) + seed * 37.0;
		float floor_h = 3.4;
		float bay = 3.2;
		if (style == 0) { floor_h = 3.8; bay = 2.2; }
		if (style == 3 || style == 7) { floor_h = 5.0; bay = 4.0; }
		if (style == 5) { floor_h = 3.0; bay = 3.6; }
		vec2 cell = vec2(u / bay, h / floor_h);
		vec2 fw = fwidth(cell);
		vec2 f = fract(cell);
		vec2 id = floor(cell);
		float far_fade = smoothstep(0.18, 0.45, max(fw.x, fw.y));
		float lit_h = step(0.52, hash(id + vec2(seed * 91.0, dot(wnorm.xz, vec2(3.0, 7.0)))));
		// far away: light up whole blocks of windows so night skylines still sparkle
		float lit_block = step(0.55, hash(floor(cell / vec2(3.0, 2.0)) + seed * 13.0)) * (0.35 + 0.4 * hash(floor(cell / 7.0) + seed));
		float lit = mix(lit_h, lit_block, far_fade);
		float grime = noise(vec2(u * 0.3, h * 0.2)) * 0.12;
		bool ground_floor = id.y < 1.0;
		if (style == 0) {
			float m = wmask(f, fw, vec4(0.07, 0.93, 0.08, 0.93));
			vec3 glass = mix(vec3(0.07, 0.17, 0.24), vec3(0.14, 0.38, 0.46), params.z);
			// subtle vertical gradient reflections
			glass *= 0.85 + 0.3 * noise(vec2(u * 0.05, h * 0.02 + seed));
			col = mix(base_col * 0.55, glass, m);
			rough = mix(0.5, 0.05, m);
			metal = mix(0.3, 0.85, m);
			float office = mix(step(0.35, hash(id.yx + seed)), 0.8, far_fade);
			emit = vec3(1.0, 0.86, 0.62) * lit * office * m * night_factor * 0.9;
			emit += accent * step(top - 1.2, h) * night_factor * 2.0;
		} else if (style == 1) {
			float m = wmask(f, fw, vec4(0.15, 0.85, 0.3, 0.78));
			float ledge = band(f.y, 0.84, 0.92, fw.y) * (1.0 - far_fade * 0.5);
			float bandc = step(top - 1.6, h) * step(h, top - 0.9);
			float fin = band(fract(u / (bay * 3.0)), 0.96, 0.995, fw.x / 3.0);
			col = base_col * (1.0 - grime);
			col = mix(col, col * 0.72, ledge);
			col = mix(col, accent, clamp(bandc + fin * 0.8, 0.0, 1.0));
			col = mix(col, vec3(0.16, 0.24, 0.3), m * (1.0 - bandc));
			rough = mix(0.8, 0.1, m);
			metal = m * 0.4;
			emit = vec3(1.0, 0.8, 0.55) * lit * m * night_factor * 0.8;
			emit += accent * clamp(bandc + fin, 0.0, 1.0) * night_factor * 3.0;
			if (ground_floor) {
				float shop = wmask(f, fw, vec4(0.08, 0.92, 0.08, 0.7));
				col = mix(col, vec3(0.1, 0.12, 0.13), shop);
				emit += vec3(1.0, 0.75, 0.5) * shop * night_factor * 0.7;
				float awning = band(f.y, 0.72, 0.86, fw.y);
				col = mix(col, accent * 0.9, awning);
			}
		} else if (style == 2 || style == 5) {
			float m = wmask(f, fw, vec4(0.3, 0.7, 0.3, 0.8));
			float shutter = (wmask(f, fw, vec4(0.2, 0.3, 0.3, 0.8)) + wmask(f, fw, vec4(0.7, 0.8, 0.3, 0.8)));
			col = base_col * (1.0 - grime * 1.5);
			if (style == 2) col = mix(col, accent * 0.8, shutter);
			col = mix(col, vec3(0.12, 0.15, 0.18), m);
			rough = mix(0.9, 0.2, m);
			emit = vec3(1.0, 0.8, 0.5) * lit * m * night_factor * 0.8;
			if (ground_floor && style == 2) {
				float shop = wmask(f, fw, vec4(0.05, 0.95, 0.05, 0.72)) * step(0.4, hash(id + seed));
				col = mix(col, vec3(0.08, 0.09, 0.1), shop);
				float sgn = band(f.y, 0.76, 0.92, fw.y) * step(0.5, hash(vec2(id.x, seed)));
				col = mix(col, accent, sgn);
				emit += accent * sgn * night_factor * 2.5;
			}
			if (ground_floor && style == 5) {
				float door = wmask(f, fw, vec4(0.4, 0.6, 0.0, 0.75)) * step(0.8, hash(vec2(id.x, seed)));
				col = mix(col, vec3(0.35, 0.22, 0.14), door);
			}
		} else if (style == 3 || style == 7 || style == 8) {
			// corrugated metal / brick; Stockyard warehouses get graffiti murals
			float rib = mix(sin(u * (style == 8 ? 9.0 : 12.0)) * 0.5 + 0.5, 0.5, far_fade);
			col = base_col * (0.84 + rib * 0.16) * (1.0 - grime);
			if (style != 8) {
				float strip = wmask(f, fw, vec4(0.1, 0.9, 0.62, 0.8)) * step(1.0, id.y);
				col = mix(col, vec3(0.15, 0.17, 0.18), strip);
				emit = vec3(1.0, 0.9, 0.7) * strip * lit * night_factor * 0.5;
			}
			if (style == 3 && step(0.45, hash(vec2(floor(u / 30.0), seed))) > 0.5 && h < 9.0) {
				// graffiti mural: big bold letter-ish blobs with outlines
				vec2 mp = vec2(u, h) * vec2(0.09, 0.14);
				float n1 = noise(mp + seed * 10.0);
				float n2 = noise(mp * 2.0 - seed * 5.0);
				float shape = smoothstep(0.45, 0.5, n1);
				float outline = smoothstep(0.42, 0.45, n1) - shape;
				vec3 bgc = hsv2rgb(vec3(fract(params.z + 0.5), 0.35, 0.9));
				vec3 fill = hsv2rgb(vec3(fract(params.z + floor(n2 * 3.0) * 0.18), 0.85, 0.95));
				vec3 mc = mix(bgc, fill, shape);
				mc = mix(mc, vec3(0.05), clamp(outline, 0.0, 1.0));
				mc = mix(mc, vec3(1.0), step(0.85, n2) * shape * 0.6);
				col = mix(mc, base_col * 0.8, far_fade * 0.3);
				rough = 0.7;
			}
			if (style == 7) {
				float door = band(fract(u / 24.0), 0.1, 0.9, fw.x / 6.0) * step(h, 8.0);
				col = mix(col, col * 0.6, door);
			}
			if (style == 8) {
				// container end frames & logo stripe
				col = mix(col, col * 0.7, band(fract(u / 12.0), 0.0, 0.03, fw.x / 3.0));
			}
		} else if (style == 4) {
			float glass = wmask(f, fw, vec4(0.1, 0.9, 0.05, 0.8));
			float slab = band(f.y, 0.86, 1.0, fw.y);
			float rail = band(f.y, 0.8, 0.86, fw.y);
			col = mix(base_col, vec3(0.12, 0.32, 0.42), glass);
			col = mix(col, vec3(0.95), slab * (1.0 - far_fade * 0.5));
			col = mix(col, vec3(0.6, 0.75, 0.8), rail);
			rough = mix(0.8, 0.05, glass);
			metal = glass * 0.6;
			emit = vec3(1.0, 0.85, 0.6) * lit * glass * night_factor * 0.7;
			emit += accent * step(top - 1.0, h) * night_factor * 1.5;
		} else if (style == 6) {
			col = base_col * (0.9 + grime);
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emit;
}
