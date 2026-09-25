class_name LifeDirector
extends Node
## 송골매의 한 해: 봄(영역·구애·알) → 여름(새끼 먹이기·수리부엉이) → 가을(사냥 가르치기·독립) → 겨울(버티기).
## 목표 표시, 튜토리얼, 계절 전환, 혈통 이어가기를 여기서 관리한다.

const NAMES_M := ["바람", "번개", "칼날", "해동", "비호", "천둥", "여울", "돌개", "한결", "매서"]
const NAMES_F := ["하늘", "송이", "새벽", "노을", "누리", "별빛", "가람", "은빛", "단비", "나래"]

var main
var nest: Nest
var mate: MateBird = null
var rival: RivalFalcon = null
var owl: OwlRaider = null
var fledglings: Array = []
var _mate_food_t := 90.0
var _call_cd := 0.0
var _display_cd := 0.0
var _owl_tonight := false
var _obj_t := 0.0
var _mate_spawn_t := -1.0
var _year_fledged := 0


func setup(p_main) -> void:
	main = p_main
	add_to_group("life")
	nest = Nest.new()
	main.add_child(nest)
	nest.setup()


func L() -> Dictionary:
	return GameState.life()


func season() -> int:
	return int(GameState.data.get("season", 0))


func reset_actors() -> void:
	for a in [mate, rival, owl]:
		if a and is_instance_valid(a):
			a.queue_free()
	mate = null
	rival = null
	owl = null
	for f in fledglings:
		if is_instance_valid(f):
			f.queue_free()
	fledglings.clear()
	_owl_tonight = false
	_mate_spawn_t = -1.0


func begin(fresh: bool, new_gen: bool) -> void:
	reset_actors()
	nest.refresh()
	var l := L()
	if l.mate.get("has", false):
		_spawn_mate(true)
	elif season() == 0 and l.get("territory", false):
		_spawn_mate(false)
	if season() == 2:
		_spawn_fledglings()
	main.hud.hide_hint()
	_season_card()
	if new_gen:
		GameState.say(Loc.t("new_gen") % [GameState.falcon().get("name", ""), int(GameState.data.get("generation", 1))], "gold")
	_refresh_objectives()
	GameState.data.erase("dead")
	GameState.save_game()


# ---------- 매 프레임 ----------

func update(delta: float) -> void:
	_call_cd -= delta
	_display_cd -= delta
	_update_chicks(delta)
	_update_fledglings_hunger(delta)
	_check_combat()
	if _mate_spawn_t > 0.0:
		_mate_spawn_t -= delta
		if _mate_spawn_t <= 0.0 and mate == null and season() == 0:
			_spawn_mate(false)
			GameState.say(Loc.t("mate_appears"), "gold")
			Sfx.play("chime", -4.0)
	_obj_t -= delta
	if _obj_t <= 0.0:
		_obj_t = 0.5
		_refresh_objectives()
		_one_time_hints()


func _check_combat() -> void:
	var f: Falcon = main.falcon
	if f.state != Falcon.State.FLYING:
		return
	var a := f._prev_pos
	var b := f.global_position
	if rival and is_instance_valid(rival) and rival.mode != RivalFalcon.R.LEAVE:
		if PreyManager.seg_dist(a - rival.prev, b - rival.global_position) < 4.5 and f.speed > 18.0:
			rival.take_hit(f.velocity)
			L()["rival_hits"] = rival.hits
			_combat_juice(rival.global_position, "rival")
			main.hud.popup(Loc.t("hit_rival"), "%d / %d" % [rival.hits, rival.need_hits], Color(1, 0.8, 0.3), 0.8)
	if owl and is_instance_valid(owl) and owl.mode != OwlRaider.O.FLEE:
		if PreyManager.seg_dist(a - owl.prev, b - owl.global_position) < 3.2 and f.speed > 18.0:
			owl.take_hit(f.velocity)
			_combat_juice(owl.global_position, "owl")
			main.hud.popup(Loc.t("hit_owl"), "%d / 2" % owl.hits, Color(1, 0.8, 0.3), 0.8)


