// Shared helpers for the photo-textured world shaders (CC0 ambientCG / Poly Haven sets).

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i), b = hash(i + vec2(1, 0)), c = hash(i + vec2(0, 1)), d = hash(i + vec2(1, 1));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(vec2 p) { return noise(p) * 0.5 + noise(p * 2.1) * 0.25 + noise(p * 4.3) * 0.125 + noise(p * 9.1) * 0.0625; }

// Two scales blended to hide tiling; `v` is a slow noise value in 0..1
vec3 tex2(sampler2D t, vec2 uv, float v) {
	vec3 a = texture(t, uv).rgb;
	vec3 b = texture(t, uv * 0.31 + vec2(0.37, 0.61)).rgb;
	return mix(a, b, 0.25 + 0.35 * v);
}
vec3 nrm2(sampler2D t, vec2 uv, float v) {
	vec3 a = texture(t, uv).rgb;
	vec3 b = texture(t, uv * 0.31 + vec2(0.37, 0.61)).rgb;
	return mix(a, b, 0.25 + 0.35 * v);
}
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
