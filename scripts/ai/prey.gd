class_name Prey
extends Node3D
## 사냥감 새. 배회 → (매를 알아채면) 도주·회피 → 맞으면 기절해 추락 → 운반/먹힘.

enum S { FLY, FLEE, STUNNED, CARRIED, GROUND, WATER, SWIM, GONE }

const TYPES := {
	"pigeon": {"model": "pigeon", "cruise": 16.0, "max": 24.0, "agility": 0.55, "strike": 26.0, "food": 32.0, "weight": 0.35, "detect": 70.0, "juke": 10.0, "alt": [18.0, 85.0], "small": false},
	"starling": {"model": "starling", "cruise": 15.0, "max": 19.5, "agility": 0.7, "strike": 13.0, "food": 12.0, "weight": 0.1, "detect": 55.0, "juke": 8.0, "alt": [10.0, 55.0], "small": true},
	"sandpiper": {"model": "sandpiper", "cruise": 16.0, "max": 21.0, "agility": 0.72, "strike": 13.0, "food": 15.0, "weight": 0.12, "detect": 60.0, "juke": 9.0, "alt": [3.0, 35.0], "small": true},
	"duck": {"model": "duck", "cruise": 19.0, "max": 25.0, "agility": 0.3, "strike": 40.0, "food": 58.0, "weight": 0.7, "detect": 95.0, "juke": 6.0, "alt": [5.0, 45.0], "small": false, "water_escape": true},
	# 바다쇠오리: 수면 바로 위를 낮고 빠르게 난다. 매가 가까이 오면 물속으로 잠수한다
	"murrelet": {"model": "murrelet", "cruise": 19.0, "max": 25.0, "agility": 0.35, "strike": 18.0, "food": 24.0, "weight": 0.22, "detect": 75.0, "juke": 6.0, "alt": [2.5, 9.0], "small": false, "water_escape": true, "dive": true, "no_glide": true},
	# 박쥐: 해 질 녘 동굴에서 쏟아져 나온다. 지그재그로 날아 맞히기 어렵다
	"bat": {"model": "bat", "cruise": 10.0, "max": 15.0, "agility": 0.9, "strike": 6.0, "food": 7.0, "weight": 0.03, "detect": 30.0, "juke": 9.0, "alt": [6.0, 55.0], "small": true, "erratic": true, "no_glide": true},
}

var kind := "pigeon"
var t: Dictionary
var weak := false
var state := S.FLY
var vel := Vector3.ZERO
var flock = null
var boid := Vector3.ZERO
var home := Vector3.ZERO
var home_r := 300.0
var wander := Vector3.ZERO
var model: BirdModel
var weight := 0.3
var food := 20.0
var juke_cd := 0.0
var calm_t := 0.0
var idle_t := 0.0
var flap_t := 0.0
var glide_t := 0.0
var spin := Vector3.ZERO
var claimed := false
var carrier: Node3D = null
var prev := Vector3.ZERO
var _check_t := 0.0
var _swim_t := 0.0
var catch_lock := 0.0     # 맞은 직후 잠깐은 다시 잡을 수 없다(STRIKE 연출이 묻히지 않게)
var _err_t := 0.0
var _under := false       # 잠수 중
var _lod_n := randi() % 4
var _lod_acc := 0.0

const LOD_DIST := 700.0
static var focus := Vector3.ZERO   # 매 위치 (PreyManager가 매 프레임 갱신)


func setup(p_kind: String, pos: Vector3, p_home: Vector3, p_home_r: float) -> Prey:
	kind = p_kind
	t = TYPES[kind].duplicate()
	# 일부는 다치거나 늙은 개체: 둔하고 잘 못 알아챈다 (매의 눈으로 찾을 수 있다)
	weak = randf() < 0.15
	if weak:
		t["agility"] = float(t.agility) * 0.3
		t["detect"] = float(t.detect) * 0.6
		t["max"] = float(t.max) * 0.85
	weight = t.weight
	food = t.food
	home = p_home
	home_r = p_home_r
	position = pos
	prev = pos
	flap_t = randf() * 10.0
	model = BirdModel.new()
	add_child(model)
	model.setup(t.model)
	vel = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * t.cruise
	_new_wander()
	return self