func _combat_juice(pos: Vector3, who: String) -> void:
	var f: Falcon = main.falcon
	var sp: Dictionary = BirdModel.resolve("rival" if who == "rival" else "owl")
	Fx.feathers(main.fx_root, pos, f.velocity, sp.back, sp.belly, 40, 0.9)
	Fx.ring(main.fx_root, pos, f.dir, 5.0, Color(1, 0.9, 0.8, 0.7))
	Sfx.play("hit", 0.0, 0.9)
	Sfx.play("boom", -4.0, 0.9)
	main.camera.add_trauma(0.6)
	main.camera.punch(-12.0)
	main._flash = 0.3
	f.speed *= 0.65


# ---------- 힌트 ----------

func _one_time_hints() -> void:
	if not Settings.hints:
		return
	var fd := GameState.falcon()
	if float(fd.get("energy", 50.0)) < 30.0 and not GameState.flag("hint_hungry"):
		GameState.set_flag("hint_hungry")
		GameState.say(Loc.t("hint_hungry"), "warn")
	if main.day_night.is_night() and not GameState.flag("hint_night"):
		GameState.set_flag("hint_night")
		GameState.say(Loc.t("hint_night"), "info")
	var f: Falcon = main.falcon
	if f.is_flying() and f.global_position.y > 180.0 and not GameState.flag("hint_islands"):
		GameState.set_flag("hint_islands")
		GameState.say(Loc.t("hint_islands"), "info")


# ---------- 새끼 ----------

func alive_chicks() -> Array:
	var out := []
	for c in L().get("chicks", []):
		if c.get("alive", true):
			out.append(c)
	return out


func _update_chicks(delta: float) -> void:
	var chicks := alive_chicks()
	if chicks.is_empty():
		return
	var rate := 0.075
	if float(main.day_night.cur.get("rain", 0.0)) > 0.3:
		rate = 0.1
	var died := false
	for c in chicks:
		var food := float(c.get("food", 60.0)) - rate * delta
		if food <= 0.0:
			food = 0.0
			c["starve"] = float(c.get("starve", 0.0)) + delta
			if c.starve > 100.0:
				c["alive"] = false
				died = true
		else:
			c["starve"] = maxf(float(c.get("starve", 0.0)) - delta, 0.0)
		c["food"] = food
	if died:
		GameState.say(Loc.t("chick_starved"), "warn")
		nest.refresh()
	# 짝도 가끔 먹이를 물어온다
	if L().mate.get("has", false):
		_mate_food_t -= delta
		if _mate_food_t <= 0.0:
			_mate_food_t = randf_range(120.0, 170.0)
			feed_chicks(22.0)
			GameState.say(Loc.t("mate_brought"), "good")
	if not GameState.flag("hint_chicks") and Settings.hints:
		GameState.set_flag("hint_chicks")
		GameState.say(Loc.t("hint_chicks"), "gold")


func feed_chicks(amount: float) -> void:
	var chicks := alive_chicks()
	if chicks.is_empty():
		return
	var left := amount
	while left > 0.5:
		var hungriest = chicks[0]
		for c in chicks:
			if float(c.get("food", 0.0)) < float(hungriest.get("food", 0.0)):
				hungriest = c
		if float(hungriest.get("food", 0.0)) >= 100.0:
			break
		var give := minf(10.0, left)
		hungriest["food"] = minf(float(hungriest.get("food", 0.0)) + give, 100.0)
		left -= give


func _update_fledglings_hunger(delta: float) -> void:
	for fd in L().get("fledglings", []):
		fd["food"] = maxf(float(fd.get("food", 60.0)) - 0.05 * delta, 0.0)


# ---------- 배우 생성 ----------

func _mate_spec() -> String:
	return "falcon" if GameState.is_male() == false else "falcon_f"


