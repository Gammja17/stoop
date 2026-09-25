class_name Falcon
extends Node3D
## 플레이어 송골매. 에너지(고도↔속도) 기반 비행, 날개 접기(급강하), 날갯짓, 착지, 들기.
##
## 핵심 규칙
##  - 속도는 진행 방향의 스칼라. 아래로 향하면 중력으로 빨라지고 위로 향하면 느려진다.
##  - 날개를 접으면(tuck) 항력이 크게 줄어 최고 속도가 오르지만 선회력이 떨어진다.
##  - 방향을 틀면 속도가 깎인다(turn bleed). 처음부터 잘 겨눌수록 빠르게 꽂힌다.

signal crashed(impact: float, damage: float)
signal landed(perch: Dictionary)
signal took_off
signal display_dive(peak_kmh: float, rolls: int)

enum State { FLYING, PERCHED, LANDING, STUNNED, FROZEN }

const G := 14.0
const CD_OPEN := 0.0042
const CD_TUCK := 0.00082
const CD_BRAKE := 0.022
const STALL := 8.5
const FLAP_ACCEL := 10.5
const FLAP_MAX := 30.0
const TURN_OPEN := 2.35
const TURN_TUCK := 0.8
const TURN_BLEED := 0.14
const G_OPEN := 85.0      # 날개 편 상태 최대 선회 가속도 (m/s²)
const G_TUCK := 42.0      # 날개 접은 상태
const ASSIST_RANGE := 30.0   # 조준 보조가 작동하는 거리
const ASSIST_RATE := 0.55    # 조준 보조 최대 회전 (rad/s)
const MOUSE_K := 0.0022
const KEY_TURN := 1.3        # A/D 선회 속도 (rad/s)
const DOUBLE_TAP := 0.3      # 이 안에 두 번 누르면 구르기

var state := State.FROZEN
var dir := Vector3.FORWARD
var speed := 20.0
var velocity := Vector3.ZERO
var aim_yaw := 0.0
var aim_pitch := 0.0
var tuck := 0.0
var stamina := 100.0
var max_stamina := 100.0
var flapping := false
var braking := false
var bank := 0.0
var roll_spin := 0.0
var turn_rate := 0.0
var g_load := 0.0
var updraft := 0.0
var in_thermal := false
var stalled := false
var carrying: Node3D = null
var perch: Dictionary = {}
var input_enabled := true
var eye_active := false
var assist_target: Node3D = null
var auto_circle := false     # 상승기류 안에서 손을 떼면 알아서 돈다
var thermal_here: Dictionary = {}
var thermal_k := 0.0
var _aim_idle := 0.0         # 마지막 조준 입력 뒤 지난 시간
var _circle_sign := 0.0
var _tap_t := {"l": -1.0, "r": -1.0}

var speed_mult := 1.0
var agility_mult := 1.0
var power_mult := 1.0

var model: BirdModel
var _prev_pos := Vector3.ZERO
var _flap_t := 0.0
var _flap_sound_t := 0.0
var _stun_t := 0.0
var _land_from := Vector3.ZERO
var _land_t := 0.0
var _dive_peak := 0.0
var _dive_rolls := 0
var _in_dive := false
var _roll_dir := 0.0
var _roll_left := 0.0
var _prev_speed := 0.0
var accel_smooth := 0.0


func _ready() -> void:
	model = BirdModel.new()
	add_child(model)
	var female: bool = GameState.falcon().get("sex", "m") == "f"
	model.setup("falcon_f" if female else "falcon")
	apply_stats()
	add_child(WingTrails.new())


func apply_stats() -> void:
	var f := GameState.falcon()
	var female: bool = f.get("sex", "m") == "f"
	# 수컷: 가볍고 민첩 / 암컷: 크고 힘이 세다
	speed_mult = (1.0 if not female else 0.97) + float(f.get("bonus_speed", 0.0))
	agility_mult = (1.08 if not female else 0.94) + float(f.get("bonus_agility", 0.0))
	power_mult = 1.0 if not female else 1.3
	var age := int(f.get("age", 1))
	var lifespan := int(f.get("lifespan", 6))
	var old := clampf(float(age - (lifespan - 2)) * 0.12, 0.0, 0.3)
	max_stamina = 100.0 + float(f.get("bonus_stamina", 0.0)) - old * 60.0


