class_name DayNight
extends Node
## 시간 흐름, 해/달, 하늘색, 안개, 날씨(비·눈·바람)를 관리한다.

signal new_day
signal hour_passed(hour: int)
signal dusk
signal nightfall

const NIGHT_REAL_SECONDS := 80.0

# [시각, 하늘 위, 지평선, 해 색, 해 세기, 주변광, 안개색, 별]
const KEYS := [
	[0.0, Color(0.015, 0.03, 0.07), Color(0.06, 0.08, 0.14), Color(0.5, 0.55, 0.8), 0.0, Color(0.17, 0.2, 0.32), Color(0.07, 0.09, 0.14), 1.0],
	[4.6, Color(0.025, 0.04, 0.09), Color(0.09, 0.1, 0.17), Color(0.5, 0.5, 0.7), 0.0, Color(0.18, 0.2, 0.3), Color(0.09, 0.1, 0.15), 1.0],
	[5.6, Color(0.12, 0.17, 0.34), Color(0.8, 0.48, 0.36), Color(1.0, 0.55, 0.3), 0.45, Color(0.32, 0.3, 0.34), Color(0.62, 0.46, 0.42), 0.25],
	[7.0, Color(0.2, 0.38, 0.7), Color(0.86, 0.78, 0.7), Color(1.0, 0.86, 0.66), 1.1, Color(0.46, 0.5, 0.56), Color(0.72, 0.72, 0.74), 0.0],
	[12.0, Color(0.15, 0.39, 0.8), Color(0.7, 0.82, 0.93), Color(1.0, 0.97, 0.92), 1.35, Color(0.5, 0.56, 0.64), Color(0.68, 0.78, 0.9), 0.0],
	[16.5, Color(0.17, 0.37, 0.74), Color(0.82, 0.78, 0.7), Color(1.0, 0.84, 0.62), 1.15, Color(0.48, 0.5, 0.55), Color(0.74, 0.72, 0.7), 0.0],
	[18.8, Color(0.13, 0.17, 0.37), Color(0.96, 0.5, 0.28), Color(1.0, 0.46, 0.2), 0.55, Color(0.32, 0.26, 0.3), Color(0.72, 0.44, 0.32), 0.1],
	[20.2, Color(0.035, 0.055, 0.13), Color(0.2, 0.15, 0.24), Color(0.6, 0.4, 0.5), 0.0, Color(0.17, 0.18, 0.28), Color(0.1, 0.11, 0.17), 0.8],
	[24.0, Color(0.015, 0.03, 0.07), Color(0.06, 0.08, 0.14), Color(0.5, 0.55, 0.8), 0.0, Color(0.17, 0.2, 0.32), Color(0.07, 0.09, 0.14), 1.0],
]

const WEATHER := {
	"clear": {"cloud": 0.35, "fog": 1.0, "wind": 4.0, "rain": 0.0, "snow": 0.0, "light": 1.0, "storm": 0.0},
	"cloudy": {"cloud": 0.75, "fog": 1.4, "wind": 6.0, "rain": 0.0, "snow": 0.0, "light": 0.7, "storm": 0.0},
	"windy": {"cloud": 0.5, "fog": 1.0, "wind": 11.0, "rain": 0.0, "snow": 0.0, "light": 0.95, "storm": 0.0},
	"rain": {"cloud": 0.95, "fog": 2.6, "wind": 8.0, "rain": 1.0, "snow": 0.0, "light": 0.45, "storm": 0.0},
	"fog": {"cloud": 0.6, "fog": 5.0, "wind": 2.0, "rain": 0.0, "snow": 0.0, "light": 0.65, "storm": 0.0},
	"snow": {"cloud": 0.9, "fog": 2.4, "wind": 5.0, "rain": 0.0, "snow": 1.0, "light": 0.6, "storm": 0.0},
	# 폭풍: 하루 중간에 먹구름이 몰려오며 시작된다 (LifeDirector가 시각을 정한다)
	"storm": {"cloud": 1.0, "fog": 3.2, "wind": 15.0, "rain": 1.0, "snow": 0.0, "light": 0.3, "storm": 1.0},
}