func _new_wander() -> void:
	var a := randf() * TAU
	var r := sqrt(randf()) * home_r
	var p := home + Vector3(cos(a) * r, 0, sin(a) * r)
	var alt: Array = t.alt
	p.y = WorldShape.floor_y(p.x, p.z) + randf_range(alt[0], alt[1])
	wander = p


func is_loose() -> bool:
	return state == S.STUNNED or state == S.GROUND or state == S.WATER


func _process(delta: float) -> void:
	# 멀리서 그냥 날아다니는 새는 가끔만 계산한다 (보이지도 않고 맞을 일도 없다)
	if state == S.FLY and global_position.distance_squared_to(focus) > LOD_DIST * LOD_DIST:
		_lod_acc += delta
		_lod_n += 1
		if _lod_n % 4 != 0:
			return
		delta = _lod_acc
	_lod_acc = 0.0
	prev = global_position
	juke_cd -= delta
	catch_lock -= delta
	match state:
		S.FLY, S.FLEE:
			_fly(delta)
		S.STUNNED:
			_fall(delta)
		S.CARRIED:
			_carried(delta)
		S.GROUND:
			idle_t += delta
			if idle_t > 90.0:
				vanish()
		S.WATER:
			idle_t += delta
			position.y = sin(idle_t * 2.0) * 0.05 - 0.05 - maxf(idle_t - 25.0, 0.0) * 0.2
			if idle_t > 30.0:
				vanish()
		S.SWIM:
			_swim(delta)
	_animate(delta)


func _falcon() -> Falcon:
	var m := get_tree().get_first_node_in_group("main")
	return m.falcon if m else null


func _fly(delta: float) -> void:
	var p := global_position
	var desired: Vector3
	if state == S.FLY:
		if flock:
			desired = boid
		else:
			if p.distance_to(wander) < 30.0:
				_new_wander()
			desired = (wander - p).normalized() * float(t.cruise)
		_check_t -= delta
		if _check_t <= 0.0:
			_check_t = randf_range(0.12, 0.2)
			_awareness()
	else:
		desired = _flee_dir(delta)
	# 박쥐: 먹이를 쫓듯 불규칙하게 방향을 튼다
	if t.get("erratic", false):
		_err_t -= delta
		if _err_t <= 0.0:
			_err_t = randf_range(0.25, 0.6)
			vel += Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)) * 6.0
	# 고도 유지
	var gy := WorldShape.floor_y(p.x, p.z)
	var alt: Array = t.alt
	var above := p.y - gy
	if above < alt[0]:
		desired.y += (alt[0] - above) * 0.9
	elif above > alt[1] * 1.3 and state == S.FLY:
		desired.y -= (above - alt[1]) * 0.3
	if above < 2.0 and not (t.get("water_escape", false) and state == S.FLEE):
		desired.y = maxf(desired.y, 6.0)
	# 경계 밖으로 나가지 않게
	if not WorldShape.in_bounds(p, 70.0):
		desired += WorldShape.inward(p, 70.0) * 12.0
	var steer := 2.2 if state == S.FLEE else 1.3
	vel = vel.lerp(desired, 1.0 - exp(-steer * delta))
	var maxs: float = t.max if state == S.FLEE else float(t.cruise) * 1.2
	if vel.length() > maxs:
		vel = vel.normalized() * maxs
	position += vel * delta
	if WorldShape.hits_obstacle(position, 1.0):
		vel = -vel * 0.5 + Vector3.UP * 5.0
	if position.y < gy + 0.5:
		position.y = gy + 0.5
		vel.y = absf(vel.y)