func _spawn_mate(paired: bool) -> void:
	if mate and is_instance_valid(mate):
		return
	var start := WorldShape.eyrie + Vector3(120, 80, -60) if not paired else WorldShape.eyrie
	mate = MateBird.new().setup(_mate_spec(), start)
	main.add_child(mate)
	if paired:
		mate.global_position = mate.nest_spot()
		mate.perched = true
		mate.mode = MateBird.M.NEST
		mate.perch_pos = mate.nest_spot()
		mate.perch_facing = WorldShape.eyrie_facing
	else:
		mate.mode = MateBird.M.COURT


func _spawn_rival() -> void:
	if rival and is_instance_valid(rival):
		return
	var need := 2 + mini(int(GameState.data.get("year", 1)) / 2, 2)
	rival = RivalFalcon.new().setup(WorldShape.eyrie + Vector3(150, 140, 80), need)
	main.add_child(rival)
	rival.hit_player.connect(_on_rival_hit_player)
	rival.defeated.connect(_on_rival_defeated)
	GameState.say(Loc.t("rival_appears"), "warn")
	Sfx.play("screech", 0.0)


func _spawn_owl() -> void:
	if owl and is_instance_valid(owl):
		return
	var start := WorldShape.eyrie + Vector3(-520, 70, randf_range(-200, 200))
	start.y = WorldShape.floor_y(start.x, start.z) + 60.0
	owl = OwlRaider.new().setup(start)
	main.add_child(owl)
	owl.reached_nest.connect(_on_owl_reached)
	owl.driven_off.connect(_on_owl_driven)
	GameState.say(Loc.t("owl_coming"), "warn")


func _spawn_fledglings() -> void:
	var i := 0
	for fd in L().get("fledglings", []):
		var fl: Fledgling = Fledgling.new().setup(fd, i)
		main.add_child(fl)
		fl.lesson.connect(_on_lesson.bind(fl))
		fledglings.append(fl)
		i += 1


# ---------- 이벤트 훅 ----------

func on_hour(h: int) -> void:
	if season() == 0 and not L().get("territory", false) and rival == null:
		var first := int(GameState.data.get("generation", 1)) == 1 and int(GameState.data.get("year", 1)) == 1 and int(GameState.data.get("day", 1)) == 1
		var start_h := 11 if first else 9
		if h >= start_h and h < 19:
			_spawn_rival()
	if h == 21 and _owl_tonight and owl == null:
		_spawn_owl()
	if h == 6:
		main.prey_mgr.clear_bats()


func on_dusk() -> void:
	var s := season()
	if s == 1 or s == 2:
		main.prey_mgr.emerge_bats()
		GameState.say(Loc.t("bats_emerge"), "gold")
	if (s == 0 or s == 2) and randf() < 0.6:
		var c := WorldShape.fields + Vector3(250, 0, 150)
		main.prey_mgr.spawn_group("starling", c, c, 300.0, 45, "murmuration")
		GameState.say(Loc.t("murmuration"), "gold")


func on_nightfall() -> void:
	if season() == 1 and not alive_chicks().is_empty() and randf() < 0.65:
		_owl_tonight = true


func on_new_day() -> void:
	var d := GameState.data
	GameState.stats()["days"] = int(GameState.stats().get("days", 0)) + 1
	d["day"] = int(d.get("day", 1)) + 1
	_owl_tonight = false
	if owl and is_instance_valid(owl):
		owl.queue_free()
		owl = null
	if int(d["day"]) > GameState.season_days():
		_end_season()
		return
	_daily_events()
	_new_weather()
	_refresh_objectives()
	GameState.save_game()


func _new_weather() -> void:
	var w: String = main.day_night.pick_weather()
	main.day_night.apply_weather(w)
	main.world.set_wet(1.0 if w == "rain" else 0.0)
	GameState.say(Loc.t("weather_today") % Loc.t("weather_" + w), "info")