const SEASON_WEATHER := [
	{"clear": 5, "cloudy": 3, "windy": 2, "rain": 2, "fog": 2, "storm": 1},
	{"clear": 7, "cloudy": 2, "windy": 1, "rain": 1, "fog": 0, "storm": 2},
	{"clear": 4, "cloudy": 3, "windy": 3, "rain": 2, "fog": 2, "storm": 2},
	{"clear": 3, "cloudy": 3, "windy": 2, "snow": 4, "fog": 1},
]

var env: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_mat: ShaderMaterial
var world: WorldBuilder

var paused := false
var cur := {"cloud": 0.35, "fog": 1.0, "wind": 4.0, "rain": 0.0, "snow": 0.0, "light": 1.0, "storm": 0.0}
var gust := 0.0             # 폭풍 돌풍: 위아래로 흔드는 바람 (m/s)
var _gust_noise := FastNoiseLite.new()
var _t := 0.0
var _bolt_t := 6.0
var _flash := 0.0
var _bolt: MeshInstance3D
var _bolt_life := 0.0
var _cam: Node3D
var wind := Vector3(-4.0, 0.0, 0.0)
var _wind_angle := PI
var _last_hour := -1
var _dusk_sent := false
var _night_sent := false
var rain_fx: GPUParticles3D
var snow_fx: GPUParticles3D
var night := 0.0


func setup(p_env: Environment, p_sun: DirectionalLight3D, p_moon: DirectionalLight3D, p_world: WorldBuilder, cam: Node3D) -> void:
	env = p_env
	sun = p_sun
	moon = p_moon
	world = p_world
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var nt := NoiseTexture2D.new()
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.012
	fn.fractal_octaves = 5
	nt.noise = fn
	sky_mat.set_shader_parameter("cloud_noise", nt)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	_make_precip(cam)
	_cam = cam
	_make_bolt()
	_gust_noise.frequency = 0.35
	apply_weather(GameState.data.get("weather", "clear"), true)
	update_visuals()


func _make_precip(cam: Node3D) -> void:
	rain_fx = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(35, 1, 35)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 4.0
	pm.initial_velocity_min = 32.0
	pm.initial_velocity_max = 40.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.particle_flag_align_y = true
	rain_fx.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 1.1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.8, 0.85, 0.95, 0.35)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	rain_fx.draw_pass_1 = q
	rain_fx.amount = 2500
	rain_fx.lifetime = 1.6
	rain_fx.visibility_aabb = AABB(Vector3(-40, -70, -40), Vector3(80, 90, 80))
	rain_fx.position = Vector3(0, 22, 0)
	rain_fx.emitting = false
	rain_fx.local_coords = false
	cam.add_child(rain_fx)
	snow_fx = GPUParticles3D.new()
	var sp := ParticleProcessMaterial.new()
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sp.emission_box_extents = Vector3(35, 1, 35)
	sp.direction = Vector3(0, -1, 0)
	sp.spread = 25.0
	sp.initial_velocity_min = 2.0
	sp.initial_velocity_max = 4.0
	sp.gravity = Vector3(0, -1.5, 0)
	sp.turbulence_enabled = true
	sp.turbulence_noise_strength = 2.0
	snow_fx.process_material = sp
	var sq := QuadMesh.new()
	sq.size = Vector2(0.12, 0.12)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(1, 1, 1, 0.85)
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sq.material = sm
	snow_fx.draw_pass_1 = sq
	snow_fx.amount = 1800
	snow_fx.lifetime = 9.0
	snow_fx.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 60, 80))
	snow_fx.position = Vector3(0, 18, 0)
	snow_fx.emitting = false
	snow_fx.local_coords = false
	cam.add_child(snow_fx)


