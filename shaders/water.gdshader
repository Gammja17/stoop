shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform vec3 deep_color : source_color = vec3(0.02, 0.13, 0.19);
uniform vec3 shallow_color : source_color = vec3(0.1, 0.38, 0.4);
uniform vec3 foam_color : source_color = vec3(0.92, 0.95, 0.96);
uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform float roughness_boost : hint_range(0.0, 1.0) = 0.0;
uniform float wave_speed = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 사인파 합의 해석적 기울기
vec2 wave_grad(vec2 p, float t, float dist) {
	vec2 g = vec2(0.0);
	vec2 dirs[6] = vec2[](vec2(1.0, 0.2), vec2(0.7, -0.7), vec2(0.2, 1.0), vec2(-0.6, 0.8), vec2(0.9, 0.45), vec2(-0.3, -0.95));
	float freqs[6] = float[](0.045, 0.08, 0.13, 0.31, 0.72, 1.6);
	float amps[6] = float[](0.9, 0.55, 0.35, 0.14, 0.05, 0.018);
	float spds[6] = float[](0.6, 0.8, 1.0, 1.5, 2.3, 3.4);
	for (int i = 0; i < 6; i++) {
		vec2 d = normalize(dirs[i]);
		float ph = dot(d, p) * freqs[i] + t * spds[i];
		float fade = 1.0 - smoothstep(12.0 / freqs[i], 120.0 / freqs[i], dist);
		g += d * cos(ph) * freqs[i] * amps[i] * fade;
	}
	return g;
}

void fragment() {
	float t = TIME * wave_speed;
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	vec2 g = wave_grad(wpos.xz, t, dist);
	float fade = smoothstep(150.0, 1800.0, dist);
	g *= mix(1.0, 0.25, fade);
	vec3 n = normalize(vec3(-g.x, 1.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	upos.xyz /= upos.w;
	float wdepth = clamp(VERTEX.z - upos.z, 0.0, 400.0);

	float dfac = clamp(wdepth / 16.0, 0.0, 1.0);
	vec3 col = mix(shallow_color, deep_color, dfac);
	float foam_line = smoothstep(0.9, 0.0, wdepth);
	float foam_n = 0.7 + 0.3 * sin(t * 1.3 + (wpos.x + wpos.z) * 0.08);
	float foam = foam_line * foam_n;
	col = mix(col, foam_color, foam * 0.75);
	ALBEDO = col * (1.0 - darkness * 0.7);
	ROUGHNESS = clamp(0.05 + 0.25 * foam + roughness_boost * 0.25 + fade * 0.08, 0.0, 1.0);
	SPECULAR = 0.6;
	ALPHA = mix(0.55, 0.97, smoothstep(0.0, 6.0, wdepth));
}
