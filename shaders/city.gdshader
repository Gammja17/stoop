shader_type spatial;
// 빌딩 벽: 세계 좌표로 창문 격자를 그린다. 밤에는 일부 창문에 불이 켜진다.

uniform vec3 wall_a : source_color = vec3(0.62, 0.62, 0.6);
uniform vec3 wall_b : source_color = vec3(0.42, 0.45, 0.5);
uniform vec3 roof_color : source_color = vec3(0.33, 0.34, 0.36);
uniform vec3 glass : source_color = vec3(0.14, 0.19, 0.26);
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float street_level = 42.0;

varying vec3 wpos;
varying vec3 wnrm;
varying vec3 bcenter;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	bcenter = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
}

void fragment() {
	float bid = hash(floor(bcenter.xz * 0.37));
	vec3 base = mix(wall_a, wall_b, bid);
	if (wnrm.y > 0.5) {
		ALBEDO = roof_color * (0.85 + 0.3 * bid);
		ROUGHNESS = 0.95;
	} else {
		float u = abs(wnrm.x) > 0.5 ? wpos.z : wpos.x;
		vec2 cell = vec2(u / 3.4, (wpos.y - 1.0) / 3.8);
		vec2 f = fract(cell);
		float win = step(0.16, f.x) * step(f.x, 0.84) * step(0.28, f.y) * step(f.y, 0.82);
		// 1층(로비)은 창문 없이 어둡게
		float lobby = 1.0 - step(street_level + 4.5, wpos.y);
		win *= 1.0 - lobby;
		float lit = step(0.58, hash(floor(cell) + bcenter.xz));
		ALBEDO = mix(base * (1.0 - 0.25 * lobby), glass, win);
		ROUGHNESS = mix(0.85, 0.12, win);
		METALLIC = win * 0.35;
		EMISSION = vec3(1.0, 0.82, 0.52) * win * lit * night * 2.2;
	}
}