func aim_dir() -> Vector3:
	return (Basis(Vector3.UP, aim_yaw) * Basis(Vector3.RIGHT, aim_pitch)) * Vector3.FORWARD


func set_heading(d: Vector3) -> void:
	dir = d.normalized()
	aim_yaw = atan2(-dir.x, -dir.z)
	aim_pitch = asin(clampf(dir.y, -1.0, 1.0))


func spawn_flying(pos: Vector3, heading: Vector3, spd: float) -> void:
	global_position = pos
	_prev_pos = pos
	set_heading(heading)
	speed = spd
	state = State.FLYING
	_aim_idle = 0.0
	tuck = 0.0


func spawn_perched(p: Dictionary) -> void:
	perch = p
	global_position = p.pos
	_prev_pos = p.pos
	var f: Vector3 = p.get("facing", Vector3.RIGHT)
	set_heading(f)
	speed = 0.0
	state = State.PERCHED


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var k := MOUSE_K * Settings.mouse_sens * (0.45 if eye_active else 1.0)
		aim_yaw -= event.relative.x * k
		if event.relative.length() > 0.5:
			_aim_idle = 0.0
		var dy: float = event.relative.y * k
		aim_pitch -= -dy if Settings.invert_y else dy
		aim_pitch = clampf(aim_pitch, deg_to_rad(-88.0), deg_to_rad(75.0))


func _process(delta: float) -> void:
	_prev_pos = global_position
	match state:
		State.FLYING:
			_fly(delta)
		State.PERCHED:
			_perched(delta)
		State.LANDING:
			_landing(delta)
		State.STUNNED:
			_stunned(delta)
		State.FROZEN:
			pass
	_update_model(delta)


func _read_input(delta: float) -> Dictionary:
	var inp := {"tuck": 0.0, "flap": false, "brake": false, "roll": 0.0}
	if not input_enabled:
		return inp
	inp.tuck = Input.get_action_strength("tuck")
	inp.flap = Input.is_action_pressed("flap")
	inp.brake = Input.is_action_pressed("brake")
	# A/D: 누르고 있으면 좌우 선회, 빠르게 두 번 누르면 구르기
	var turn := Input.get_action_strength("roll_right") - Input.get_action_strength("roll_left")
	if absf(turn) > 0.1:
		aim_yaw -= turn * KEY_TURN * delta
		_aim_idle = 0.0
	var now := Time.get_ticks_msec() / 1000.0
	for side: String in ["l", "r"]:
		if Input.is_action_just_pressed("roll_left" if side == "l" else "roll_right"):
			if now - float(_tap_t[side]) < DOUBLE_TAP:
				inp.roll = -1.0 if side == "l" else 1.0
				_tap_t[side] = -1.0
			else:
				_tap_t[side] = now
	# 패드 스틱 조준
	var jx := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var jy := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	var jv := Vector2(jx, jy)
	if jv.length() > 0.18:
		_aim_idle = 0.0
		var rate := 2.2 * Settings.mouse_sens * delta
		aim_yaw -= jx * rate
		aim_pitch -= (jy if not Settings.invert_y else -jy) * rate
		aim_pitch = clampf(aim_pitch, deg_to_rad(-88.0), deg_to_rad(75.0))
	return inp


