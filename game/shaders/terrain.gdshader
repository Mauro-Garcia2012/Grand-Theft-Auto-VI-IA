// Terrain: COLOR.rgb weights -> r: sand, g: grass, b: concrete, a: swamp ; tarmac when all zero
shader_type spatial;
render_mode diffuse_burley, cull_disabled;

global uniform float wetness;
uniform sampler2D splat : filter_linear, repeat_disable;
uniform vec2 map_min = vec2(-2000.0, -1700.0);
uniform vec2 map_size = vec2(3696.0, 4200.0);
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i), b = hash(i + vec2(1, 0)), c = hash(i + vec2(0, 1)), d = hash(i + vec2(1, 1));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(vec2 p) { return noise(p) * 0.5 + noise(p * 2.1) * 0.25 + noise(p * 4.3) * 0.125 + noise(p * 9.1) * 0.0625; }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 w = texture(splat, (wpos.xz - map_min) / map_size);
	float n = fbm(wpos.xz * 0.25);
	float n2 = fbm(wpos.xz * 2.0);
	vec3 sand = mix(vec3(0.86, 0.77, 0.58), vec3(0.78, 0.68, 0.5), n) * (0.92 + n2 * 0.12);
	// wet sand near the water line
	sand = mix(sand * 0.72, sand, smoothstep(0.1, 0.6, wpos.y));
	vec3 grass = mix(vec3(0.22, 0.42, 0.12), vec3(0.36, 0.5, 0.18), n) * (0.85 + n2 * 0.25);
	vec3 concrete = mix(vec3(0.6, 0.59, 0.56), vec3(0.5, 0.5, 0.48), n) * (0.9 + n2 * 0.15);
	vec3 swamp = mix(vec3(0.25, 0.3, 0.14), vec3(0.4, 0.38, 0.2), n) * (0.8 + n2 * 0.3);
	vec3 tarmac = vec3(0.26, 0.27, 0.27) * (0.85 + n2 * 0.2);
	float total = w.r + w.g + w.b + w.a;
	vec3 col = tarmac * max(0.0, 1.0 - total) + sand * w.r + grass * w.g + concrete * w.b + swamp * w.a;
	// underwater darkening
	col *= mix(0.55, 1.0, smoothstep(-4.0, 0.0, wpos.y));
	float wet = clamp(wetness, 0.0, 1.0);
	ALBEDO = col * (1.0 - wet * 0.25);
	ROUGHNESS = mix(0.95, 0.4, wet * (1.0 - w.g));
}
