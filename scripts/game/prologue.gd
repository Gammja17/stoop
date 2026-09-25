class_name Prologue
extends Node
## 프롤로그 튜토리얼: 둥지에서 알을 깨고 나와 어미에게 나는 법·급강하·먹이 받기·사냥을 배운다.
## 끝나면 "1년 뒤 봄"으로 넘어가 본게임이 시작된다.

enum St { EGG, HATCHED, FLAP, FOLLOW, THERMAL, STOOP, CATCH, EAT, HUNT, HOME, DONE }

const CRACKS_NEEDED := 10

var main
var dialog
var active := false
var stage := St.EGG
var mother: MotherBird
var cracks := 0
var _t := 0.0
var _peak := 0.0
var _gift: Prey = null
var _flock = null
var _thermal: Dictionary = {}
var _busy := false
var _nag_t := 0.0
var _gift_t := 0.0
var _struck := false


func setup(p_main, p_dialog) -> void:
	main = p_main
	dialog = p_dialog


func _mother_name() -> String:
	return Loc.t("pro_mother")


func begin(from_stage: int) -> void:
	active = true
	cracks = 0
	_peak = 0.0
	_struck = false
	_thermal = _nearest_thermal()
	main.hud.set_objectives([])
	main.hud.hide_hint()
	_spawn_mother()
	if from_stage <= St.HATCHED:
		_start_egg()
	else:
		main.set_juvenile(true)
		_enter(St.FLAP)


func stop() -> void:
	active = false
	_busy = false
	if mother and is_instance_valid(mother):
		mother.queue_free()
	mother = null
	if _gift and is_instance_valid(_gift):
		_gift.vanish()
	_gift = null
	main.life.nest.show_player_egg(false)
	main.life.nest.show_player_chick(false)
	main.world.set_thermal_boost(1.0)
	dialog.close()


func skip() -> void:
	if not active:
		return
	stop()
	main.finish_prologue()


func _nearest_thermal() -> Dictionary:
	var best: Dictionary = WorldShape.thermals[0]
	var bd := INF
	for t in WorldShape.thermals:
		var d := (t.pos as Vector3).distance_to(WorldShape.eyrie)
		if d < bd:
			bd = d
			best = t
	return best


func _spawn_mother() -> void:
	if mother and is_instance_valid(mother):
		mother.queue_free()
	mother = MotherBird.new().setup(WorldShape.eyrie)
	main.add_child(mother)
	mother.sit_at_nest()


func _save_stage() -> void:
	if stage >= St.FLAP and stage < St.DONE:
		GameState.data["prologue"] = int(stage)
		GameState.save_game()


# ---------- 알 ----------

func _start_egg() -> void:
	stage = St.EGG
	var f: Falcon = main.falcon
	f.visible = false
	f.input_enabled = false
	main.hud.set_flight_widgets_visible(false)
	main.life.nest.show_player_egg(true)
	main.life.nest.crack_egg(0.0)
	main.camera.mode = ChaseCamera.Mode.ORBIT
	main.camera.orbit_dist = 1.3
	main.camera.orbit_behind(-WorldShape.eyrie_facing)
	main.camera.orbit_pitch = -0.5
	dialog.say("", Loc.t("pro_egg_1"))
	dialog.set_goal(Loc.t("pro_goal_egg") % [0, CRACKS_NEEDED])
	dialog.set_progress(0.0, true)
	main.hud.set_prompt(Loc.t("pro_prompt_click"))


func _unhandled_input(event: InputEvent) -> void:
	if not active or stage != St.EGG or _busy:
		return
	var click: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or event.is_action_pressed("tuck") or event.is_action_pressed("interact")
	if not click:
		return
	get_viewport().set_input_as_handled()
	_crack()


func _crack() -> void:
	cracks += 1
	var k := float(cracks) / CRACKS_NEEDED
	var nest = main.life.nest
	nest.crack_egg(k)
	Sfx.play("tap", -2.0, 0.8 + 0.5 * k)
	main.camera.add_trauma(0.12 + 0.1 * k)
	Fx.shell(main.fx_root, nest.egg_position() + Vector3.UP * 0.08, Color(0.95, 0.88, 0.78), 5, 1.0)
	dialog.set_goal(Loc.t("pro_goal_egg") % [cracks, CRACKS_NEEDED])
	dialog.set_progress(k, true)
	if cracks == 4:
		dialog.say("", Loc.t("pro_egg_2"))
	elif cracks == 7:
		dialog.say("", Loc.t("pro_egg_3"))
		Sfx.play_at("call", mother.global_position, -4.0, 1.1, 200.0)
	if cracks >= CRACKS_NEEDED:
		_hatch()