func _fly(delta: float) -> void:
	_aim_idle += delta
	var inp := _read_input(delta)
	var want_tuck: float = inp.tuck
	_assist_steering(delta, inp)
	if stalled:
		want_tuck = 0.0
	tuck = move_toward(tuck, want_tuck, delta * (3.4 if want_tuck > tuck else 4.8))
	braking = inp.brake and tuck < 0.4
	# 조준이 진행 방향에서 너무 멀면 끌어온다
	var ad := aim_dir()
	var off := dir.angle_to(ad)
	var max_off := deg_to_rad(95.0)
	if off > max_off:
		var cl := dir.slerp(ad, max_off / off).normalized()
		aim_yaw = atan2(-cl.x, -cl.z)
		aim_pitch = asin(clampf(cl.y, -1.0, 1.0))
		ad = cl
	# 선회
	var authority := clampf(speed / 15.0, 0.3, 1.4)
	var max_turn := lerpf(TURN_OPEN, TURN_TUCK, tuck) * authority * agility_mult
	if braking:
		max_turn *= 1.25
	if stalled:
		max_turn *= 0.45
	# 원심 가속도 한계(G): 빠를수록 크게 돌 수 없다 → 너무 낮게 꽂히면 못 빠져나온다
	var g_cap := lerpf(G_OPEN, G_TUCK, tuck) * agility_mult / maxf(speed, 1.0)
	max_turn = minf(max_turn, g_cap)
	var ang := dir.angle_to(ad)
	var step := minf(ang, max_turn * delta)
	var old_dir := dir
	if ang > 0.0001:
		var axis := dir.cross(ad)
		if axis.length() < 0.0001:
			axis = Vector3.UP
		dir = dir.rotated(axis.normalized(), step).normalized()
	turn_rate = step / maxf(delta, 0.0001)
	# 조준 보조: 목표가 코앞이고 거의 겨눈 상태면 살짝 끌어당긴다(자동 명중은 아님)
	if assist_target and is_instance_valid(assist_target):
		var to := assist_target.global_position - global_position
		var dist := to.length()
		if dist < ASSIST_RANGE and dist > 0.5:
			var a2 := dir.angle_to(to)
			if a2 < deg_to_rad(14.0) and a2 > 0.0001:
				var ax := dir.cross(to)
				if ax.length() > 0.0001:
					dir = dir.rotated(ax.normalized(), minf(a2, ASSIST_RATE * delta)).normalized()
	g_load = lerpf(g_load, turn_rate * speed / G, 1.0 - exp(-6.0 * delta))
	# 가속
	var acc := -G * dir.y
	var cd := lerpf(CD_OPEN, CD_TUCK, tuck) / speed_mult + (CD_BRAKE if braking else 0.0)
	var carry_w := 0.0
	if carrying:
		carry_w = float(carrying.get("weight"))
		cd += carry_w * 0.004
	acc -= cd * speed * speed
	acc -= TURN_BLEED * turn_rate * speed
	flapping = false
	if inp.flap and tuck < 0.35 and stamina > 0.5:
		var lim := FLAP_MAX * speed_mult * (1.0 - carry_w * 0.25)
		flapping = true
		stamina -= 19.0 * delta
		if speed < lim:
			acc += FLAP_ACCEL * (1.0 - carry_w * 0.45)
	else:
		var regen := 11.0 if GameState.falcon().get("energy", 50.0) > 20.0 else 5.0
		stamina = minf(stamina + regen * delta, max_stamina)
	speed = maxf(speed + acc * delta, 0.0)
	# 실속
	if speed < STALL and tuck < 0.5:
		stalled = true
	elif speed > STALL + 5.0:
		stalled = false
	if stalled:
		var down := (Vector3(dir.x, 0, dir.z).normalized() + Vector3.DOWN * 1.2).normalized()
		dir = dir.slerp(down, 1.0 - exp(-1.6 * delta)).normalized()
		# 조준은 살짝만 내린다 (카메라가 제멋대로 고개 숙이지 않게)
		if aim_pitch > deg_to_rad(-12.0):
			aim_pitch = lerpf(aim_pitch, deg_to_rad(-12.0), 1.0 - exp(-1.0 * delta))
		speed += 3.0 * delta
	# 상승기류 / 능선 바람
	var was_in := in_thermal
	updraft = _compute_updraft() * (1.0 - tuck)
	if in_thermal and not was_in:
		Sfx.play("whoosh", -12.0, 0.7)
	if flapping:
		updraft += 1.6 * (1.0 - carry_w * 0.5)
	var wind := _wind()
	# 상승기류 안의 공기는 바람과 함께 움직이므로 기둥 밖으로 밀려나지 않는다
	velocity = dir * speed + Vector3.UP * updraft + wind * (0.35 + 0.3 * (1.0 - tuck)) * (1.0 - 0.85 * thermal_k)
	# 고도 제한
	if global_position.y > WorldShape.MAX_ALT and velocity.y > 0.0:
		velocity.y *= 0.2
	var new_pos := global_position + velocity * delta
	# 경계: 바깥으로 나가면 되돌린다
	if not WorldShape.in_bounds(new_pos):
		var inward := WorldShape.inward(new_pos)
		# 정면으로 부딪혀도 한쪽으로 돌아 나가도록 옆 성분을 섞는다
		var side := dir.cross(Vector3.UP).normalized()
		if side.dot(inward) < 0.0:
			side = -side
		dir = dir.slerp((dir + inward * 2.0 + side).normalized(), 1.0 - exp(-2.5 * delta)).normalized()
		aim_yaw = lerp_angle(aim_yaw, atan2(-dir.x, -dir.z), 1.0 - exp(-3.0 * delta))
	global_position = new_pos
	# 뱅크 & 구르기
	var yaw_rate := old_dir.signed_angle_to(dir, Vector3.UP) / maxf(delta, 0.0001)
	var target_bank := clampf(-yaw_rate * 0.55, -1.25, 1.25)
	bank = lerpf(bank, target_bank, 1.0 - exp(-6.0 * delta))
	if absf(inp.roll) > 0.5 and _roll_left <= 0.0:
		_roll_dir = signf(inp.roll)
		_roll_left = TAU
		Sfx.play("whoosh", -10.0, 1.3)
		if _in_dive:
			_dive_rolls += 1
	if _roll_left > 0.0:
		var r := minf(_roll_left, 11.0 * delta)
		_roll_left -= r
		roll_spin += r * _roll_dir
	else:
		roll_spin = lerp_angle(roll_spin, 0.0, 1.0 - exp(-8.0 * delta))
	# 구애 비행 추적 (급강하 후 빠져나오기)
	var kmh := speed * 3.6
	GameState.record_speed(kmh)
	if tuck > 0.6 and dir.y < -0.5 and kmh > 120.0:
		if not _in_dive:
			_in_dive = true
			_dive_peak = 0.0
			_dive_rolls = 0
		_dive_peak = maxf(_dive_peak, kmh)
	elif _in_dive and dir.y > -0.1:
		_in_dive = false
		display_dive.emit(_dive_peak, _dive_rolls)
	accel_smooth = lerpf(accel_smooth, (speed - _prev_speed) / maxf(delta, 0.0001), 1.0 - exp(-5.0 * delta))
	_prev_speed = speed
	# 소리
	Sfx.wind_speed = clampf(speed / 105.0, 0.0, 1.0)
	Sfx.wind_tuck = tuck
	if flapping:
		_flap_sound_t -= delta
		if _flap_sound_t <= 0.0:
			_flap_sound_t = 0.22
			Sfx.play("flap", -9.0, randf_range(0.9, 1.1))
	# 충돌
	_check_ground(delta)


