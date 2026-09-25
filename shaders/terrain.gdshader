shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// 정점 색: r=갯벌, g=모래사장, b=마을 흙
uniform sampler2D tex_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nrm_grass : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nrm_rock : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_sand : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_mud : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_snow : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

uniform float grass_scale = 0.035;
uniform float rock_scale = 0.045;
uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;
uniform float autumn : hint_range(0.0, 1.0) = 0.0;
uniform float summer : hint_range(0.0, 1.0) = 0.0;
uniform float wet : hint_range(0.0, 1.0) = 0.0;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tri_rock(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 a = texture(tex_rock, p.zy * rock_scale).rgb;
	vec3 b = texture(tex_rock, p.xz * rock_scale).rgb;
	vec3 c = texture(tex_rock, p.xy * rock_scale).rgb;
	return a * w.x + b * w.y + c * w.z;
}

void fragment() {
	vec2 uv = wpos.xz;
	vec3 g1 = texture(tex_grass, uv * grass_scale).rgb;
	vec3 g2 = texture(tex_grass, uv * grass_scale * 0.21 + vec2(0.37, 0.71)).rgb;
	vec3 grass = mix(g1, g2, 0.45) * vec3(0.92, 1.02, 0.86);
	grass = mix(grass, grass * vec3(1.12, 1.02, 0.72), summer);
	grass = mix(grass, grass * vec3(1.35, 1.0, 0.55), autumn);
	vec3 sand = texture(tex_sand, uv * 0.07).rgb * vec3(1.05, 1.0, 0.92);
	vec3 mud = texture(tex_mud, uv * 0.05).rgb * vec3(0.85, 0.8, 0.72);
	vec3 rock = tri_rock(wpos, wnorm) * vec3(0.95, 0.93, 0.9);
	vec3 snow = texture(tex_snow, uv * 0.03).rgb;

	float slope = 1.0 - wnorm.y;
	float rockw = smoothstep(0.26, 0.46, slope);
	vec3 col = grass;
	col = mix(col, sand, COLOR.g);
	col = mix(col, mud, COLOR.r);
	col = mix(col, mix(grass, sand * 0.85, 0.55), COLOR.b * 0.7);
	col = mix(col, rock, rockw);

	float under = smoothstep(0.3, -5.0, wpos.y);
	col = mix(col, col * vec3(0.5, 0.6, 0.6), under);

	float sn = snow_amount * smoothstep(0.34, 0.16, slope) * smoothstep(1.2, 5.0, wpos.y);
	col = mix(col, snow, sn);

	ALBEDO = col;
	float wet_mud = COLOR.r * (1.0 - under);
	ROUGHNESS = clamp(mix(0.95, 0.35, wet_mud * 0.8 + wet * 0.4), 0.2, 1.0);
	SPECULAR = 0.3 + 0.3 * wet_mud;

	vec3 n1 = texture(nrm_grass, uv * grass_scale).rgb;
	vec3 n2 = texture(nrm_rock, uv * rock_scale).rgb;
	NORMAL_MAP = mix(n1, n2, rockw);
	NORMAL_MAP_DEPTH = 0.7 * (1.0 - sn);
}
