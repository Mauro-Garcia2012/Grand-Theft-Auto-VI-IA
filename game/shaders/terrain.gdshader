// Terrain: COLOR.rgb weights -> r: sand, g: grass, b: concrete, a: swamp ; tarmac when all zero
// Photo textures (CC0, ambientCG) with two-scale blending against tiling.
shader_type spatial;
render_mode diffuse_burley, cull_disabled;

#include "res://shaders/pbr_util.gdshaderinc"

global uniform float wetness;
uniform sampler2D splat : filter_linear, repeat_disable;
uniform vec2 map_min = vec2(-2000.0, -1700.0);
uniform vec2 map_size = vec2(3696.0, 4200.0);
uniform sampler2D sand_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D conc_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D conc_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asph_c : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asph_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 w = texture(splat, (wpos.xz - map_min) / map_size);
	float v = fbm(wpos.xz * 0.02);
	float big = fbm(wpos.xz * 0.004);
	vec2 uv = wpos.xz;
	float total = w.r + w.g + w.b + w.a;
	float wt = max(0.0, 1.0 - total);
	vec3 col = vec3(0.0);
	vec3 nm = vec3(0.0);
	if (w.r > 0.01) {
		// light Miami beach sand; darker and wet at the waterline
		vec3 s = tex2(sand_c, uv * 0.25, v) * vec3(1.3, 1.14, 0.88);
		s *= 0.93 + big * 0.14;
		s = mix(s * 0.62, s, smoothstep(0.1, 0.7, wpos.y));
		col += s * w.r;
		nm += nrm2(sand_n, uv * 0.25, v) * w.r;
	}
	if (w.g > 0.01) {
		vec3 g = tex2(grass_c, uv * 0.3, v) * vec3(0.95, 1.0, 0.85);
		g *= mix(vec3(1.05, 1.0, 0.8), vec3(0.85, 1.0, 1.0), big);
		col += g * w.g;
		nm += nrm2(grass_n, uv * 0.3, v) * w.g;
	}
	if (w.b > 0.01) {
		col += tex2(conc_c, uv * 0.18, v) * vec3(0.66, 0.64, 0.6) * w.b;
		nm += nrm2(conc_n, uv * 0.18, v) * w.b;
	}
	if (w.a > 0.01) {
		vec3 m = mix(tex2(mud_c, uv * 0.3, v), tex2(grass_c, uv * 0.25, v) * 0.8, smoothstep(0.35, 0.65, big));
		col += m * w.a;
		nm += nrm2(mud_n, uv * 0.3, v) * w.a;
	}
	if (wt > 0.01) {
		col += tex2(asph_c, uv * 0.2, v) * 0.55 * wt;
		nm += nrm2(asph_n, uv * 0.2, v) * wt;
	}
	float wsum = max(total + wt, 0.001);
	col /= wsum;
	nm /= wsum;
	// underwater darkening
	col *= mix(0.55, 1.0, smoothstep(-4.0, 0.0, wpos.y));
	float wet = clamp(wetness, 0.0, 1.0);
	TANGENT = normalize((VIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	BINORMAL = normalize((VIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 1.0;
	ALBEDO = col * (1.0 - wet * 0.25);
	ROUGHNESS = mix(0.95, 0.4, wet * (1.0 - w.g));
}