func _wind() -> Vector3:
	var main := get_tree().get_first_node_in_group("main")
	if main and main.day_night:
		return main.day_night.wind
	return Vector3.ZERO


func _compute_updraft() -> float:
	var p := global_position
	var up := 0.0
	in_thermal = false
	thermal_here = {}
	thermal_k = 0.0
	var main := get_tree().get_first_node_in_group("main")
	var tf := 1.0
	if main and main.day_night:
		tf = main.day_night.thermal_factor()
	for t in WorldShape.thermals:
		var tp: Vector3 = t.pos
		var d := Vector2(p.x - tp.x, p.z - tp.z).length()
		var r: float = t.r
		if d < r * 1.35 and p.y < tp.y + 650.0:
			var k := 1.0 - smoothstep(r * 0.75, r * 1.35, d)
			var top := 1.0 - smoothstep(tp.y + 450.0, tp.y + 650.0, p.y)
			up = maxf(up, float(t.power) * k * top * (0.35 + 0.65 * tf))
			if k > 0.3:
				in_thermal = true
			if k * top > thermal_k:
				thermal_k = k * top
				thermal_here = t
	# 능선 상승풍: 바람이 바다에서 절벽으로 불 때 절벽 앞 공기가 솟는다
	var wind := _wind()
	if wind.x < -1.0:
		var cz := p.z
		var cx := WorldShape.coast_x(cz)
		var dx := p.x - cx
		var cf := WorldShape.cliff_factor(cz)
		if cf > 0.3 and dx > -20.0 and dx < 140.0:
			var cliff_top := WorldShape.ground(cx - 40.0, cz)
			if p.y < cliff_top + 90.0:
				var k2 := (1.0 - smoothstep(0.0, 140.0, dx)) * cf
				up = maxf(up, absf(wind.x) * 0.9 * k2)
	# 먼 섬의 절벽: 바람이 부딪히는 쪽 절벽 앞에서 공기가 솟는다
	var wl := Vector2(wind.x, wind.z).length()
	if wl > 1.0:
		var isl := WorldShape.island_near(p, 150.0)
		if isl and isl.id != "seals":
			var wd := Vector3(wind.x, 0.0, wind.z) / wl
			var ahead := WorldShape.ground(p.x + wd.x * 45.0, p.z + wd.z * 45.0)
			var rise := ahead - WorldShape.floor_y(p.x, p.z)
			if rise > 15.0 and p.y < ahead + 80.0:
				var k3 := clampf(rise / 60.0, 0.0, 1.0) * (1.0 - smoothstep(ahead + 30.0, ahead + 80.0, p.y))
				up = maxf(up, wl * 0.9 * k3)
	return up