func _hatch() -> void:
	_busy = true
	stage = St.HATCHED
	var nest = main.life.nest
	Fx.shell(main.fx_root, nest.egg_position() + Vector3.UP * 0.05, Color(0.95, 0.9, 0.82), 24, 2.0)
	Sfx.play("wood", -2.0, 1.3)
	Sfx.play("chick", 2.0)
	main.camera.add_trauma(0.35)
	nest.show_player_egg(false)
	nest.show_player_chick(true)
	main.hud.set_prompt("")
	dialog.set_progress(1.0, false)
	dialog.set_goal("")
	await get_tree().create_timer(1.2).timeout
	await _line(_mother_name(), "pro_hatch_1")
	await _line(_mother_name(), "pro_hatch_2")
	await _line(_mother_name(), "pro_hatch_3")
	# 몇 주 뒤…
	var tw: Tween = main.hud.fade_to(1.0, 1.0)
	await tw.finished
	dialog.say("", Loc.t("pro_weeks"))
	dialog.set_goal("")
	nest.show_player_chick(false)
	main.set_juvenile(true)
	main.falcon.visible = true
	main.camera.orbit_dist = 3.4
	main.camera.orbit_behind(WorldShape.eyrie_facing)
	main.hud.set_flight_widgets_visible(true)
	await get_tree().create_timer(2.2).timeout
	main.hud.fade_to(0.0, 1.2)
	_busy = false
	_enter(St.FLAP)


## 대사 한 줄을 띄우고 넘길 때까지 기다린다 (그동안 조작은 막는다)
func _line(speaker: String, key: String) -> void:
	var f: Falcon = main.falcon
	var was := f.input_enabled
	f.input_enabled = false
	dialog.say(speaker, Loc.t(key), true)
	await dialog.advanced
	f.input_enabled = was


# ---------- 단계 진입 ----------

func _enter(s: int) -> void:
	stage = s
	_t = 0.0
	_nag_t = 0.0
	_save_stage()
	Sfx.play("chime", -8.0)
	var f: Falcon = main.falcon
	match s:
		St.FLAP:
			_busy = true
			f.input_enabled = false
			mother.sit_at_nest()
			await _line(_mother_name(), "pro_flap_1")
			dialog.say(_mother_name(), Loc.t("pro_flap_2"))
			dialog.set_goal(Loc.t("pro_goal_flap"))
			f.input_enabled = true
			_busy = false
		St.FOLLOW:
			var tp: Vector3 = _thermal.pos
			mother.lead_to(tp + Vector3(0, 70, 0))
			dialog.say(_mother_name(), Loc.t("pro_follow"))
			dialog.set_goal(Loc.t("pro_goal_follow"))
		St.THERMAL:
			mother.circle_at(_thermal.pos, 60.0)
			main.world.set_thermal_boost(4.0)
			dialog.say(_mother_name(), Loc.t("pro_thermal"))
		St.STOOP:
			main.world.set_thermal_boost(1.0)
			_peak = 0.0
			mother.escort()
			dialog.say(_mother_name(), Loc.t("pro_stoop_1"))
			dialog.set_goal(Loc.t("pro_goal_stoop") % 0)
		St.CATCH:
			_give_gift()
			dialog.say(_mother_name(), Loc.t("pro_catch"))
			dialog.set_goal(Loc.t("pro_goal_catch"))
		St.EAT:
			mother.escort()
			dialog.say(_mother_name(), Loc.t("pro_eat"))
			dialog.set_goal(Loc.t("pro_goal_eat"))
		St.HUNT:
			_struck = false
			mother.escort()
			_spawn_flock()
			dialog.say(_mother_name(), Loc.t("pro_hunt_1"))
			dialog.set_goal(Loc.t("pro_goal_hunt"))
		St.HOME:
			mother.lead_to(WorldShape.eyrie + WorldShape.eyrie_facing * 20.0 + Vector3(0, 15, 0))
			dialog.say(_mother_name(), Loc.t("pro_home"))
			dialog.set_goal(Loc.t("pro_goal_home"))


# ---------- 매 프레임 ----------