func hours() -> float:
	return float(GameState.data.get("time", 12.0))


func is_night() -> bool:
	var h := hours()
	return h >= 20.2 or h < 5.2


## 게임 시간당 실시간 초
func _rate() -> float:
	var h := hours()
	if h >= 5.0 and h < 20.0:
		return 15.0 / (Settings.day_minutes * 60.0)
	return 9.0 / NIGHT_REAL_SECONDS


func advance(delta: float) -> void:
	if paused or GameState.data.is_empty():
		return
	var h := hours() + _rate() * delta
	var day_rolled := false
	if h >= 24.0:
		h -= 24.0
	if hours() < 5.0 and h >= 5.0:
		day_rolled = true
	GameState.data["time"] = h
	var hi := int(h)
	if hi != _last_hour:
		_last_hour = hi
		hour_passed.emit(hi)
	if h >= 18.6 and h < 19.0 and not _dusk_sent:
		_dusk_sent = true
		dusk.emit()
	if h >= 20.2 and h < 21.0 and not _night_sent:
		_night_sent = true
		nightfall.emit()
	if day_rolled:
		_dusk_sent = false
		_night_sent = false
		new_day.emit()


func set_time(h: float) -> void:
	GameState.data["time"] = h
	_last_hour = int(h)
	_dusk_sent = h >= 18.6
	_night_sent = h >= 20.2 or h < 5.0


func pick_weather() -> String:
	var season := int(GameState.data.get("season", 0))
	var table: Dictionary = SEASON_WEATHER[season]
	var total := 0
	for k in table:
		total += table[k]
	var r := randi() % total
	for k in table:
		r -= table[k]
		if r < 0:
			return k
	return "clear"


func apply_weather(w: String, instant: bool = false) -> void:
	GameState.data["weather"] = w
	var target: Dictionary = WEATHER.get(w, WEATHER["clear"])
	_wind_angle = PI + randf_range(-0.6, 0.6)
	if instant:
		cur = target.duplicate()
	else:
		var tw := create_tween().set_parallel(true)
		for k in target:
			tw.tween_method(func(v): cur[k] = v, float(cur[k]), float(target[k]), 20.0)


func _process(delta: float) -> void:
	_t += delta
	var st: float = cur.get("storm", 0.0)
	_update_storm(delta, st)
	update_visuals()
	var ws: float = cur["wind"] * (1.0 + 0.5 * st * _gust_noise.get_noise_1d(_t * 40.0))
	wind = Vector3(cos(_wind_angle), 0.0, sin(_wind_angle)) * ws


# ---------- 폭풍: 돌풍과 번개 ----------

func _make_bolt() -> void:
	_bolt = MeshInstance3D.new()
	_bolt.mesh = ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.85, 0.9, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	_bolt.material_override = m
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.visible = false
	world.add_child(_bolt)


func _update_storm(delta: float, st: float) -> void:
	gust = _gust_noise.get_noise_1d(_t * 13.0 + 100.0) * 7.0 * st
	_flash = move_toward(_flash, 0.0, delta * 5.0)
	if _bolt_life > 0.0:
		_bolt_life -= delta
		_bolt.visible = _bolt_life > 0.0 and not (_bolt_life > 0.1 and _bolt_life < 0.15)   # 한 번 깜빡
	if st < 0.6 or _cam == null:
		return
	_bolt_t -= delta
	if _bolt_t <= 0.0:
		_bolt_t = randf_range(3.5, 10.0)
		_strike()