## 손을 뗐을 때의 도움: 상승기류 안에서는 자동 선회, 그 밖에서는 천천히 수평으로
func _assist_steering(delta: float, inp: Dictionary) -> void:
	var hands_off: bool = _aim_idle > 1.0 and input_enabled and not inp.flap and inp.tuck < 0.2 and not stalled
	# 먹잇감을 겨누고 있거나 크게 위아래로 겨눌 때는 끼어들지 않는다
	var aiming: bool = (assist_target != null and is_instance_valid(assist_target)) or absf(aim_pitch) > deg_to_rad(35.0)
	auto_circle = hands_off and not aiming and not thermal_here.is_empty() and thermal_k > 0.05
	if not auto_circle:
		_circle_sign = 0.0
		if hands_off and not aiming and _aim_idle > 1.5 and absf(aim_pitch) < deg_to_rad(30.0):
			aim_pitch = lerpf(aim_pitch, deg_to_rad(-4.0), 1.0 - exp(-0.5 * delta))
		return
	var c: Vector3 = thermal_here.pos
	var rel := Vector3(global_position.x - c.x, 0.0, global_position.z - c.z)
	if rel.length() < 1.0:
		rel = Vector3(-dir.z, 0.0, dir.x)
	var rn := rel.normalized()
	var tangent := Vector3.UP.cross(rn)
	if _circle_sign == 0.0:
		_circle_sign = 1.0 if tangent.dot(Vector3(dir.x, 0.0, dir.z)) >= 0.0 else -1.0
	tangent *= _circle_sign
	var want_r := float(thermal_here.r) * 0.5
	var radial := -rn * clampf((rel.length() - want_r) / want_r, -1.0, 1.0)
	var hd := (tangent + radial * 0.9).normalized()
	aim_yaw = lerp_angle(aim_yaw, atan2(-hd.x, -hd.z), 1.0 - exp(-2.5 * delta))
	aim_pitch = lerpf(aim_pitch, deg_to_rad(-8.0), 1.0 - exp(-1.5 * delta))   # 속도를 잃지 않게 살짝 숙인다


