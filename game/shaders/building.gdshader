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

#include "res://shaders/pbr_util.gdshaderinc"

uniform sampler2D plaster_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaster_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cwall_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cwall_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bricks_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bricks_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D steel_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D steel_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roof_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roof_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

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

// Fake room behind a window ("interior mapping"): ray-box intersection in cell space.
// f: position inside the facade cell (0..1), V: view ray (world), T/N: facade tangent/normal.
vec3 interior(vec2 f, vec3 V, vec3 T, vec3 N, float bay, float fh, float rid, bool office) {
	vec3 d = vec3(dot(V, T) / bay, V.y / fh, dot(V, -N) / 4.0);
	d.z = max(d.z, 0.0005);
	vec3 p = vec3(f, 0.0);
	vec3 tt = vec3(d.x > 0.0 ? (1.0 - p.x) / d.x : -p.x / min(d.x, -0.0001),
		d.y > 0.0 ? (1.0 - p.y) / d.y : -p.y / min(d.y, -0.0001), (1.0 - p.z) / d.z);
	float t = min(min(tt.x, tt.y), tt.z);
	vec3 h = p + d * t;
	vec3 paint = mix(vec3(0.78, 0.72, 0.62), vec3(0.62, 0.66, 0.7), hash(vec2(rid, 1.7)));
	if (office) paint = vec3(0.7, 0.72, 0.74);
	vec3 c;
	if (t == tt.z) {
		c = paint;
		// furniture silhouette / desk against the back wall
		float fx = abs(h.x - 0.5 - (hash(vec2(rid, 3.3)) - 0.5) * 0.3);
		c = mix(c, c * 0.35, step(fx, 0.28) * step(h.y, 0.3 + 0.1 * hash(vec2(rid, 5.1))));
		// picture frame
		c = mix(c, vec3(0.25, 0.2, 0.15), step(abs(h.x - 0.35), 0.08) * step(abs(h.y - 0.62), 0.07) * step(0.5, hash(vec2(rid, 8.2))));
	} else if (t == tt.y) {
		if (d.y < 0.0) {
			c = office ? vec3(0.32, 0.33, 0.35) : vec3(0.42, 0.3, 0.2);   // floor
		} else {
			c = vec3(0.86, 0.86, 0.84);                                    // ceiling
			if (office) c = mix(c, vec3(1.4, 1.35, 1.2), step(0.7, fract(h.z * 4.0)) * step(0.3, fract(h.x * 3.0)));
		}
	} else {
		c = paint * 0.82;
	}
	// darker towards the back of the room
	return c * mix(1.0, 0.55, h.z);
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
	vec3 nmap = vec3(0.5, 0.5, 1.0);
	vec3 tng = vec3(1.0, 0.0, 0.0);
	vec3 bin = vec3(0.0, 0.0, -1.0);
	if (wnorm.y > 0.5) {
		float n = noise(wpos.xz * 0.7) * 0.5 + noise(wpos.xz * 3.1) * 0.25;
		vec3 rt = tex2(roof_c, wpos.xz * 0.2, n);
		nmap = nrm2(roof_n, wpos.xz * 0.2, n);
		col = rt * 0.8 * (0.8 + n * 0.3);
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
		tng = tangent;
		bin = vec3(0.0, 1.0, 0.0);
		vec3 V = normalize(wpos - CAMERA_POSITION_WORLD);
		// photo texture detail for the wall material (tinted by the palette colour)
		vec2 tuv = vec2(u, -h) * 0.45;
		float tv = noise(vec2(u, h) * 0.05 + seed * 7.0);
		vec3 wall_t;
		if (style == 3 && hash(vec2(seed, 3.1)) > 0.5) {
			wall_t = tex2(bricks_c, tuv * 0.8, tv) * 1.6;
			nmap = nrm2(bricks_n, tuv * 0.8, tv);
		} else if (style == 3 || style == 6) {
			wall_t = tex2(cwall_c, tuv * 0.5, tv) * 1.7;
			nmap = nrm2(cwall_n, tuv * 0.5, tv);
		} else if (style == 7 || style == 8) {
			wall_t = tex2(steel_c, tuv * 0.5, tv) * 1.6;
			nmap = nrm2(steel_n, tuv * 0.5, tv);
		} else {
			wall_t = tex2(plaster_c, tuv, tv) * 1.2;
			nmap = nrm2(plaster_n, tuv, tv);
		}
		// soften the pastel palette a little and apply the texture
		vec3 soft = mix(vec3(lum(base_col)), base_col, 0.82);
		vec3 wall = soft * wall_t;
		// rain streaks / dirt towards the ground and below ledges
		wall *= 1.0 - (1.0 - smoothstep(0.0, 2.5, h)) * 0.18;
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
			// facade variants: full curtain wall / spandrel bands / vertical fins
			float variant = hash(vec2(seed, 7.7));
			vec4 wr = vec4(0.07, 0.93, 0.08, 0.93);
			if (variant > 0.66) wr = vec4(0.05, 0.95, 0.3, 0.95);
			else if (variant > 0.33) wr = vec4(0.18, 0.82, 0.06, 0.94);
			float m = wmask(f, fw, wr);
			// glass tints: blue-green, silver, bronze, dark grey, green
			float gsel = hash(vec2(seed, 2.9));
			vec3 glass = mix(vec3(0.07, 0.17, 0.24), vec3(0.14, 0.38, 0.46), params.z);
			if (gsel > 0.8) glass = vec3(0.28, 0.3, 0.32);
			else if (gsel > 0.6) glass = vec3(0.2, 0.15, 0.1);
			else if (gsel > 0.4) glass = vec3(0.07, 0.08, 0.09);
			else if (gsel > 0.25) glass = vec3(0.1, 0.2, 0.16);
			// subtle vertical gradient reflections
			glass *= 0.85 + 0.3 * noise(vec2(u * 0.05, h * 0.02 + seed));
			vec3 room = interior(f, V, tangent, wnorm, bay, floor_h, hash(id + seed), true);
			glass = mix(mix(glass, room * 0.45, 0.45), glass, far_fade);
			col = mix(wall * 0.55, glass, m);
			rough = mix(0.5, 0.05, m);
			metal = mix(0.3, 0.6, m);
			float office = mix(step(0.35, hash(id.yx + seed)), 0.8, far_fade);
			emit = mix(room * 1.1, vec3(1.0, 0.86, 0.62), far_fade) * lit * office * m * night_factor * 0.9;
			emit += accent * step(top - 1.2, h) * night_factor * 2.0;
		} else if (style == 1) {
			float m = wmask(f, fw, vec4(0.15, 0.85, 0.3, 0.78));
			float ledge = band(f.y, 0.84, 0.92, fw.y) * (1.0 - far_fade * 0.5);
			float bandc = step(top - 1.6, h) * step(h, top - 0.9);
			float fin = band(fract(u / (bay * 3.0)), 0.96, 0.995, fw.x / 3.0);
			col = wall * (1.0 - grime);
			col = mix(col, col * 0.72, ledge);
			col = mix(col, accent, clamp(bandc + fin * 0.8, 0.0, 1.0));
			vec3 room = interior(f, V, tangent, wnorm, bay, floor_h, hash(id + seed), false);
			vec3 gl = mix(room * 0.5, vec3(0.16, 0.24, 0.3), far_fade);
			col = mix(col, gl, m * (1.0 - bandc));
			rough = mix(0.8, 0.06, m);
			metal = m * 0.2;
			emit = mix(room * 1.2, vec3(1.0, 0.8, 0.55), far_fade) * lit * m * night_factor * 0.8;
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
			float frame = clamp(wmask(f, fw, vec4(0.27, 0.73, 0.26, 0.84)) - m, 0.0, 1.0);
			col = wall * (1.0 - grime * 1.5);
			if (style == 2) col = mix(col, mix(vec3(lum(accent)), accent, 0.6) * 0.75, shutter);
			col = mix(col, vec3(0.86, 0.85, 0.82), frame * (1.0 - far_fade));
			// glass: dark interior, some curtains, reflective
			vec3 room = interior(f, V, tangent, wnorm, bay, floor_h, hash(id + seed), false);
			vec3 gl = mix(room * 0.5, vec3(0.08, 0.1, 0.11), far_fade);
			// some windows with light curtains
			gl = mix(gl, vec3(0.62, 0.58, 0.5), step(0.75, hash(id + seed * 3.0)) * 0.7);
			col = mix(col, gl, m);
			rough = mix(0.9, 0.06, m);
			metal = m * 0.15;
			emit = mix(room * 1.2, vec3(1.0, 0.8, 0.5), far_fade) * lit * m * night_factor * 0.8;
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
			col = wall * (0.9 + rib * 0.1) * (1.0 - grime);
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
			vec3 room = interior(f, V, tangent, wnorm, bay, floor_h, hash(id + seed), false);
			col = mix(wall, mix(mix(vec3(0.1, 0.22, 0.28), room * 0.5, 0.6), vec3(0.1, 0.22, 0.28), far_fade), glass);
			col = mix(col, vec3(0.95), slab * (1.0 - far_fade * 0.5));
			col = mix(col, vec3(0.6, 0.75, 0.8), rail);
			rough = mix(0.8, 0.05, glass);
			metal = glass * 0.6;
			emit = vec3(1.0, 0.85, 0.6) * lit * glass * night_factor * 0.7;
			emit += accent * step(top - 1.0, h) * night_factor * 1.5;
		} else if (style == 6) {
			col = wall * (0.9 + grime);
		}
	}
	TANGENT = normalize((VIEW_MATRIX * vec4(tng, 0.0)).xyz);
	BINORMAL = normalize((VIEW_MATRIX * vec4(bin, 0.0)).xyz);
	NORMAL_MAP = nmap;
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emit;
}