func _daily_events() -> void:
	var l := L()
	var s := season()
	if s == 0 and l.mate.get("has", false) and int(l.get("eggs", 0)) == 0 and alive_chicks().is_empty():
		l["eggs"] = randi_range(3, 4)
		GameState.say(Loc.t("eggs_laid") % int(l.eggs), "gold")
		Sfx.play("chime_big", -4.0)
		nest.refresh()
		if mate:
			mate.go_nest()
	if s == 1:
		for c in alive_chicks():
			c["growth"] = minf(float(c.get("growth", 0.0)) + 0.25 * clampf(float(c.get("food", 50.0)) / 60.0, 0.3, 1.0), 1.0)
		nest.refresh()
	if s == 2 and int(GameState.data.get("day", 1)) == 2:
		var c := WorldShape.bay
		main.prey_mgr.spawn_group("sandpiper", c, c, 350.0, 40, "migration")
		main.prey_mgr.spawn_group("sandpiper", c + Vector3(80, 0, 120), c, 350.0, 35, "migration")
		GameState.say(Loc.t("migration"), "gold")


func _end_season() -> void:
	var d := GameState.data
	var l := L()
	var s := season()
	match s:
		0:
			var eggs := int(l.get("eggs", 0))
			var late: bool = eggs == 0 and l.mate.get("has", false)
			if eggs > 0 or late:
				var fed := int(l.get("incubation_food", 0))
				# 봄 막바지에 짝을 맺었으면 늦둥이 두 마리만
				var hatched := 2 if late else maxi(eggs - maxi(0, 2 - fed), 1)
				var chicks := []
				for i in hatched:
					var sex := "m" if randf() < 0.5 else "f"
					var nm: String = (NAMES_M if sex == "m" else NAMES_F)[randi() % 10]
					chicks.append({"name": nm, "sex": sex, "food": 70.0, "growth": 0.0, "alive": true})
				l["chicks"] = chicks
				l["eggs"] = 0
				GameState.say(Loc.t("hatched") % hatched, "gold")
			else:
				GameState.say(Loc.t("no_chicks_year"), "info")
		1:
			var fl := []
			for c in alive_chicks():
				fl.append({"name": c.name, "sex": c.sex, "skill": 1 if float(c.get("growth", 0.0)) >= 0.9 else 0, "food": 70.0, "lessons": 0})
			l["chicks"] = []
			l["fledglings"] = fl
			if fl.size() > 0:
				GameState.say(Loc.t("fledged") % fl.size(), "gold")
		2:
			var n := 0
			for fd in l.get("fledglings", []):
				l["offspring"].append({"name": fd.name, "sex": fd.sex, "skill": int(fd.get("skill", 0)), "year": int(d.get("year", 1)), "alive": true})
				n += 1
			l["fledglings"] = []
			_year_fledged = n
			GameState.stats()["fledged"] = int(GameState.stats().get("fledged", 0)) + n
			Records.add_fledged(n)
			for f in fledglings:
				if is_instance_valid(f):
					f.queue_free()
			fledglings.clear()
			if n > 0:
				GameState.say(Loc.t("independent") % n, "gold")
		3:
			_year_end()
			return
	d["season"] = s + 1
	d["day"] = 1
	main.world.set_season(s + 1)
	main.world.set_snow(1.0 if s + 1 == 3 else 0.0)
	nest.refresh()
	if s + 1 == 2:
		_spawn_fledglings()
	_new_weather()
	_season_card()
	_refresh_objectives()
	GameState.save_game()


func _season_card() -> void:
	var sid := GameState.season_id()
	main.hud.popup(Loc.t("season_" + sid), Loc.t("season_sub_" + sid), Color(1, 0.95, 0.85), 2.5)
	Sfx.play("chime_big", -6.0)


func _year_end() -> void:
	main.menus.open_summary(_year_fledged)


