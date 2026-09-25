shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley;
// 해식 기둥·둥지 선반용 삼면 투영 바위

uniform sampler2D tex_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_top : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_snow : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float scale = 0.06;
uniform float top_amount = 0.7;
uniform float snow_amount = 0.0;
uniform vec3 tint : source_color = vec3(1.0);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = pow(abs(wnorm), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 r = texture(tex_rock, wpos.zy * scale).rgb * w.x + texture(tex_rock, wpos.xz * scale).rgb * w.y + texture(tex_rock, wpos.xy * scale).rgb * w.z;
	vec3 col = r * tint;
	float top = smoothstep(0.62, 0.85, wnorm.y) * top_amount;
	col = mix(col, texture(tex_top, wpos.xz * 0.05).rgb * vec3(0.9, 1.0, 0.85), top);
	float sn = smoothstep(0.55, 0.8, wnorm.y) * snow_amount;
	col = mix(col, texture(tex_snow, wpos.xz * 0.05).rgb, sn);
	// 바다 근처 젖은 띠
	col *= mix(0.7, 1.0, smoothstep(0.0, 3.0, wpos.y));
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