func _check_ground(_delta: float) -> void:
	var p := global_position
	var g := WorldShape.ground(p.x, p.z)
	var water := g < WorldShape.SEA
	var fy := maxf(g, WorldShape.SEA) + 0.3
	if WorldShape.hits_obstacle(p, 0.4):
		_crash(speed, false)
		return
	if p.y >= fy:
		return
	if water:
		if speed < 26.0 and dir.y > -0.55:
			# 수면 스치기
			global_position.y = fy + 0.15
			dir = Vector3(dir.x, absf(dir.y) * 0.4 + 0.18, dir.z).normalized()
			aim_pitch = maxf(aim_pitch, deg_to_rad(8.0))
			speed *= 0.82
			get_tree().call_group("main", "fx_splash", Vector3(p.x, 0.0, p.z), 0.6)
			Sfx.play_at("splash", p, -8.0, 1.3)
			return
		_crash(speed, true)
	else:
		if speed < 17.0 and dir.y > -0.6:
			global_position.y = g + 0.2
			var face := Vector3(dir.x, 0, dir.z).normalized()
			land_at({"pos": Vector3(p.x, g + 0.2, p.z), "kind": "ground", "facing": face}, true)
			return
		_crash(speed, false)


func _crash(impact: float, water: bool) -> void:
	var p := global_position
	var n := WorldShape.normal(p.x, p.z) if not water else Vector3.UP
	var into := clampf(-dir.dot(n) * 1.6, 0.35, 1.0)
	var dmg := maxf(impact - 14.0, 0.0) * 1.15 * into
	state = State.STUNNED
	_stun_t = 1.8
	var fy := WorldShape.floor_y(p.x, p.z)
	global_position.y = fy + 0.4
	speed = 0.0
	tuck = 0.0
	_in_dive = false
	if carrying:
		drop_prey(false)
	crashed.emit(impact, dmg)
	if water:
		get_tree().call_group("main", "fx_splash", Vector3(p.x, 0.0, p.z), 1.6)
		Sfx.play_at("splash", p, 2.0, 0.8)
	else:
		get_tree().call_group("main", "fx_dust", p)
	Sfx.play("crash", 0.0, 0.8)
	Sfx.play("boom", -4.0, 0.7)


func _stunned(delta: float) -> void:
	_stun_t -= delta
	var p := global_position
	global_position.y = lerpf(p.y, WorldShape.floor_y(p.x, p.z) + 0.3, 1.0 - exp(-8.0 * delta))
	if _stun_t <= 0.0:
		var water := WorldShape.is_water(p.x, p.z)
		var face := Vector3(dir.x, 0, dir.z)
		if face.length() < 0.1:
			face = Vector3.RIGHT
		if water:
			# 물에서는 허우적거리며 바로 날아오른다
			spawn_flying(p + Vector3.UP * 1.5, (face.normalized() + Vector3.UP * 0.5).normalized(), 12.0)
			took_off.emit()
		else:
			spawn_perched({"pos": Vector3(p.x, WorldShape.ground(p.x, p.z) + 0.2, p.z), "kind": "ground", "facing": face.normalized()})
			landed.emit(perch)


# ---------- 착지 / 이륙 ----------

func try_land() -> bool:
	if state != State.FLYING:
		return false
	var pr := WorldShape.nearest_perch(global_position, 14.0)
	if pr.is_empty() or speed > 30.0:
		return false
	land_at(pr, false)
	return true


func land_at(p: Dictionary, instant: bool) -> void:
	perch = p
	_land_from = global_position
	_land_t = 0.0
	state = State.PERCHED if instant else State.LANDING
	speed = 0.0
	tuck = 0.0
	stalled = false
	if instant:
		global_position = p.pos
		landed.emit(perch)
	Sfx.play("flap", -4.0, 0.8)


func _landing(delta: float) -> void:
	_land_t += delta / 0.55
	var t := smoothstep(0.0, 1.0, minf(_land_t, 1.0))
	var target: Vector3 = perch.pos
	var arc := sin(t * PI) * 1.5
	global_position = _land_from.lerp(target, t) + Vector3.UP * arc
	var to := target - _land_from
	to.y = 0.0
	if to.length() > 0.3:
		dir = dir.slerp(to.normalized(), 1.0 - exp(-8.0 * delta)).normalized()
	if _land_t >= 1.0:
		state = State.PERCHED
		var f: Vector3 = perch.get("facing", dir)
		set_heading(Vector3(f.x, 0, f.z).normalized() if Vector3(f.x, 0, f.z).length() > 0.1 else Vector3.RIGHT)
		Sfx.play("step", -6.0)
		landed.emit(perch)