## 연말 요약 화면에서 "다음 해로"를 누르면 호출
func start_new_year() -> void:
	var d := GameState.data
	var l := L()
	var f := GameState.falcon()
	f["age"] = int(f.get("age", 1)) + 1
	# 지난 해들의 자식 생존
	var survived := 0
	for o in l.get("offspring", []):
		if o.get("alive", true):
			# 사냥을 잘 배운 자식일수록 겨울을 잘 넘긴다
			if randf() < 0.62 + 0.1 * float(o.get("skill", 0)):
				survived += 1
			else:
				o["alive"] = false
	if survived > 0:
		GameState.say(Loc.t("offspring_survive") % survived, "good")
	if int(f.age) > int(f.get("lifespan", 6)):
		main._die("old")
		return
	d["year"] = int(d.get("year", 1)) + 1
	d["season"] = 0
	d["day"] = 1
	GameState.stats()["year_prey"] = 0
	_year_fledged = 0
	l["territory"] = false
	l["rival_hits"] = 0
	l["eggs"] = 0
	l["incubation_food"] = 0
	l["chicks"] = []
	l["fledglings"] = []
	main.world.set_season(0)
	main.world.set_snow(0.0)
	main.falcon.apply_stats()
	reset_actors()
	if l.mate.get("has", false):
		_spawn_mate(true)
		GameState.say(Loc.t("mate_returns"), "gold")
	nest.refresh()
	_new_weather()
	_season_card()
	if int(f.age) >= int(f.get("lifespan", 6)):
		GameState.say(Loc.t("growing_old"), "warn")
	_refresh_objectives()
	GameState.save_game()


func on_crash() -> void:
	if not GameState.flag("hint_crash") and Settings.hints:
		GameState.set_flag("hint_crash")
		GameState.say(Loc.t("hint_crash"), "info")


func on_takeoff() -> void:
	pass


func on_land(p: Dictionary) -> void:
	var f: Falcon = main.falcon
	var l := L()
	if p.get("kind", "") != "eyrie":
		return
	# 둥지 자리 보여주기
	if mate and mate.mode != MateBird.M.NEST and not l.mate.get("has", false) and float(l.mate.get("bond", 0.0)) >= 50.0 and not l.mate.get("shown_eyrie", false):
		if mate.global_position.distance_to(WorldShape.eyrie) < 120.0:
			l.mate["shown_eyrie"] = true
			_add_bond(25.0, Loc.t("bond_eyrie"))
			mate.go_nest()
	if f.carrying == null:
		return
	var prey := f.carrying as Prey
	if not alive_chicks().is_empty():
		f.carrying = null
		feed_chicks(prey.food * 1.6)
		prey.vanish()
		main.hud.popup(Loc.t("fed_chicks"), "", Color(0.7, 1.0, 0.6), 1.0)
		Sfx.play("chick", 0.0)
		Sfx.play("ui_good", -6.0)
	elif int(l.get("eggs", 0)) > 0 and mate:
		f.carrying = null
		prey.vanish()
		l["incubation_food"] = int(l.get("incubation_food", 0)) + 1
		main.hud.popup(Loc.t("fed_mate"), "%d / 2" % mini(int(l.incubation_food), 2), Color(0.7, 1.0, 0.6), 1.0)
		mate.call_back()
	elif season() == 2 and not l.get("fledglings", []).is_empty():
		f.carrying = null
		prey.vanish()
		var hungriest = l.fledglings[0]
		for fd in l.fledglings:
			if float(fd.get("food", 0.0)) < float(hungriest.get("food", 0.0)):
				hungriest = fd
		hungriest["food"] = 100.0
		main.hud.popup(Loc.t("fed_fledgling"), str(hungriest.name), Color(0.7, 1.0, 0.6), 1.0)


