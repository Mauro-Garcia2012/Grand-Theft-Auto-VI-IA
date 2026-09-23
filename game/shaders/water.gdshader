// Tropical water: depth-based turquoise->deep blue, animated normals, fresnel, shore foam.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled, depth_draw_always;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec3 shallow = vec3(0.2, 0.78, 0.75);
uniform vec3 deep = vec3(0.02, 0.22, 0.38);
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
	return noise(p * 0.35 + vec2(t * 0.25, t * 0.1)) * 0.6 + noise(p * 0.9 - vec2(t * 0.35, -t * 0.2)) * 0.3 + noise(p * 2.7 + vec2(t * 0.6, t * 0.4)) * 0.1;
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
	float depth_raw = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * ndc;
	world.xyz /= world.w;
	float depth = clamp(wpos.y - world.y, 0.0, 50.0);
	float dfac = 1.0 - exp(-depth * 0.35);
	vec3 col = mix(shallow, deep, dfac);
	// refraction of the bottom in shallow water
	vec2 ruv = SCREEN_UV + nrm.xz * 0.02 * (1.0 - dfac);
	vec3 below = texture(screen_tex, ruv).rgb;
	col = mix(below * shallow * 1.3, col, clamp(dfac * 1.5 + 0.25, 0.0, 1.0));
	float foam = (1.0 - smoothstep(0.0, 0.8, depth)) * step(0.45, noise(wpos.xz * 3.0 + t));
	col = mix(col, vec3(0.95), foam * 0.8);
	col *= mix(1.0, 0.25, night_factor);
	ALBEDO = col;
	ALPHA = 1.0;
	ROUGHNESS = 0.03;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
