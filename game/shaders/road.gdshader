// Asphalt with lane markings. UV.x: 0..1 across the road, UV.y: meters along.
// UV2.x: segment length (m), UV2.y: lanes (2 or 4); COLOR.r = 1 for intersections (no markings)
shader_type spatial;
render_mode diffuse_burley, cull_disabled;

global uniform float night_factor;
global uniform float wetness;

varying vec2 info;
varying float is_cross;
varying vec3 wpos;

#include "res://shaders/pbr_util.gdshaderinc"

uniform sampler2D asph_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asph_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

void vertex() {
	info = UV2;
	is_cross = COLOR.r;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = noise(wpos.xz * 1.3) * 0.5 + noise(wpos.xz * 7.0) * 0.3 + noise(wpos.xz * 0.15) * 0.4;
	float v = fbm(wpos.xz * 0.03);
	vec3 asphalt = tex2(asph_c, wpos.xz * 0.22, v) * 0.5 * (0.85 + noise(wpos.xz * 0.15) * 0.3);
	// darker oil-stained strip in the middle of each lane
	if (is_cross < 0.5) {
		float lane_c = abs(fract(UV.x * info.y) - 0.5);
		asphalt *= 1.0 - smoothstep(0.25, 0.0, lane_c) * 0.12;
	}
	vec3 col = asphalt;
	float paint = 0.0;
	vec3 paint_col = vec3(0.92);
	if (is_cross < 0.5) {
		float x = UV.x;
		float y = UV.y;
		float len = info.x;
		float lanes = info.y;
		// edge lines
		paint += step(x, 0.035) * step(0.02, x) + step(0.965, x) * step(x, 0.98);
		// center line (double yellow on avenues, dashed yellow otherwise)
		float c = abs(x - 0.5);
		if (lanes > 3.0) {
			float dbl = step(0.008, c) * step(c, 0.02);
			paint_col = mix(paint_col, vec3(0.95, 0.75, 0.1), dbl);
			paint += dbl;
			// lane dashes
			float ld = step(abs(abs(x - 0.5) - 0.25), 0.008) * step(fract(y / 9.0), 0.5);
			paint += ld;
		} else {
			float cl = step(c, 0.012) * step(fract(y / 6.0), 0.55);
			paint_col = mix(paint_col, vec3(0.95, 0.75, 0.1), cl);
			paint += cl;
		}
		// crosswalk zebra near the ends
		float endd = min(y, len - y);
		float zebra = step(endd, 3.2) * step(0.6, endd) * step(0.5, fract(x * 8.0)) * step(0.06, x) * step(x, 0.94);
		paint += zebra;
		float stopl = step(endd, 4.0) * step(3.5, endd) * step(0.5, x) * step(x, 0.97);
		paint += stopl;
		paint = clamp(paint, 0.0, 1.0);
		col = mix(col, paint_col * (0.85 + n * 0.1), paint * (0.75 + 0.25 * noise(wpos.xz * 3.0)));
	}
	// cracks / patches
	col *= 1.0 - step(0.8, noise(wpos.xz * 0.35)) * 0.12;
	float wet = clamp(wetness, 0.0, 1.0);
	TANGENT = normalize((VIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	BINORMAL = normalize((VIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
	NORMAL_MAP = mix(nrm2(asph_n, wpos.xz * 0.22, v), vec3(0.5, 0.5, 1.0), paint * 0.6 + wet * 0.5);
	ALBEDO = col * (1.0 - wet * 0.35);
	ROUGHNESS = mix(0.9 - paint * 0.2, 0.15, wet);
	SPECULAR = 0.4 + wet * 0.4;
}