func on_drop(p: Prey) -> void:
	if p == null:
		return
	var pp := p.global_position
	# 둥지 위에 떨어뜨리면 바로 배달
	if not alive_chicks().is_empty() and Vector2(pp.x - WorldShape.eyrie.x, pp.z - WorldShape.eyrie.z).length() < 25.0 and pp.y > WorldShape.eyrie.y - 2.0:
		feed_chicks(p.food * 1.5)
		p.vanish()
		main.hud.popup(Loc.t("fed_chicks"), "", Color(0.7, 1.0, 0.6), 1.0)
		Sfx.play("chick", 0.0)
		return
	# 새끼에게 사냥 가르치기
	var best: Fledgling = null
	var bd := 70.0
	for fl in fledglings:
		if not is_instance_valid(fl) or fl.carrying:
			continue
		var d: float = fl.global_position.distance_to(pp)
		if d < bd and fl.global_position.y < pp.y + 5.0:
			bd = d
			best = fl
	if best:
		var skill := float(best.data.get("skill", 0))
		best.start_catch(p, clampf(0.45 + 0.18 * skill - bd * 0.002, 0.25, 0.9))
		return
	# 짝에게 공중 먹이 전달
	if mate and is_instance_valid(mate) and mate.global_position.distance_to(pp) < 70.0 and mate.carrying == null:
		mate.start_catch(p)


func mate_caught(p: Prey) -> void:
	var l := L()
	Sfx.play_at("call", mate.global_position, 0.0, 1.15, 600.0)
	if not l.mate.get("has", false):
		_add_bond(30.0, Loc.t("bond_gift"))
	elif int(l.get("eggs", 0)) > 0:
		l["incubation_food"] = int(l.get("incubation_food", 0)) + 1
		main.hud.popup(Loc.t("fed_mate"), "%d / 2" % mini(int(l.incubation_food), 2), Color(0.7, 1.0, 0.6), 1.0)
	elif not alive_chicks().is_empty():
		feed_chicks(p.food * 1.2)
		main.hud.popup(Loc.t("mate_to_nest"), "", Color(0.7, 1.0, 0.6), 1.0)
	else:
		main.hud.popup(Loc.t("mate_thanks"), "", Color(0.9, 0.9, 1.0), 0.8)


func on_display_dive(peak: float, rolls: int) -> void:
	if mate == null or not is_instance_valid(mate) or L().mate.get("has", false):
		if peak >= 250.0:
			GameState.say(Loc.t("great_dive") % int(peak), "gold")
		return
	if _display_cd > 0.0 or peak < 170.0:
		return
	if mate.global_position.distance_to(main.falcon.global_position) > 320.0:
		return
	_display_cd = 5.0
	var gain := clampf((peak - 140.0) / 8.0, 4.0, 20.0) + rolls * 3.0
	_add_bond(gain, Loc.t("bond_display") % int(peak))
	mate.call_back()


func on_call() -> void:
	if mate and is_instance_valid(mate):
		mate.call_back()
		if not L().mate.get("has", false) and mate.global_position.distance_to(main.falcon.global_position) < 400.0:
			mate.follow_t = 25.0
			if _call_cd <= 0.0:
				_call_cd = 20.0
				_add_bond(3.0, Loc.t("bond_call"))
	for fl in fledglings:
		if is_instance_valid(fl) and fl.global_position.distance_to(main.falcon.global_position) < 300.0:
			Sfx.play_at("chick", fl.global_position, 0.0, 0.7, 300.0)
			break


func _add_bond(v: float, reason: String) -> void:
	var l := L()
	var b := minf(float(l.mate.get("bond", 0.0)) + v, 100.0)
	l.mate["bond"] = b
	main.hud.popup(reason, "+%d  (%d/100)" % [int(v), int(b)], Color(1.0, 0.6, 0.75), 1.1)
	Sfx.play("chime", -6.0, 1.2)
	if b >= 100.0 and not l.mate.get("has", false):
		l.mate["has"] = true
		var nm: String = (NAMES_F if GameState.is_male() else NAMES_M)[randi() % 10]
		l.mate["name"] = nm
		await get_tree().create_timer(1.2).timeout
		main.hud.popup(Loc.t("paired"), Loc.t("paired_sub") % nm, Color(1.0, 0.55, 0.7), 2.5)
		Records.unlock("paired")
		Sfx.play("chime_big", 0.0)
		if mate:
			mate.go_nest()
		GameState.save_game()
	elif b >= 50.0 and mate and mate.mode == MateBird.M.COURT:
		mate.mode = MateBird.M.FOLLOW
		GameState.say(Loc.t("mate_follows"), "good")


