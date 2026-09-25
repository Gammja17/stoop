class_name Mobber
extends AIFalcon
## 매를 괴롭히는 새: 본섬의 까마귀 떼, 바닷새섬 번식지의 갈매기.
## 매가 느리고 낮게 가까이 오면(또는 앉아 있으면) 떼로 몰려와 쪼아 댄다. 들이받으면 물러난다.

enum M { IDLE, MOB, FLEE }

var species := "crow"
var mode := M.IDLE
var home := Vector3.ZERO
var home_r := 80.0
var alt := 25.0
var trigger_r := 110.0
var active := true          # 밤, 비번식기에는 덤비지 않는다
var group: Array = []       # 같이 몰려드는 무리 (공유 배열)
var _angle := 0.0
var _think := 0.0
var _mob_t := 0.0
var _flee_t := 0.0
var _call_t := 0.0
var _peck_cd := 0.0
var _orbit := 0.0
var _lod_n := randi() % 4
var _lod_acc := 0.0


func setup(sp: String, p_home: Vector3, r: float, p_alt: float, p_group: Array) -> Mobber:
	species = sp
	home = p_home
	home_r = r
	alt = p_alt
	group = p_group
	group.append(self)
	_angle = randf() * TAU
	_orbit = randf() * TAU
	position = home + Vector3(cos(_angle) * r, 0, sin(_angle) * r)
	position.y = WorldShape.floor_y(position.x, position.z) + alt
	init_model("crow" if sp == "crow" else "gull")
	return self


func _process(delta: float) -> void:
	_think -= delta
	_call_t -= delta
	_peck_cd -= delta
	var m = main_node()
	if m == null:
		return
	var f: Falcon = m.falcon
	if mode == M.IDLE and global_position.distance_squared_to(f.global_position) > 800.0 * 800.0:
		_lod_acc += delta
		_lod_n += 1
		if _lod_n % 4 != 0:
			return
		delta = _lod_acc
	_lod_acc = 0.0
	match mode:
		M.IDLE:
			_angle += delta * 10.0 / home_r
			var tp := home + Vector3(cos(_angle) * home_r, 0, sin(_angle * 1.3) * home_r * 0.7)
			tp.y = WorldShape.floor_y(tp.x, tp.z) + alt + sin(_angle * 3.0) * 5.0
			steer((tp - global_position).normalized() * 10.0, delta, 1.2)
			if _think <= 0.0:
				_think = randf_range(0.5, 0.9)
				if active and _provoked(f):
					for g in group:
						if is_instance_valid(g):
							g.start_mob()
					m.mobbed_start(self)
		M.MOB:
			_mob_t += delta
			_orbit += delta * 2.2
			var fp := f.global_position + f.velocity * 0.35
			var ring := Vector3(cos(_orbit) * 6.0, 2.5 + sin(_orbit * 1.7) * 2.0, sin(_orbit) * 6.0)
			var tgt := fp + ring
			# 가끔 곧장 달려들어 쫀다
			if _peck_cd <= 0.0 and fmod(_mob_t + _orbit, 3.0) < 0.9:
				tgt = f.global_position
			var top := 17.0 if species == "crow" else 18.5
			steer((tgt - global_position).normalized() * top, delta, 2.6)
			if _call_t <= 0.0:
				_call_t = randf_range(0.6, 1.4)
				Sfx.play_at("caw" if species == "crow" else "gull", global_position, -2.0, randf_range(0.9, 1.15), 250.0)
			if _peck_cd <= 0.0 and global_position.distance_to(f.global_position) < 2.2:
				_peck_cd = randf_range(2.5, 4.0)
				vel += (global_position - f.global_position).normalized() * 9.0 + Vector3.UP * 4.0
				m.mobbed_peck(self)
			if _mob_t > 18.0 or not active or _escaped(f):
				mode = M.IDLE
		M.FLEE:
			_flee_t -= delta
			var away := global_position - f.global_position
			away.y = 0.0
			steer(away.normalized() * 16.0 + Vector3.UP * 3.0, delta, 1.5)
			if _flee_t <= 0.0:
				mode = M.IDLE
	animate(delta)


## 매가 무리 영역에 느리고 낮게 들어오면 덤빈다
func _provoked(f: Falcon) -> bool:
	if f == null or f.state == Falcon.State.FROZEN or f.state == Falcon.State.STUNNED:
		return false
	var hd := Vector2(f.global_position.x - home.x, f.global_position.z - home.z).length()
	if hd > trigger_r:
		return false
	var agl := f.global_position.y - WorldShape.floor_y(f.global_position.x, f.global_position.z)
	if f.state == Falcon.State.PERCHED:
		return f.perch.get("kind", "") != "eyrie"
	return agl < alt + 45.0 and f.speed < 30.0


func _escaped(f: Falcon) -> bool:
	var hd := Vector2(f.global_position.x - home.x, f.global_position.z - home.z).length()
	var agl := f.global_position.y - WorldShape.floor_y(f.global_position.x, f.global_position.z)
	return hd > trigger_r * 2.5 or agl > alt + 140.0 or (f.is_flying() and f.speed > 42.0)


func start_mob() -> void:
	if mode == M.FLEE:
		return
	mode = M.MOB
	_mob_t = randf_range(0.0, 2.0)
	_peck_cd = randf_range(1.0, 3.0)


func knocked(from_vel: Vector3) -> void:
	mode = M.FLEE
	_flee_t = 15.0
	vel = from_vel * 0.3 + Vector3.UP * 6.0
	Sfx.play_at("caw" if species == "crow" else "gull", global_position, 4.0, 1.4, 400.0)
	# 한 마리가 맞으면 나머지도 기가 꺾인다
	for g in group:
		if is_instance_valid(g) and g != self and g.mode == M.MOB and randf() < 0.6:
			g.mode = M.IDLE
