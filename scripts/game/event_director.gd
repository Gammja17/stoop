class_name EventDirector
extends Node
## 돌발 이벤트와 제한시간 도전. 1~2분마다 하나씩 벌어진다. 성공하면 경험.

const CHALLENGES := ["fast_kill", "climb", "two_kills", "speed_330", "roll_dive"]
const XP := {"golden": 150, "race": 90, "thief": 70, "fast_kill": 120, "climb": 60, "two_kills": 100, "speed_330": 80, "roll_dive": 70}
const TIME := {"golden": 90.0, "race": 60.0, "thief": 45.0, "fast_kill": 45.0, "climb": 25.0, "two_kills": 60.0, "speed_330": 45.0, "roll_dive": 45.0}

var main
var cur := ""
var left := 0.0
var _next := 60.0
var _kills := 0
var golden: Prey
var hunter: HunterFalcon
var race_flock: Flock
var thief: Gull
var thief_prey: Prey
var _stolen := false


func setup(p_main) -> void:
	main = p_main


func reset() -> void:
	_end_quiet()
	_next = 60.0


func update(delta: float) -> void:
	if cur == "":
		_next -= delta
		if _next <= 0.0:
			_start()
		return
	left -= delta
	match cur:
		"golden":
			if golden == null or not is_instance_valid(golden) or golden.state == Prey.S.GONE:
				_fail()
				return
		"race":
			if hunter and is_instance_valid(hunter) and hunter.done:
				_fail()
				return
		"thief":
			if thief and is_instance_valid(thief) and thief.prey and is_instance_valid(thief.prey):
				thief_prey = thief.prey
				_stolen = true
		"climb":
			if _agl() >= 400.0:
				_success()
				return
		"speed_330":
			if main.falcon.kmh() >= 330.0:
				_success()
				return
	if left <= 0.0:
		# 도둑 까마귀에게 끝까지 안 뺏겼으면 성공
		if cur == "thief" and not _stolen and main.falcon.carrying:
			_success()
		else:
			_fail(true)


func _agl() -> float:
	var p: Vector3 = main.falcon.global_position
	return p.y - WorldShape.floor_y(p.x, p.z)


func _eligible() -> Array:
	if main.day_night.is_night():
		return ["climb", "speed_330"]   # 밤엔 새가 드물다
	var out: Array = CHALLENGES.duplicate()
	out += ["golden", "golden", "race", "race"]
	if main.falcon.carrying:
		out += ["thief", "thief", "thief"]
	return out


func _start() -> void:
	var list := _eligible()
	var id: String = list[randi() % list.size()]
	cur = id
	left = TIME[id]
	_kills = 0
	_stolen = false
	match id:
		"golden":
			_spawn_golden()
		"race":
			_spawn_race()
		"thief":
			_spawn_thief()
	main.hud.popup(Loc.t("ev_" + id), Loc.t("ev_" + id + "_d"), Color(1, 0.85, 0.3), 2.4)
	GameState.say(Loc.t("ev_" + id) + " — " + Loc.t("ev_" + id + "_d"), "gold")
	Sfx.play("chime", -2.0, 1.2)


func _ahead(dist: float) -> Vector3:
	var f: Falcon = main.falcon
	var d := Vector3(f.dir.x, 0.0, f.dir.z)
	if d.length() < 0.1:
		d = Vector3.RIGHT
	d = d.normalized().rotated(Vector3.UP, randf_range(-0.8, 0.8))
	var p := f.global_position + d * dist
	# 먼 바다·경계 밖이면 본섬 쪽으로
	if not WorldShape.in_bounds(p, 150.0) or WorldShape.ground(p.x, p.z) < -20.0:
		p = f.global_position.lerp(Vector3(-300, 0, 0), 0.4)
	p.y = 0.0
	return p


func _spawn_golden() -> void:
	var spot := _ahead(380.0)
	var fl: Flock = main.prey_mgr.spawn_group("golden", spot, spot, 260.0, 1, "golden_ev")
	golden = fl.members[0]


