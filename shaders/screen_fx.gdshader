shader_type canvas_item;
// 속도감/타격감 화면 효과: 방사형 블러, 속도선, 색수차, 비네트, G 터널, 번쩍임

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur = 0.0;
uniform float lines = 0.0;
uniform float aberration = 0.0;
uniform float vignette = 0.25;
uniform float g_tunnel = 0.0;
uniform float flash = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0);
uniform float damage = 0.0;
uniform float warn = 0.0;
uniform float night = 0.0;
uniform float eye = 0.0;
uniform float t = 0.0;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	vec2 ca = c * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float r = length(ca);
	float bs = blur * smoothstep(0.12, 0.75, r);
	vec3 col = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float k = float(i) / 8.0;
		col += texture(screen_tex, uv - c * bs * k * 0.09).rgb;
	}
	col /= 8.0;
	if (aberration > 0.001) {
		float a = aberration * 0.008;
		col.r = mix(col.r, texture(screen_tex, uv + c * a).r, 0.9);
		col.b = mix(col.b, texture(screen_tex, uv - c * a).b, 0.9);
	}
	if (lines > 0.001) {
		float ang = atan(ca.y, ca.x);
		float seg = floor(ang * 70.0);
		float h = hash(seg + floor(t * 14.0) * 13.1);
		float streak = step(0.9, h) * smoothstep(0.32, 0.62, r) * smoothstep(1.0, 0.7, r);
		float along = fract(r * 3.0 - t * 6.0 * (0.5 + h));
		streak *= smoothstep(0.0, 0.2, along) * smoothstep(1.0, 0.6, along);
		col = mix(col, vec3(1.0), streak * lines * 0.35);
	}
	col *= 1.0 - vignette * smoothstep(0.35, 0.9, r);
	col = mix(col, vec3(0.0), g_tunnel * smoothstep(0.12, 0.62, r));
	col = mix(col, vec3(0.55, 0.02, 0.02), damage * smoothstep(0.15, 0.8, r) * 0.85);
	col = mix(col, vec3(0.95, 0.12, 0.06), warn * smoothstep(0.3, 0.85, r) * (0.55 + 0.45 * sin(t * 16.0)) * 0.55);
	if (eye > 0.001) {
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		vec3 gray = mix(vec3(lum), col, 0.45) * vec3(1.02, 1.0, 0.94);
		col = mix(col, gray, eye * 0.6);
		col *= 1.0 - eye * 0.5 * smoothstep(0.3, 0.7, r);
	}
	col = mix(col, flash_color, clamp(flash, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