## 번개 한 번: 멀리서 줄기가 내리꽂히고 하늘이 번쩍, 거리만큼 늦게 천둥
func _strike() -> void:
	var cp := _cam.global_position
	# 대부분은 보는 쪽 앞에 친다
	var fwd := -_cam.global_basis.z
	var a := atan2(fwd.z, fwd.x) + randf_range(-0.9, 0.9) if randf() < 0.75 else randf() * TAU
	var dist := randf_range(250.0, 1100.0)
	var base := cp + Vector3(cos(a) * dist, 0.0, sin(a) * dist)
	base.y = WorldShape.floor_y(base.x, base.z)
	var top := base + Vector3(randf_range(-60, 60), 420.0 + randf() * 80.0, randf_range(-60, 60))
	var im: ImmediateMesh = _bolt.mesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_bolt_branch(im, top, base, 5.0, 14, cp)
	for i in 2:
		var k := randf_range(0.25, 0.6)
		var from := top.lerp(base, k)
		var to := from + Vector3(randf_range(-120, 120), -(from.y - base.y) * randf_range(0.3, 0.6), randf_range(-120, 120))
		_bolt_branch(im, from, to, 2.5, 7, cp)
	im.surface_end()
	_bolt_life = 0.28
	_bolt.visible = true
	_flash = clampf(1.3 - dist / 1200.0, 0.3, 1.0)
	var m = get_tree().get_first_node_in_group("main")
	if m and dist < 500.0:
		m._flash = maxf(m._flash, 0.15)
	var delay := dist / 340.0
	var vol := lerpf(6.0, -6.0, dist / 1100.0)
	get_tree().create_timer(delay, false).timeout.connect(func(): Sfx.play("thunder", vol, randf_range(0.85, 1.1)))


func _bolt_branch(im: ImmediateMesh, from: Vector3, to: Vector3, w: float, segs: int, cp: Vector3) -> void:
	var prev := from
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var p := from.lerp(to, t)
		if i < segs:
			p += Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * (from.distance_to(to) / segs) * 0.6
		var seg := p - prev
		var side := seg.cross(cp - prev).normalized() * w
		im.surface_add_vertex(prev - side)
		im.surface_add_vertex(prev + side)
		im.surface_add_vertex(p + side)
		im.surface_add_vertex(prev - side)
		im.surface_add_vertex(p + side)
		im.surface_add_vertex(p - side)
		prev = p