func _perched(delta: float) -> void:
	stamina = minf(stamina + 30.0 * delta, max_stamina)
	Sfx.wind_speed = 0.0
	if not input_enabled:
		return
	if Input.is_action_just_pressed("flap") or Input.is_action_just_pressed("tuck"):
		take_off()


func take_off() -> void:
	var f := aim_dir()
	f.y = maxf(f.y, 0.05) + 0.12
	spawn_flying(global_position + Vector3.UP * 0.8, f.normalized(), 13.0)
	stamina = maxf(stamina - 8.0, 0.0)
	Sfx.play("flap", -3.0, 1.0)
	took_off.emit()


# ---------- 먹이 ----------

func grab(prey: Node3D) -> void:
	carrying = prey


func drop_prey(gentle: bool = true) -> Node3D:
	var p := carrying
	carrying = null
	if p and p.has_method("released"):
		p.released(velocity * (0.5 if gentle else 0.4))
	return p


func talon_point() -> Vector3:
	return global_transform * Vector3(0, -0.22 * BirdModel.VISUAL, 0.02)


# ---------- 모델 ----------

func _update_model(delta: float) -> void:
	if model == null:
		return
	var up := Vector3.UP
	var fwd := dir
	if state == State.PERCHED or state == State.LANDING or state == State.STUNNED:
		fwd = Vector3(dir.x, 0, dir.z).normalized() if Vector3(dir.x, 0, dir.z).length() > 0.01 else Vector3.FORWARD
	if absf(fwd.dot(up)) > 0.98:
		up = -aim_dir() if fwd.y < 0 else aim_dir()
		up = (up - fwd * fwd.dot(up)).normalized()
		if up.length() < 0.1:
			up = Vector3.BACK
	var b := Basis.looking_at(fwd, up)
	b = b * Basis(Vector3.FORWARD, -bank * (1.0 - 0.5 * tuck) + roll_spin)
	transform.basis = b
	# 날개 포즈
	var m := model
	match state:
		State.FLYING:
			m.perched = move_toward(m.perched, 0.0, delta * 4.0)
			m.fold = lerpf(m.fold, tuck * 0.97, 1.0 - exp(-14.0 * delta))
			if flapping:
				_flap_t += delta * 11.0
				m.flap_amp = lerpf(m.flap_amp, 0.75, 1.0 - exp(-10.0 * delta))
			elif stalled:
				_flap_t += delta * 14.0
				m.flap_amp = lerpf(m.flap_amp, 0.5, 1.0 - exp(-10.0 * delta))
			else:
				_flap_t += delta * 2.0
				m.flap_amp = lerpf(m.flap_amp, 0.03 + 0.04 * float(in_thermal), 1.0 - exp(-4.0 * delta))
			m.flap_phase = _flap_t
			m.sweep = -0.6 if braking else lerpf(0.0, 0.2, clampf(speed / 40.0, 0.0, 1.0))
			m.tail_spread = lerpf(m.tail_spread, (1.0 if braking or in_thermal else 0.0), 1.0 - exp(-6.0 * delta))
			m.talons_out = lerpf(m.talons_out, 1.0 if carrying else (0.7 if tuck > 0.8 and speed > 40.0 else 0.0), 1.0 - exp(-8.0 * delta))
		State.LANDING:
			_flap_t += delta * 12.0
			m.flap_phase = _flap_t
			m.flap_amp = 0.6
			m.fold = 0.0
			m.sweep = -0.8
			m.talons_out = 1.0
			m.tail_spread = 1.0
		State.PERCHED:
			m.perched = move_toward(m.perched, 1.0, delta * 3.0)
			m.fold = move_toward(m.fold, 1.0, delta * 3.0)
			m.flap_amp = move_toward(m.flap_amp, 0.0, delta * 3.0)
			m.sweep = 0.0
			m.tail_spread = 0.0
			m.talons_out = 0.0
		State.STUNNED:
			_flap_t += delta * 18.0
			m.flap_phase = _flap_t
			m.flap_amp = 0.9
			m.fold = 0.2
	m.pose(delta)


func kmh() -> float:
	return speed * 3.6


func is_flying() -> bool:
	return state == State.FLYING