func update(delta: float) -> void:
	if not active or _busy:
		return
	_t += delta
	_nag_t -= delta
	var f: Falcon = main.falcon
	var p := f.global_position
	var agl := p.y - WorldShape.floor_y(p.x, p.z)
	match stage:
		St.FLAP:
			if f.state == Falcon.State.FLYING and _t > 2.5:
				_enter(St.FOLLOW)
		St.FOLLOW:
			var tp: Vector3 = _thermal.pos
			if Vector2(p.x - tp.x, p.z - tp.z).length() < float(_thermal.r) * 1.3:
				_enter(St.THERMAL)
			elif f.global_position.distance_to(mother.global_position) > 250.0 and _nag_t <= 0.0:
				_nag_t = 12.0
				dialog.say(_mother_name(), Loc.t("pro_follow_nag"))
		St.THERMAL:
			dialog.set_goal(Loc.t("pro_goal_thermal") % int(maxf(agl, 0.0)))
			if agl >= 150.0:
				_enter(St.STOOP)
			elif not f.in_thermal and f.state == Falcon.State.FLYING and _t > 6.0 and _nag_t <= 0.0:
				_nag_t = 10.0
				dialog.say(_mother_name(), Loc.t("pro_thermal_nag"))
			elif f.state == Falcon.State.PERCHED and _nag_t <= 0.0:
				_nag_t = 8.0
				dialog.say(_mother_name(), Loc.t("pro_takeoff_nag"))
		St.STOOP:
			if _t > 5.0 and _t - delta <= 5.0:
				dialog.say(_mother_name(), Loc.t("pro_stoop_2"))
			if f.state == Falcon.State.FLYING:
				_peak = maxf(_peak, f.kmh())
				dialog.set_goal(Loc.t("pro_goal_stoop") % int(_peak))
				if _peak >= 180.0 and f.dir.y > -0.25 and agl > 3.0:
					dialog.say(_mother_name(), Loc.t("pro_stoop_ok"))
					_enter_later(St.CATCH, 2.5)
			elif f.state == Falcon.State.PERCHED and _nag_t <= 0.0:
				_nag_t = 8.0
				dialog.say(_mother_name(), Loc.t("pro_takeoff_nag"))
		St.CATCH:
			_update_gift(delta)
		St.EAT:
			if f.carrying == null and f.state == Falcon.State.FLYING and main.eating <= 0.0 and _t > 1.0:
				# 먹이를 잃어버렸으면 다시 받기부터
				_enter(St.CATCH)
		St.HUNT:
			if not _struck and (_flock == null or not is_instance_valid(_flock) or _flock.members.is_empty()) and _t > 2.0:
				_spawn_flock()
			if _t > 7.0 and _t - delta <= 7.0 and not _struck:
				dialog.say(_mother_name(), Loc.t("pro_hunt_2"))
		St.HOME:
			if mother.mode == MotherBird.M.CIRCLE:
				mother.sit_at_nest()
			# 이미 둥지에 앉아 있어도 작별 인사로 넘어간다
			if f.state == Falcon.State.PERCHED and f.perch.get("kind", "") == "eyrie":
				_farewell()


func _enter_later(s: int, wait: float) -> void:
	_busy = true
	await get_tree().create_timer(wait).timeout
	_busy = false
	if active:
		_enter(s)


# ---------- 먹이 받기 ----------

func _give_gift() -> void:
	if _gift and is_instance_valid(_gift):
		_gift.vanish()
	_gift = Prey.new().setup("pigeon", mother.global_position, mother.global_position, 50.0)
	main.prey_mgr.add_child(_gift)
	main.prey_mgr.prey.append(_gift)
	mother.take_prey(_gift)
	mother.hold_above_player()
	_gift_t = 4.5


func _update_gift(delta: float) -> void:
	var f: Falcon = main.falcon
	if _gift == null or not is_instance_valid(_gift) or _gift.state == Prey.S.GONE:
		# 사라졌으면(바다에 가라앉음, 갈매기) 하나 더
		_give_gift()
		dialog.say(_mother_name(), Loc.t("pro_catch_again"))
		return
	if _gift.state == Prey.S.CARRIED and _gift.carrier == mother:
		_gift_t -= delta
		if _gift_t <= 0.0 and f.state == Falcon.State.FLYING and mother.global_position.y > f.global_position.y + 8.0:
			mother.release_prey()
			Sfx.play_at("call", mother.global_position, 0.0, 1.1, 300.0)
			dialog.say(_mother_name(), Loc.t("pro_catch_now"))
	elif (_gift.state == Prey.S.GROUND or _gift.state == Prey.S.WATER) and _nag_t <= 0.0:
		_nag_t = 12.0
		dialog.say(_mother_name(), Loc.t("pro_catch_pickup"))


# ---------- 첫 사냥 ----------

func _spawn_flock() -> void:
	var f: Falcon = main.falcon
	var fwd := Vector3(f.dir.x, 0, f.dir.z)
	if fwd.length() < 0.1:
		fwd = WorldShape.eyrie_facing
	var spot := f.global_position + fwd.normalized() * 220.0
	_flock = main.prey_mgr.spawn_group("pigeon", spot, spot, 140.0, 4, "tutorial")
	for pg in _flock.members:
		pg.weak = true
		pg.t["agility"] = 0.1
		pg.t["detect"] = 25.0
		var gy := WorldShape.floor_y(pg.global_position.x, pg.global_position.z)
		pg.global_position.y = maxf(f.global_position.y - 100.0, gy + 30.0)


