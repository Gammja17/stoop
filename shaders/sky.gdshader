shader_type sky;
render_mode use_debanding;

uniform vec3 top_color : source_color = vec3(0.22, 0.45, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.7, 0.8, 0.9);
uniform vec3 ground_color : source_color = vec3(0.35, 0.4, 0.45);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_size = 1.0;
uniform float sun_glow = 0.35;
uniform float stars = 0.0;
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;
uniform vec3 cloud_light : source_color = vec3(1.0);
uniform vec3 cloud_shade : source_color = vec3(0.62, 0.66, 0.74);
uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;
uniform vec2 cloud_wind = vec2(0.004, 0.0015);
uniform vec3 moon_dir = vec3(0.0, 1.0, 0.0);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.5));
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-h * 3.0, 0.0, 1.0));
	}
	if (LIGHT0_ENABLED) {
		float sdot = dot(d, LIGHT0_DIRECTION);
		col += sun_color * pow(max(sdot, 0.0), 6.0) * sun_glow;
		col += sun_color * pow(max(sdot, 0.0), 64.0) * sun_glow * 1.5;
		col += sun_color * smoothstep(0.99955 - sun_size * 0.0002, 0.9997, sdot) * 12.0;
	}
	if (stars > 0.0 && h > 0.0) {
		vec3 q = floor(d * 380.0);
		float st = step(0.9978, hash(q));
		float tw = 0.6 + 0.4 * sin(TIME * 3.0 + hash(q + 3.1) * 40.0);
		col += vec3(st * tw) * stars * smoothstep(0.0, 0.25, h);
		float md = dot(d, normalize(moon_dir));
		col += vec3(0.85, 0.9, 1.0) * smoothstep(0.99935, 0.99965, md) * stars * 2.0;
		col += vec3(0.3, 0.35, 0.5) * pow(max(md, 0.0), 40.0) * stars * 0.4;
	}
	if (h > -0.02) {
		float hh = max(h, 0.0);
		vec2 uv = d.xz / (hh + 0.12) * 0.28 + TIME * cloud_wind;
		float n1 = texture(cloud_noise, uv).r;
		float n2 = texture(cloud_noise, uv * 2.6 + vec2(0.3, 0.7)).r;
		float dens = n1 * 0.7 + n2 * 0.3;
		float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.32, dens);
		c *= smoothstep(-0.02, 0.2, h);
		vec3 cc = mix(cloud_shade, cloud_light, clamp(n2 * 1.2 - 0.1, 0.0, 1.0));
		col = mix(col, cc, c * 0.88);
	}
	COLOR = col;
}