func _awareness() -> void:
	var f := _falcon()
	if f == null or not f.is_flying():
		return
	var rel := f.global_position - global_position
	var d := rel.length()
	var range_k := 1.4 if f.speed < 20.0 else 1.0
	if d > float(t.detect) * range_k:
		return
	var from_above := rel.normalized().y > 0.5
	var fast := f.speed > 45.0
	var chance := 0.4
	if from_above and fast:
		chance = 0.06     # 위에서 빠르게 내리꽂으면 거의 못 알아챈다
	elif fast:
		chance = 0.2
	if d < 18.0:
		chance += 0.3
	if randf() < chance:
		alarm()


func alarm() -> void:
	if state != S.FLY:
		return
	state = S.FLEE
	calm_t = 0.0
	if flock:
		flock.alarm()
	if kind == "duck":
		Sfx.play_at("quack", global_position, -6.0, randf_range(0.9, 1.1), 200.0)


func _flee_dir(delta: float) -> Vector3:
	var f := _falcon()
	if f == null:
		state = S.FLY
		return vel
	var p := global_position
	var rel := f.global_position - p
	var d := rel.length()
	var away := -rel.normalized()
	var desired := (away * 0.8 + vel.normalized() * 0.6).normalized() * float(t.max)
	if flock:
		desired = desired * 0.6 + boid * 0.4
	# 오리는 물로 뛰어든다. 바다쇠오리는 매가 가까이 와야 잠수한다
	if t.get("water_escape", false) and WorldShape.is_water(p.x, p.z) and (not t.get("dive", false) or d < 35.0):
		desired.y = -12.0
		if p.y < 1.2:
			_start_swim()
			return Vector3.ZERO
	# 회피(급선회): 부딪히기 직전에 옆으로 튄다
	var rv := f.velocity - vel
	var rv2 := rv.length_squared()
	if rv2 > 1.0 and juke_cd <= 0.0:
		# rel: 먹잇감 기준 매의 상대 위치, rv: 상대 속도 → 최근접 시각
		var tca := -rel.dot(rv) / rv2
		if tca > 0.0 and tca < 0.55:
			var closest := rel + rv * tca
			if closest.length() < 7.0:
				# 한 번의 접근에 한 번만 판정한다
				juke_cd = 1.2
				if randf() < float(t.agility):
					_juke(f.velocity)
	if d > 170.0:
		calm_t += delta
		if calm_t > 4.0:
			state = S.FLY
			_new_wander()
	else:
		calm_t = 0.0
	return desired


func _juke(threat_vel: Vector3) -> void:
	juke_cd = 1.2
	var side := threat_vel.cross(Vector3.UP)
	if side.length() < 0.1:
		side = Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
	side = side.normalized() * (1.0 if randf() < 0.5 else -1.0)
	var j: float = t.juke
	vel += side * j + Vector3.UP * randf_range(-0.6, 0.8) * j * 0.7
	Sfx.play_at("flap", global_position, -4.0, 1.4, 120.0)


func _start_swim() -> void:
	state = S.SWIM
	position.y = 0.05
	vel = Vector3(vel.x, 0, vel.z) * 0.2
	_swim_t = 0.0
	if t.get("dive", false):
		_under = true
		position.y = -2.0
		vel = Vector3(vel.x, 0, vel.z).normalized() * 4.0
	get_tree().call_group("main", "fx_splash", global_position, 0.7)
	Sfx.play_at("splash", global_position, -6.0, 1.4, 250.0)


func _swim(delta: float) -> void:
	_swim_t += delta
	position += vel * delta
	if _under:
		# 물속에서 몇 초 헤엄치다 다른 곳으로 떠오른다
		position.y = -2.0
		if _swim_t > 5.0:
			_under = false
			position.y = 0.05
			Sfx.play_at("splash", global_position, -12.0, 1.8, 150.0)
		return
	vel = vel.lerp(Vector3.ZERO, delta * 0.5)
	position.y = sin(_swim_t * 1.7) * 0.04
	var f := _falcon()
	if _swim_t > 8.0 and (f == null or f.global_position.distance_to(global_position) > 160.0):
		state = S.FLY
		vel = Vector3(randf_range(-1, 1), 0.6, randf_range(-1, 1)).normalized() * 10.0
		_new_wander()