func _on_lesson(success: bool, fl: Fledgling) -> void:
	if success:
		fl.data["skill"] = int(fl.data.get("skill", 0)) + 1
		fl.data["lessons"] = int(fl.data.get("lessons", 0)) + 1
		fl.data["food"] = 100.0
		main.hud.popup(Loc.t("lesson_ok"), Loc.t("lesson_ok_sub") % [str(fl.data.name), int(fl.data.skill)], Color(0.7, 1.0, 0.6), 1.2)
		Sfx.play("chime", -4.0)
	else:
		main.hud.popup(Loc.t("lesson_fail"), Loc.t("lesson_fail_sub"), Color(1, 0.8, 0.6), 1.0)


func _on_rival_hit_player() -> void:
	var f: Falcon = main.falcon
	main.damage(7.0, "rival")
	f.speed *= 0.55
	f.dir = (f.dir + Vector3(randf_range(-0.5, 0.5), -0.4, randf_range(-0.5, 0.5))).normalized()
	main.camera.add_trauma(0.8)
	Fx.feathers(main.fx_root, f.global_position, rival.vel if rival else Vector3.DOWN, Color(0.24, 0.28, 0.33), Color(0.9, 0.88, 0.82), 30, 0.8)
	Sfx.play("hit", 0.0, 0.8)
	main.hud.popup(Loc.t("got_hit"), "", Color(1, 0.4, 0.3), 0.8)
	if f.carrying:
		f.drop_prey(false)


func _on_rival_defeated() -> void:
	L()["territory"] = true
	Records.unlock("territory")
	main.hud.popup(Loc.t("territory_won"), Loc.t("territory_won_sub"), Color(1, 0.85, 0.35), 2.2)
	Sfx.play("chime_big", 0.0)
	if not L().mate.get("has", false):
		_mate_spawn_t = 15.0
	GameState.save_game()


func _on_owl_reached() -> void:
	var chicks := alive_chicks()
	if mate and is_instance_valid(mate) and mate.perched and randf() < 0.5:
		GameState.say(Loc.t("mate_defended"), "good")
		return
	if chicks.is_empty():
		return
	var c = chicks[randi() % chicks.size()]
	c["alive"] = false
	nest.refresh()
	GameState.say(Loc.t("owl_took") % str(c.name), "warn")
	Sfx.play("hoot", 4.0, 0.9)


func _on_owl_driven() -> void:
	_owl_tonight = false
	Records.unlock("owl")
	main.hud.popup(Loc.t("owl_driven"), "", Color(1, 0.85, 0.35), 1.6)
	Sfx.play("chime_big", -2.0)


## 쉬는 동안의 밤 사건 처리 (둥지에서 잠들 때)
func resolve_night_while_sleeping() -> void:
	for c in alive_chicks():
		c["food"] = maxf(float(c.get("food", 50.0)) - 22.0, 5.0)
	if _owl_tonight:
		_owl_tonight = false
		_on_owl_reached()
	if owl and is_instance_valid(owl):
		owl.queue_free()
		owl = null


# ---------- 목표 & 표식 ----------

