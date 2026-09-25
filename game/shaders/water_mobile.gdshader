// Phone version of water.gdshader: same colours and waves, but opaque and without the screen /
// depth texture reads (refraction, depth tint, shore foam), which cost a full screen copy per frame.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec3 shallow = vec3(0.13, 0.55, 0.52);
uniform vec3 deep = vec3(0.02, 0.13, 0.2);
global uniform float night_factor;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i), b = hash(i + vec2(1, 0)), c = hash(i + vec2(0, 1)), d = hash(i + vec2(1, 1));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float waves(vec2 p, float t) {
	return noise(p * 0.35 + vec2(t * 0.25, t * 0.1)) * 0.65 + noise(p * 0.9 - vec2(t * 0.35, -t * 0.2)) * 0.35;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;
	VERTEX.y += (sin(wpos.x * 0.08 + t * 1.3) + cos(wpos.z * 0.07 + t * 1.1)) * 0.12;
}

void fragment() {
	float t = TIME;
	float e = 0.15;
	float h0 = waves(wpos.xz, t);
	float hx = waves(wpos.xz + vec2(e, 0.0), t);
	float hz = waves(wpos.xz + vec2(0.0, e), t);
	vec3 nrm = normalize(vec3((h0 - hx) * 2.5, 1.0, (h0 - hz) * 2.5));
	NORMAL = (VIEW_MATRIX * vec4(nrm, 0.0)).xyz;
	vec3 col = mix(shallow, deep, 0.62 + h0 * 0.2);
	col *= mix(1.0, 0.25, night_factor);
	ALBEDO = col;
	ROUGHNESS = 0.03;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