func _fall(delta: float) -> void:
	vel += Vector3.DOWN * 12.0 * delta
	vel = vel.lerp(Vector3(0, vel.y, 0), 1.0 - exp(-0.6 * delta))
	if vel.y < -30.0:
		vel.y = -30.0
	position += vel * delta
	rotation += spin * delta
	var p := global_position
	var g := WorldShape.ground(p.x, p.z)
	if g < WorldShape.SEA:
		if p.y <= 0.05:
			state = S.WATER
			idle_t = 0.0
			position.y = 0.0
			get_tree().call_group("main", "fx_splash", p, 0.5)
			Sfx.play_at("splash", p, -8.0, 1.6, 200.0)
	elif p.y <= g + 0.1:
		state = S.GROUND
		idle_t = 0.0
		position.y = g + 0.08
		rotation = Vector3(0, rotation.y, PI * 0.5)
		Sfx.play_at("thud", p, -8.0, 1.4, 150.0)


func _carried(_delta: float) -> void:
	if carrier == null or not is_instance_valid(carrier):
		released(Vector3.ZERO)
		return
	if carrier.has_method("talon_point"):
		global_position = carrier.talon_point()
	else:
		global_position = carrier.global_position + Vector3.DOWN * 0.3
	global_basis = carrier.global_basis * Basis(Vector3.FORWARD, PI)


## 누군가 발로 잡았다
func take(by: Node3D) -> void:
	state = S.CARRIED
	carrier = by
	claimed = false
	if flock:
		flock.remove(self)
		flock = null


## 발에서 놓였다(죽은 먹이가 떨어진다)
func released(v: Vector3) -> void:
	carrier = null
	state = S.STUNNED
	vel = v
	spin = Vector3(randf_range(-6, 6), randf_range(-4, 4), randf_range(-6, 6))


## 공중에서 맞았다
func knock(v: Vector3) -> void:
	state = S.STUNNED
	catch_lock = 0.7
	vel = v
	spin = Vector3(randf_range(-14, 14), randf_range(-8, 8), randf_range(-14, 14))
	if flock:
		flock.alarm()
		flock.remove(self)
		flock = null


func vanish() -> void:
	state = S.GONE
	if flock:
		flock.remove(self)
		flock = null
	queue_free()


func _animate(delta: float) -> void:
	if model == null:
		return
	match state:
		S.FLY, S.FLEE:
			var fast := state == S.FLEE
			glide_t -= delta
			if glide_t < -2.5:
				glide_t = randf_range(0.6, 2.0)
			var gliding: bool = glide_t > 0.0 and not fast and kind != "duck" and not t.get("no_glide", false)
			flap_t += delta * (0.0 if gliding else (16.0 if fast else 11.0) * (1.4 if weight < 0.2 else 1.0))
			model.flap_phase = flap_t
			model.flap_amp = lerpf(model.flap_amp, 0.05 if gliding else 0.75, 1.0 - exp(-8.0 * delta))
			model.fold = 0.0
			if vel.length() > 0.5:
				var up := Vector3.UP
				var fwd := vel.normalized()
				if absf(fwd.dot(up)) < 0.97:
					var bank := clampf(-boid.cross(vel).y * 0.002, -0.8, 0.8)
					global_basis = global_basis.slerp(Basis.looking_at(fwd, up) * Basis(Vector3.FORWARD, bank), 1.0 - exp(-8.0 * delta)).orthonormalized()
		S.STUNNED:
			model.flap_amp = 0.3
			flap_t += delta * 6.0
			model.flap_phase = flap_t
			model.fold = 0.3
		S.CARRIED, S.GROUND, S.WATER:
			model.flap_amp = 0.0
			model.fold = 0.2
		S.SWIM:
			model.flap_amp = 0.0
			model.fold = 1.0
			model.perched = 0.3
			if vel.length() > 0.2:
				global_basis = Basis.looking_at(Vector3(vel.x, 0, vel.z).normalized(), Vector3.UP)
	model.pose(delta)