func update_visuals() -> void:
	if env == null:
		return
	var h := hours()
	var a: Array = KEYS[0]
	var b: Array = KEYS[1]
	for i in KEYS.size() - 1:
		if h >= KEYS[i][0] and h <= KEYS[i + 1][0]:
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var t := 0.0
	if b[0] > a[0]:
		t = (h - a[0]) / (b[0] - a[0])
	t = smoothstep(0.0, 1.0, t)
	var top: Color = a[1].lerp(b[1], t)
	var hor: Color = a[2].lerp(b[2], t)
	var sun_c: Color = a[3].lerp(b[3], t)
	var sun_e: float = lerpf(a[4], b[4], t)
	var amb: Color = a[5].lerp(b[5], t)
	var fog_c: Color = a[6].lerp(b[6], t)
	var stars: float = lerpf(a[7], b[7], t)
	night = stars
	var cloud: float = cur["cloud"]
	var light_k: float = cur["light"]
	# 흐린 날은 하늘을 회색으로
	var gray := clampf((cloud - 0.5) * 1.6, 0.0, 1.0)
	top = top.lerp(Color(top.get_luminance(), top.get_luminance(), top.get_luminance()) * 1.1, gray * 0.7)
	hor = hor.lerp(Color(hor.get_luminance(), hor.get_luminance(), hor.get_luminance()), gray * 0.6)
	# 폭풍: 하늘·안개·빛이 어두운 납빛으로
	var st: float = cur.get("storm", 0.0)
	top = top.lerp(Color(0.16, 0.18, 0.22), st * 0.8)
	hor = hor.lerp(Color(0.3, 0.32, 0.36), st * 0.75)
	fog_c = fog_c.lerp(Color(0.26, 0.28, 0.32), st * 0.75)
	amb = amb * (1.0 - 0.35 * st)
	sky_mat.set_shader_parameter("top_color", top)
	sky_mat.set_shader_parameter("horizon_color", hor)
	sky_mat.set_shader_parameter("ground_color", hor * 0.55)
	sky_mat.set_shader_parameter("sun_color", sun_c)
	sky_mat.set_shader_parameter("stars", stars * (1.0 - gray))
	sky_mat.set_shader_parameter("cloud_cover", cloud)
	sky_mat.set_shader_parameter("cloud_light", (Color(1, 1, 1).lerp(sun_c, 0.35) * maxf(sun_e, 0.12) * 0.85 + amb * 0.3) * (1.0 - 0.6 * st))
	sky_mat.set_shader_parameter("cloud_shade", amb * 0.9 + hor * 0.25)
	# 해 방향
	var season := int(GameState.data.get("season", 0))
	var elev: float = [55.0, 70.0, 45.0, 30.0][season]
	var th := (h - 6.0) / 13.5 * PI
	var d := Vector3(cos(th), sin(th) * sin(deg_to_rad(elev)), sin(th) * cos(deg_to_rad(elev)) + 0.15).normalized()
	sun.basis = Basis.looking_at(-d, Vector3.UP if absf(d.y) < 0.99 else Vector3.FORWARD)
	sun.light_color = sun_c
	sun.light_energy = sun_e * light_k * clampf(d.y * 6.0, 0.0, 1.0)
	sun.shadow_enabled = sun.light_energy > 0.05
	sun.visible = sun.light_energy > 0.001
	var md := Vector3(-d.x, absf(d.y) * 0.8 + 0.3, -d.z * 0.5).normalized()
	moon.basis = Basis.looking_at(-md, Vector3.UP)
	moon.light_energy = 0.4 * stars
	sky_mat.set_shader_parameter("moon_dir", md)
	# 번개: 하늘과 주변광이 순간 밝아진다
	if _flash > 0.01:
		sky_mat.set_shader_parameter("top_color", top.lerp(Color(0.75, 0.8, 0.95), _flash * 0.8))
		sky_mat.set_shader_parameter("horizon_color", hor.lerp(Color(0.85, 0.88, 1.0), _flash * 0.8))
		sky_mat.set_shader_parameter("cloud_light", Color(0.9, 0.93, 1.0) * (1.0 + _flash * 2.0))
	env.ambient_light_color = amb.lerp(Color(0.8, 0.85, 1.0), _flash * 0.7)
	env.ambient_light_energy = lerpf(0.6, 1.0, light_k) + _flash * 1.5
	env.fog_light_color = fog_c
	env.fog_density = 0.00032 * float(cur["fog"])
	env.fog_sun_scatter = 0.25 * sun_e
	if world and world.water_mat:
		world.water_mat.set_shader_parameter("darkness", stars * 0.8)
		world.water_mat.set_shader_parameter("roughness_boost", clampf(float(cur["wind"]) / 12.0, 0.0, 1.0))
		world.set_thermal_strength((1.0 - stars) * clampf(sun_e, 0.0, 1.0))
		world.set_storm(st)
		world.set_city_night(clampf(stars * 1.3 + (1.0 - light_k) * 0.4, 0.0, 1.0))
	if rain_fx:
		rain_fx.emitting = float(cur["rain"]) > 0.3
		rain_fx.amount_ratio = lerpf(0.55, 1.0, float(cur.get("storm", 0.0)))
		snow_fx.emitting = float(cur["snow"]) > 0.3
	Sfx.rain_level = float(cur["rain"])


## 상승기류 세기 배율 (낮·맑음에 강함)
func thermal_factor() -> float:
	var h := hours()
	var sunk := smoothstep(8.0, 11.0, h) * (1.0 - smoothstep(16.5, 19.0, h))
	return sunk * clampf(1.2 - float(cur["cloud"]) * 0.6, 0.3, 1.0) * (1.0 - float(cur["rain"]) * 0.7)