func _spawn_race() -> void:
	var spot := _ahead(320.0)
	race_flock = main.prey_mgr.spawn_group("pigeon", spot, spot, 160.0, 6, "race_ev")
	for m in race_flock.members:
		m.set_meta("race", true)
	var hp := spot + Vector3(90, WorldShape.floor_y(spot.x, spot.z) + 130.0, 40)
	hunter = HunterFalcon.new().setup(hp, race_flock)
	main.add_child(hunter)


func _spawn_thief() -> void:
	var f: Falcon = main.falcon
	var a := randf() * TAU
	var c := f.global_position + Vector3(cos(a) * 160.0, 30.0, sin(a) * 160.0)
	thief = Gull.new().setup(c, "crow")
	main.prey_mgr.add_child(thief)
	main.prey_mgr.gulls.append(thief)
	thief.global_position = c
	thief.state = Gull.G.HARASS
	thief._harass_t = -40.0


func _success() -> void:
	var xp: int = XP[cur]
	main.hud.popup(Loc.t("ev_success"), Loc.t("ev_" + cur) + "   +%d" % xp, Color(0.7, 1.0, 0.6), 2.0)
	Sfx.play("chime_big", -2.0)
	main.gain_xp(xp)
	var st := GameState.stats()
	st["challenges"] = int(st.get("challenges", 0)) + 1
	if cur == "golden":
		Records.unlock("golden")
	if int(st["challenges"]) >= 10:
		Records.unlock("challenger")
	_end()


func _fail(timeout: bool = false) -> void:
	GameState.say(Loc.t("ev_timeout") % Loc.t("ev_" + cur) if timeout else Loc.t("ev_fail_" + cur), "info")
	_end()


func _end() -> void:
	_end_quiet()
	_next = randf_range(80.0, 140.0)


func _end_quiet() -> void:
	if golden and is_instance_valid(golden) and golden.state in [Prey.S.FLY, Prey.S.FLEE]:
		golden.vanish()
	if hunter and is_instance_valid(hunter) and not hunter.done:
		hunter.queue_free()
	if thief and is_instance_valid(thief):
		if thief.prey and is_instance_valid(thief.prey) and thief.state == Gull.G.CARRY:
			thief.prey.vanish()
		main.prey_mgr.gulls.erase(thief)
		thief.queue_free()
	golden = null
	hunter = null
	race_flock = null
	thief = null
	thief_prey = null
	cur = ""


# ---------- 훅 ----------

func on_kill(p: Prey, kmh: float) -> void:
	match cur:
		"golden":
			if p == golden:
				_success()
		"race":
			if p.get_meta("race", false):
				_success()
		"fast_kill":
			if kmh >= 250.0:
				_success()
		"two_kills":
			_kills += 1
			if _kills >= 2:
				_success()


func on_catch(p: Prey) -> void:
	if cur == "thief" and p == thief_prey:
		_success()


func on_display(_peak: float, rolls: int) -> void:
	if cur == "roll_dive" and rolls >= 3:
		_success()


func objective() -> Dictionary:
	if cur == "":
		return {}
	return {"text": Loc.t("ev_" + cur) + " — %d" % int(ceil(left)) + Loc.t("sec")}


func markers() -> Array:
	var out := []
	if golden and is_instance_valid(golden) and golden.state != Prey.S.GONE:
		out.append({"pos": golden.global_position, "color": Color(1.0, 0.8, 0.2), "label": Loc.t("mk_golden")})
	if hunter and is_instance_valid(hunter) and not hunter.done:
		out.append({"pos": hunter.global_position, "color": Color(1.0, 0.45, 0.3), "label": Loc.t("mk_hunter")})
	if race_flock and is_instance_valid(race_flock) and not race_flock.members.is_empty():
		out.append({"pos": race_flock.centroid, "color": Color(0.8, 1.0, 0.6), "label": Loc.t("mk_race")})
	if thief and is_instance_valid(thief):
		out.append({"pos": thief.global_position, "color": Color(1.0, 0.3, 0.25), "label": Loc.t("mk_thief")})
	return out