# ---------- 훅 (main에서 호출) ----------

func on_caught(p: Prey) -> void:
	if not active:
		return
	if stage == St.CATCH:
		dialog.say(_mother_name(), Loc.t("pro_catch_ok"))
		_enter_later(St.EAT, 2.0)
	elif stage == St.HUNT and not _struck and p != _gift:
		_hunted()


func on_struck(_p: Prey) -> void:
	if active and stage == St.HUNT and not _struck:
		_hunted()


func _hunted() -> void:
	_struck = true
	dialog.say(_mother_name(), Loc.t("pro_hunt_ok"))
	dialog.set_goal("")
	Sfx.play("chime_big", -4.0)
	_enter_later(St.HOME, 3.5)


func on_eat(_p: Prey) -> void:
	if active and stage == St.EAT:
		dialog.say(_mother_name(), Loc.t("pro_eat_ok"))
		_enter_later(St.HUNT, 3.0)


func on_crash() -> void:
	if not active:
		return
	if stage == St.STOOP:
		_peak = 0.0
		dialog.say(_mother_name(), Loc.t("pro_crash"))
		dialog.set_goal(Loc.t("pro_goal_reclimb"))
	else:
		dialog.say(_mother_name(), Loc.t("pro_crash_soft"))


func on_land(perch: Dictionary) -> void:
	if active and stage == St.HOME and perch.get("kind", "") == "eyrie":
		_farewell()


func _farewell() -> void:
	_busy = true
	stage = St.DONE
	dialog.set_goal("")
	mother.sit_at_nest()
	await get_tree().create_timer(0.6).timeout
	await _line(_mother_name(), "pro_bye_1")
	await _line(_mother_name(), "pro_bye_2")
	await _line(_mother_name(), "pro_bye_3")
	dialog.close()
	Sfx.play_at("call", mother.global_position, 2.0, 1.05, 400.0)
	mother.leave()
	main.falcon.input_enabled = false
	await get_tree().create_timer(3.0).timeout
	var tw: Tween = main.hud.fade_to(1.0, 1.2)
	await tw.finished
	dialog.say("", Loc.t("pro_year_later"))
	dialog.set_goal("")
	await get_tree().create_timer(2.5).timeout
	mother = null
	active = false
	_busy = false
	dialog.close()
	main.finish_prologue()


# ---------- 표식 ----------

func markers() -> Array:
	var out := []
	var f: Falcon = main.falcon
	var mcol := Color(1.0, 0.75, 0.45)
	var p := f.global_position
	var agl := p.y - WorldShape.floor_y(p.x, p.z)
	match stage:
		St.FOLLOW:
			if mother and is_instance_valid(mother):
				out.append({"pos": mother.global_position, "color": mcol, "label": _mother_name()})
		St.EAT:
			var pr := WorldShape.nearest_perch(p, 5000.0)
			if not pr.is_empty():
				out.append({"pos": (pr.pos as Vector3) + Vector3(0, 2, 0), "color": Color(0.6, 1.0, 0.7), "label": Loc.t("pro_mk_perch")})
		St.STOOP:
			# 높이가 모자라면 상승기류로 안내
			if agl < 120.0:
				out.append({"pos": (_thermal.pos as Vector3) + Vector3(0, 80, 0), "color": Color(1, 0.95, 0.5), "label": Loc.t("hud_thermal")})
		St.THERMAL:
			var tp: Vector3 = _thermal.pos
			out.append({"pos": Vector3(tp.x, maxf(f.global_position.y, tp.y + 40.0), tp.z), "color": Color(1, 0.95, 0.5), "label": Loc.t("hud_thermal")})
		St.CATCH:
			if _gift and is_instance_valid(_gift):
				out.append({"pos": _gift.global_position, "color": Color(1, 0.5, 0.4), "label": Loc.t("pro_mk_food")})
		St.HUNT:
			if not _struck and _flock and is_instance_valid(_flock) and not _flock.members.is_empty():
				out.append({"pos": _flock.members[0].global_position + Vector3(0, 3, 0), "color": Color(1, 0.5, 0.4), "label": Loc.t("prey_pigeon")})
		St.HOME:
			out.append({"pos": WorldShape.eyrie + Vector3(0, 3, 0), "color": Color(1.0, 0.8, 0.25), "label": Loc.t("mk_eyrie")})
	return out
