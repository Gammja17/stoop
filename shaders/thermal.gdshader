shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;
// 상승기류 기둥: 멀리서 옅게 아른거리는 줄무늬. 가까이 가면 사라진다.

uniform float strength = 1.0;
uniform vec3 tint : source_color = vec3(1.0, 0.95, 0.8);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float band = pow(sin(UV.x * 60.0 + UV.y * 10.0 - TIME * 2.0) * 0.5 + 0.5, 10.0);
	float fade = smoothstep(0.0, 0.2, UV.y) * smoothstep(1.0, 0.5, UV.y);
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float df = smoothstep(40.0, 180.0, dist) * (1.0 - smoothstep(1000.0, 1900.0, dist));
	float edge = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float a = band * fade * df * strength * (0.01 + 0.035 * edge);
	ALBEDO = tint * a;
}