func _refresh_objectives() -> void:
	var items := []
	var l := L()
	var s := season()
	var fd := GameState.falcon()
	match s:
		0:
			items.append({"text": Loc.t("obj_territory") % [int(l.get("rival_hits", 0)), rival.need_hits if rival else 3], "done": l.get("territory", false)})
			if l.get("territory", false):
				if not l.mate.get("has", false):
					items.append({"text": Loc.t("obj_mate") % int(l.mate.get("bond", 0.0))})
				elif int(l.get("eggs", 0)) == 0:
					items.append({"text": Loc.t("obj_eggs_soon"), "done": false})
				else:
					items.append({"text": Loc.t("obj_incubate") % mini(int(l.get("incubation_food", 0)), 2), "done": int(l.get("incubation_food", 0)) >= 2})
		1:
			var chicks := alive_chicks()
			if chicks.is_empty():
				items.append({"text": Loc.t("obj_summer_alone")})
			else:
				var avg := 0.0
				for c in chicks:
					avg += float(c.get("food", 0.0))
				avg /= chicks.size()
				items.append({"text": Loc.t("obj_feed_chicks") % [chicks.size(), int(avg)]})
			if owl and is_instance_valid(owl) and owl.mode != OwlRaider.O.FLEE:
				items.append({"text": Loc.t("obj_owl") % owl.hits})
		2:
			var fl: Array = l.get("fledglings", [])
			if fl.is_empty():
				items.append({"text": Loc.t("obj_autumn_alone")})
			else:
				var done := 0
				for x in fl:
					done += mini(int(x.get("lessons", 0)), 2)
				items.append({"text": Loc.t("obj_teach") % [done, fl.size() * 2], "done": done >= fl.size() * 2})
		3:
			items.append({"text": Loc.t("obj_winter") % [int(GameState.data.get("day", 1)), GameState.season_days()]})
	if float(fd.get("energy", 50.0)) < 40.0:
		items.append({"text": Loc.t("obj_eat") % int(fd.get("energy", 0.0))})
	main.hud.set_objectives(items)


func markers() -> Array:
	var out := [{"pos": WorldShape.eyrie + Vector3(0, 3, 0), "color": Color(1.0, 0.8, 0.25), "label": Loc.t("mk_eyrie")}]
	var f: Falcon = main.falcon
	if mate and is_instance_valid(mate) and mate.global_position.distance_to(f.global_position) > 60.0 and not (mate.mode == MateBird.M.NEST and mate.perched):
		out.append({"pos": mate.global_position, "color": Color(1.0, 0.55, 0.75), "label": Loc.t("mk_mate")})
	if rival and is_instance_valid(rival) and rival.mode != RivalFalcon.R.LEAVE:
		if rival.vulnerable():
			out.append({"pos": rival.global_position, "color": Color(1.0, 0.85, 0.2), "label": Loc.t("mk_rival_open")})
			if not rival.hinted:
				rival.hinted = true
				GameState.say(Loc.t("rival_open"), "gold")
		else:
			out.append({"pos": rival.global_position, "color": Color(1.0, 0.3, 0.25), "label": Loc.t("mk_rival")})
	if owl and is_instance_valid(owl) and owl.mode != OwlRaider.O.FLEE:
		out.append({"pos": owl.global_position, "color": Color(1.0, 0.3, 0.25), "label": Loc.t("mk_owl")})
	for fl in fledglings:
		if is_instance_valid(fl) and not fl.perched and fl.global_position.distance_to(f.global_position) > 40.0:
			out.append({"pos": fl.global_position, "color": Color(0.9, 0.75, 0.55), "label": str(fl.data.name)})
	return out


func prompt_extra() -> String:
	var f: Falcon = main.falcon
	if f.carrying and mate and is_instance_valid(mate) and mate.global_position.distance_to(f.global_position) < 60.0 and f.state == Falcon.State.FLYING:
		return Loc.t("prompt_gift")
	if f.carrying and f.state == Falcon.State.FLYING:
		for fl in fledglings:
			if is_instance_valid(fl) and fl.global_position.distance_to(f.global_position) < 70.0:
				return Loc.t("prompt_teach")
	if mate and is_instance_valid(mate) and not L().mate.get("has", false) and f.carrying == null and mate.global_position.distance_to(f.global_position) < 350.0:
		return Loc.t("prompt_call")
	return ""


# ---------- 휴식 ----------

func can_sleep() -> bool:
	var h := float(GameState.data.get("time", 12.0))
	return h >= 16.0 or h < 5.0


func on_death(cause: String) -> void:
	if cause == "old":
		Records.unlock("old_age")
	GameState.archive_current(cause)
	GameState.data["dead"] = cause
	GameState.save_game()
	reset_actors()
