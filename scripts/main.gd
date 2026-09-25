extends Node3D
## 게임 전체 흐름: 로딩 → 타이틀 → 플레이 ↔ 메뉴. 사냥 판정과 타격 연출(히트스톱·슬로모·킬캠)을 담당한다.

@onready var world: WorldBuilder = $World
@onready var day_night: DayNight = $DayNight
@onready var falcon: Falcon = $Falcon
@onready var camera: ChaseCamera = $Camera
@onready var prey_mgr: PreyManager = $PreyManager
@onready var life: LifeDirector = $Life
@onready var streaks: SpeedStreaks = $Streaks
@onready var fx_root: Node3D = $FX
@onready var env: Environment = $WorldEnvironment.environment
@onready var screen_fx: ColorRect = $ScreenLayer/ScreenFX
@onready var hud = $UILayer/HUD
@onready var dialog = $UILayer/DialogBox
@onready var menus = $MenuLayer/Menus
@onready var prologue: Prologue = $Prologue

var playing := false
var loaded := false
var dev_mode := false
var eating := 0.0
var eating_total := 0.0
var juice_lock := false
var _flash := 0.0
var _aberr := 0.0
var _damage := 0.0
var _focus := false
var _heart_t := 0.0
var _eye := 0.0
var _starve_warned := false
var _t := 0.0


func _ready() -> void:
	add_to_group("main")
	falcon.visible = false
	falcon.state = Falcon.State.FROZEN
	camera.mode = ChaseCamera.Mode.CINEMATIC
	hud.bind(self)
	hud.set_flight_widgets_visible(false)
	menus.main = self
	menus.show_loading(true)
	await get_tree().process_frame
	await get_tree().process_frame
	await world.build()
	day_night.setup(env, $Sun, $Moon, world, camera)
	world.set_season(0)
	streaks.cam = camera
	streaks.falcon = falcon
	camera.target = falcon
	camera.first_person = Settings.first_person
	falcon.crashed.connect(_on_crashed)
	falcon.landed.connect(_on_landed)
	falcon.took_off.connect(_on_took_off)
	falcon.display_dive.connect(func(pk, rolls): life.on_display_dive(pk, rolls))
	prey_mgr.contact.connect(_on_contact)
	prey_mgr.gull_hit.connect(_on_gull_hit)
	prey_mgr.mobber_hit.connect(_on_mobber_hit)
	prey_mgr.eagle_hit.connect(_on_eagle_hit)
	day_night.new_day.connect(func(): life.on_new_day())
	day_night.hour_passed.connect(func(h): life.on_hour(h))
	day_night.dusk.connect(func(): life.on_dusk())
	day_night.nightfall.connect(func(): life.on_nightfall())
	# 타이틀 화면용: 둥지에 앉은 매
	if GameState.data.is_empty():
		GameState.new_game("매", "m", "normal")
		GameState.in_game = false
	falcon.visible = true
	falcon.spawn_perched({"pos": WorldShape.eyrie, "kind": "eyrie", "facing": WorldShape.eyrie_facing})
	falcon.state = Falcon.State.PERCHED
	falcon.input_enabled = false
	day_night.set_time(7.2)
	prey_mgr.setup(self)
	life.setup(self)
	prologue.setup(self, dialog)
	camera.cine_center = WorldShape.eyrie
	camera.cine_facing = WorldShape.eyrie_facing
	loaded = true
	menus.show_loading(false)
	menus.open_title()
	Sfx.music("title")
	Sfx.set_wind_active(true)
	# 개발용 자동 점검 (배포 빌드에서는 tools/가 제외된다)
	for arg in OS.get_cmdline_user_args():
		var tool_path := "res://tools/%s.gd" % arg.trim_prefix("--")
		if arg.begins_with("--") and ResourceLoader.exists(tool_path):
			dev_mode = true
			add_child(load(tool_path).new())


# ---------- 시작 ----------

func start_new_game(p_name: String, sex: String, difficulty: String, tutorial: bool = true) -> void:
	GameState.new_game(p_name, sex, difficulty)
	GameState.data["prologue"] = 0 if tutorial else -1
	_begin(true)


func continue_game() -> void:
	if not GameState.load_game():
		return
	_begin(false)


func continue_lineage(offspring: Dictionary) -> void:
	GameState.continue_as(offspring)
	GameState.save_game()
	if int(GameState.data.get("generation", 1)) >= 3:
		Records.unlock("gen3")
	_begin(false, true)


func _begin(fresh: bool, new_generation: bool = false) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	var tw: Tween = hud.fade_to(1.0, 0.5)
	await tw.finished
	_rebuild_falcon()
	falcon.spawn_perched({"pos": WorldShape.eyrie, "kind": "eyrie", "facing": WorldShape.eyrie_facing})
	falcon.input_enabled = true
	falcon.stamina = falcon.max_stamina
	day_night.set_time(float(GameState.data.get("time", 6.5)))
	day_night.apply_weather(str(GameState.data.get("weather", "clear")), true)
	world.set_season(int(GameState.data.get("season", 0)))
	world.set_snow(1.0 if GameState.data.get("season", 0) == 3 else 0.0)
	camera.mode = ChaseCamera.Mode.ORBIT
	camera.orbit_behind(WorldShape.eyrie_facing)
	menus.close_all()
	hud.set_flight_widgets_visible(true)
	playing = true
	GameState.in_game = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.music("calm", 4.0)
	var pro := int(GameState.data.get("prologue", -1))
	if pro >= 0:
		# 새 게임은 알부터, 이어하기는 첫 비행부터
		prologue.begin(0 if fresh else Prologue.St.FLAP)
	else:
		life.begin(fresh, new_generation)
	hud.fade_to(0.0, 1.2)


func _rebuild_falcon(spec: String = "") -> void:
	if falcon.model:
		falcon.model.queue_free()
	falcon.model = BirdModel.new()
	falcon.add_child(falcon.model)
	if spec == "":
		spec = "falcon_f" if GameState.falcon().get("sex", "m") == "f" else "falcon"
	falcon.model.setup(spec)
	falcon.apply_stats()
	falcon.carrying = null
	camera._apply_body_visibility()


## 프롤로그 동안은 갈색 어린 매
func set_juvenile(on: bool) -> void:
	_rebuild_falcon("juvenile" if on else "")
	falcon.spawn_perched({"pos": WorldShape.eyrie, "kind": "eyrie", "facing": WorldShape.eyrie_facing})
	camera.mode = ChaseCamera.Mode.ORBIT
	camera.orbit_behind(WorldShape.eyrie_facing)


## 프롤로그가 끝나면(또는 건너뛰면) 1년차 봄 아침에서 본게임을 시작한다
func finish_prologue() -> void:
	GameState.data["prologue"] = -1
	if falcon.carrying:
		var cp := falcon.carrying as Prey
		falcon.carrying = null
		if cp:
			cp.vanish()
	set_juvenile(false)
	falcon.visible = true
	falcon.input_enabled = true
	GameState.falcon()["energy"] = 75.0
	GameState.falcon()["health"] = 100.0
	day_night.set_time(6.5)
	hud.set_flight_widgets_visible(true)
	life.begin(true, false)
	hud.fade_to(0.0, 1.5)


func quit_to_title() -> void:
	playing = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.set_flight_widgets_visible(false)
	hud.hide_hint()
	hud.set_prompt("")
	if prologue.active:
		prologue.stop()
	falcon.visible = true
	life.reset_actors()
	falcon.input_enabled = false
	if falcon.carrying:
		falcon.drop_prey(false)
	falcon.spawn_perched({"pos": WorldShape.eyrie, "kind": "eyrie", "facing": WorldShape.eyrie_facing})
	camera.mode = ChaseCamera.Mode.CINEMATIC
	menus.open_title()
	Sfx.music("title")


# ---------- 루프 ----------

func _process(delta: float) -> void:
	if not loaded:
		return
	_t += delta
	world.follow_camera(camera.global_position)
	world.bob_boats(_t)
	_update_screen_fx(delta)
	_update_audio()
	if not playing:
		return
	if prologue.active:
		# 프롤로그 동안은 시간이 멈추고 배고픔도 없다
		prologue.update(delta)
	else:
		day_night.advance(delta)
		_update_needs(delta)
	_update_eating(delta)
	_update_targeting()
	_update_prompts()
	if not prologue.active:
		life.update(delta)
	hud.update_hud(self, delta)
	hud.reticle.markers = prologue.markers() if prologue.active else life.markers() + prey_mgr.markers()
	_check_islands(delta)
	camera.eye_zoom = _eye
	var kmh := falcon.kmh()
	if kmh >= 300.0:
		Records.unlock("speed_300")
		if kmh >= 350.0:
			Records.unlock("speed_350")
	# 앉아 있을 땐 카메라가 보는 쪽으로 날아오르게 조준을 맞춘다
	if falcon.state == Falcon.State.PERCHED and camera.mode == ChaseCamera.Mode.ORBIT:
		falcon.aim_yaw = camera.orbit_yaw
		falcon.aim_pitch = deg_to_rad(8.0)
	falcon.eye_active = _eye > 0.5


func _notification(what: int) -> void:
	# 창이 포커스를 잃으면 자동으로 일시정지
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and playing and not dev_mode and not get_tree().paused and menus and not menus.any_open():
		menus.open_pause()


func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	if event.is_action_pressed("pause"):
		menus.open_pause()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("map"):
		menus.open_map()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("view"):
		camera.toggle_view()
		hud.notify(Loc.t("view_first") if camera.first_person else Loc.t("view_third"), "info")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not falcon.input_enabled:
		return
	if event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("eat"):
		_start_eating()
	elif event.is_action_pressed("drop"):
		_drop()
	elif event.is_action_pressed("call"):
		Sfx.play("call", -2.0, randf_range(0.95, 1.05))
		life.on_call()


func _interact() -> void:
	match falcon.state:
		Falcon.State.FLYING:
			if falcon.try_land():
				return
			hud.notify(Loc.t("no_perch"), "info")
		Falcon.State.PERCHED:
			if falcon.perch.get("kind", "") == "eyrie" and not prologue.active:
				menus.open_rest()
			else:
				falcon.take_off()


# ---------- 둥지에서 쉬기 ----------

func sleep_until_morning() -> void:
	menus.close_all()
	falcon.input_enabled = false
	var tw: Tween = hud.fade_to(1.0, 0.8)
	await tw.finished
	var h := float(GameState.data.get("time", 20.0))
	life.resolve_night_while_sleeping()
	var fd := GameState.falcon()
	fd["health"] = minf(float(fd.get("health", 50.0)) + 25.0, 100.0)
	fd["energy"] = maxf(float(fd.get("energy", 50.0)) - 12.0, 0.0)
	falcon.stamina = falcon.max_stamina
	day_night.set_time(6.0)
	# 오후/밤에 잠들면 새벽 5시를 지나 새 날이 된다
	life.on_new_day()
	await get_tree().create_timer(0.4).timeout
	hud.fade_to(0.0, 1.2)
	falcon.input_enabled = true
	GameState.save_game()
	GameState.say(Loc.t("saved"), "good")


func nap() -> void:
	menus.close_all()
	var tw: Tween = hud.fade_to(0.8, 0.4)
	await tw.finished
	var fd := GameState.falcon()
	fd["health"] = minf(float(fd.get("health", 50.0)) + 6.0, 100.0)
	falcon.stamina = falcon.max_stamina
	var old_h := float(GameState.data.get("time", 12.0))
	var h := old_h + 1.0
	if h >= 24.0:
		h -= 24.0
	day_night.set_time(h)
	if old_h < 5.0 and h >= 5.0:
		life.on_new_day()
	hud.fade_to(0.0, 0.6)


# ---------- 배고픔/체력 ----------

func _update_needs(delta: float) -> void:
	var fd := GameState.falcon()
	var e := float(fd.get("energy", 50.0))
	var hp := float(fd.get("health", 100.0))
	var drain := 0.12
	if falcon.flapping:
		drain += 0.22
	var season := int(GameState.data.get("season", 0))
	if season == 3:
		drain += 0.06
	if float(day_night.cur.get("rain", 0.0)) > 0.3:
		drain += 0.03
	if falcon.state == Falcon.State.PERCHED:
		drain *= 0.6
	e = maxf(e - drain * delta, 0.0)
	if e <= 0.0:
		hp -= 0.7 * delta
		if not _starve_warned:
			_starve_warned = true
			GameState.say(Loc.t("starving"), "warn")
	else:
		_starve_warned = false
		if e > 45.0:
			hp += (0.9 if falcon.state == Falcon.State.PERCHED else 0.25) * delta
	fd["energy"] = e
	fd["health"] = clampf(hp, 0.0, 100.0)
	if hp <= 0.0:
		_die("starve")


func damage(amount: float, cause: String) -> void:
	_damage = clampf(_damage + amount / 40.0, 0.0, 1.0)
	if prologue.active:
		return
	var fd := GameState.falcon()
	var hp := float(fd.get("health", 100.0)) - amount
	if hp <= 0.0:
		if GameState.data.get("difficulty", "normal") == "normal" and cause != "old":
			fd["health"] = 12.0
			_blackout()
			return
		fd["health"] = 0.0
		_die(cause)
		return
	fd["health"] = hp


func _blackout() -> void:
	falcon.input_enabled = false
	hud.popup(Loc.t("blackout"), Loc.t("blackout_sub"), Color(1, 0.4, 0.3), 2.0)
	var tw: Tween = hud.fade_to(1.0, 1.0)
	await tw.finished
	if falcon.carrying:
		falcon.drop_prey(false)
	falcon.spawn_perched({"pos": WorldShape.eyrie, "kind": "eyrie", "facing": WorldShape.eyrie_facing})
	var h := float(GameState.data.get("time", 12.0)) + 2.0
	day_night.set_time(fmod(h, 24.0))
	GameState.falcon()["energy"] = maxf(float(GameState.falcon().get("energy", 30.0)) - 20.0, 5.0)
	camera.mode = ChaseCamera.Mode.ORBIT
	await get_tree().create_timer(0.6).timeout
	hud.fade_to(0.0, 1.0)
	falcon.input_enabled = true


func _die(cause: String) -> void:
	if not playing:
		return
	playing = false
	falcon.input_enabled = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.set_flight_widgets_visible(false)
	hud.hide_hint()
	hud.set_prompt("")
	life.on_death(cause)
	var tw: Tween = hud.fade_to(0.85, 1.5)
	await tw.finished
	menus.open_death(cause)
	hud.fade_to(0.0, 0.5)


# ---------- 먹기 ----------

func _start_eating() -> void:
	if falcon.carrying == null or eating > 0.0:
		return
	var p: Prey = falcon.carrying as Prey
	if p == null:
		return
	var small: bool = p.t.get("small", false)
	if falcon.state == Falcon.State.FLYING and not small:
		hud.notify(Loc.t("eat_need_perch"), "info")
		return
	eating_total = 1.3 if small else 2.8
	eating = eating_total
	Sfx.play("pluck", -6.0)


func _update_eating(delta: float) -> void:
	if eating <= 0.0:
		return
	if falcon.carrying == null:
		eating = 0.0
		return
	eating -= delta
	hud.set_prompt(Loc.t("eating") % int((1.0 - eating / eating_total) * 100.0))
	if randf() < delta * 3.0:
		Sfx.play("pluck", -12.0, randf_range(0.8, 1.2))
	if eating <= 0.0:
		var p: Prey = falcon.carrying as Prey
		falcon.carrying = null
		var fd := GameState.falcon()
		fd["energy"] = minf(float(fd.get("energy", 0.0)) + p.food, 100.0)
		hud.popup(Loc.t("ate"), "+%d" % int(p.food), Color(0.7, 1.0, 0.6), 0.8)
		Sfx.play("ui_good", -8.0)
		prologue.on_eat(p)
		p.vanish()


func _drop() -> void:
	if falcon.carrying == null:
		return
	eating = 0.0
	var p := falcon.drop_prey(true)
	Sfx.play("whoosh", -8.0, 1.2)
	life.on_drop(p)


func gull_steal(g: Gull) -> void:
	if falcon.carrying == null:
		return
	eating = 0.0
	var p: Prey = falcon.drop_prey(false) as Prey
	if p:
		g.take_prey(p)
	camera.add_trauma(0.4)
	hud.popup(Loc.t("stolen"), Loc.t("stolen_sub"), Color(1, 0.5, 0.4), 1.0)
	Sfx.play("hit_med", -4.0)


# ---------- 사냥 판정 ----------

func _on_contact(p: Prey, how: String) -> void:
	var sp := falcon.speed
	var kmh := sp * 3.6
	match how:
		"air":
			var need: float = float(p.t.strike) / falcon.power_mult
			if sp >= need:
				var perfect := kmh >= 250.0
				var knock := falcon.velocity * 0.45 + Vector3(randf_range(-2, 2), 3.0, randf_range(-2, 2))
				p.knock(knock)
				falcon.speed *= 0.7
				GameState.record_prey(p.kind)
				if perfect:
					GameState.stats()["perfect"] = int(GameState.stats().get("perfect", 0)) + 1
				_strike_juice(p, kmh, perfect)
				prologue.on_struck(p)
				_check_hunt_records(p, perfect)
			elif p.t.get("small", false) or (p.kind != "duck" and p.state == Prey.S.FLY):
				# 느린 속도로는 방심한 먹잇감이나 작은 새만 낚아챌 수 있다
				p.take(falcon)
				falcon.grab(p)
				GameState.record_prey(p.kind)
				_bind_juice(p, Loc.t("bind"))
				prologue.on_struck(p)
				_check_hunt_records(p, false)
			elif p.kind != "duck":
				# 도망치는 비둘기는 느린 추격으로는 몸을 틀어 빠져나간다
				p._juke(falcon.velocity)
				falcon.speed *= 0.85
				hud.popup(Loc.t("dodged"), Loc.t("dodged_sub"), Color(1, 0.75, 0.55), 0.8)
				Sfx.play("whoosh", -4.0, 1.3)
			else:
				p.alarm()
				p.vel += falcon.dir * 8.0
				falcon.speed *= 0.45
				camera.add_trauma(0.35)
				hud.popup(Loc.t("bounced"), Loc.t("bounced_sub"), Color(1, 0.6, 0.5), 0.9)
				Sfx.play("hit_med", -2.0, 0.8)
		"catch":
			p.take(falcon)
			falcon.grab(p)
			_bind_juice(p, Loc.t("air_catch"))
			prologue.on_caught(p)
			Records.unlock("air_catch")
		"pickup":
			p.take(falcon)
			falcon.grab(p)
			Sfx.play("pluck", -4.0)
			hud.notify(Loc.t("picked_up") % Loc.t("prey_" + p.kind), "good")
			prologue.on_caught(p)


func _check_hunt_records(p: Prey, perfect: bool) -> void:
	Records.unlock("first_hunt")
	if perfect:
		Records.unlock("perfect_1")
		if int(GameState.stats().get("perfect", 0)) >= 10:
			Records.unlock("perfect_10")
	if p.kind == "duck":
		Records.unlock("duck")
	if p.kind == "murrelet":
		Records.unlock("murrelet")
	if p.kind == "bat":
		Records.unlock("bat")
	var kinds: Dictionary = GameState.stats().get("prey", {})
	if kinds.has("pigeon") and kinds.has("starling") and kinds.has("sandpiper") and kinds.has("duck"):
		Records.unlock("all_prey")


func _on_gull_hit(g: Gull) -> void:
	g.knocked()
	Records.unlock("gull")
	camera.add_trauma(0.35)
	Fx.feathers(fx_root, g.global_position, falcon.velocity, Color(1, 1, 1), Color(0.7, 0.72, 0.75), 30, 0.8)
	Sfx.play("hit_med", -2.0, 1.1)
	hud.popup(Loc.t("gull_driven"), "", Color(0.9, 0.95, 1.0), 0.8)


# ---------- 섬과 새 동물 ----------

var _island_t := 0.0
var _mob_note_t := 0.0


## 처음 가 본 섬 알림과 기록
func _check_islands(delta: float) -> void:
	_island_t -= delta
	_mob_note_t -= delta
	if _island_t > 0.0 or prologue.active:
		return
	_island_t = 1.0
	var st := GameState.stats()
	var seen: Array = st.get("islands", [])
	var isl := WorldShape.island_near(falcon.global_position, 20.0)
	if isl and not seen.has(isl.id):
		seen.append(isl.id)
		st["islands"] = seen
		hud.popup(Loc.t("island_new"), Loc.t("map_isl_" + isl.id), Color(0.7, 0.9, 1.0), 1.2)
		GameState.say(Loc.t("island_hint_" + isl.id), "gold")
		Sfx.play("chime", -4.0)
		if seen.size() >= WorldShape.islands.size():
			Records.unlock("islands")


func mobbed_start(m: Mobber) -> void:
	if _mob_note_t > 0.0:
		return
	_mob_note_t = 25.0
	GameState.say(Loc.t("mob_crow" if m.species == "crow" else "mob_gull"), "warn")


func mobbed_peck(m: Mobber) -> void:
	if not playing or falcon.state == Falcon.State.FROZEN:
		return
	falcon.stamina = maxf(falcon.stamina - 8.0, 0.0)
	camera.add_trauma(0.18)
	if not camera.first_person:
		var sp := BirdModel.resolve(falcon.model.spec_id)
		Fx.feathers(fx_root, falcon.global_position, m.vel, sp.back, sp.belly, 6, 0.3)
	Sfx.play("hit_med", -10.0, 1.3)


func _on_mobber_hit(m: Mobber) -> void:
	m.knocked(falcon.velocity)
	camera.add_trauma(0.3)
	var sp := BirdModel.resolve("crow" if m.species == "crow" else "gull")
	Fx.feathers(fx_root, m.global_position, falcon.velocity, sp.back, sp.belly, 24, 0.7)
	Sfx.play("hit_med", -2.0, 1.1)
	hud.popup(Loc.t("mob_driven"), "", Color(0.9, 0.95, 1.0), 0.7)


func eagle_warn(e: SeaEagle) -> void:
	GameState.say(Loc.t("eagle_warn"), "warn")
	Sfx.play_at("eagle", e.global_position, 4.0, 1.0, 900.0)


func eagle_steal(e: SeaEagle) -> void:
	if falcon.carrying == null:
		return
	eating = 0.0
	var p: Prey = falcon.drop_prey(false) as Prey
	if p:
		e.take_prey(p)
		e._go_home()
	camera.add_trauma(0.55)
	hud.popup(Loc.t("stolen"), Loc.t("eagle_stolen_sub"), Color(1, 0.5, 0.4), 1.0)
	Sfx.play("hit", -4.0, 0.8)


func _on_eagle_hit(e: SeaEagle) -> void:
	e.take_hit(falcon.velocity)
	Records.unlock("eagle")
	var sp := BirdModel.resolve("eagle")
	Fx.feathers(fx_root, e.global_position, falcon.velocity, sp.back, sp.belly, 45, 1.0)
	Fx.ring(fx_root, e.global_position, falcon.dir, 6.0, Color(1, 0.9, 0.8, 0.7))
	Sfx.play("hit", 0.0, 0.85)
	Sfx.play("boom", -4.0, 0.85)
	camera.add_trauma(0.6)
	camera.punch(-12.0)
	_flash = 0.3
	falcon.speed *= 0.6
	hud.popup(Loc.t("eagle_driven"), "", Color(1, 0.8, 0.3), 1.0)


func fox_warn(_f: Fox) -> void:
	GameState.say(Loc.t("fox_warn"), "warn")
	Sfx.play("step", -2.0, 0.7)


func fox_pounce(fx: Fox) -> void:
	if falcon.state != Falcon.State.PERCHED or not falcon.input_enabled:
		return
	eating = 0.0
	if falcon.carrying:
		var p: Prey = falcon.drop_prey(false) as Prey
		if p:
			fx.take(p)
		hud.popup(Loc.t("fox_pounce"), Loc.t("fox_pounce_sub"), Color(1, 0.5, 0.4), 1.0)
	else:
		hud.popup(Loc.t("fox_pounce"), "", Color(1, 0.6, 0.45), 0.8)
	falcon.take_off()
	camera.add_trauma(0.5)
	Sfx.play("hit_med", -2.0, 0.8)


## 타격감의 핵심: 멈춤(히트스톱) → 슬로모션 → 복귀
func _strike_juice(p: Prey, kmh: float, perfect: bool) -> void:
	var k := clampf((kmh - 80.0) / 220.0, 0.0, 1.0)
	var pos := p.global_position
	var sp: Dictionary = p.model.s
	Fx.feathers(fx_root, pos, falcon.velocity, sp.back, sp.belly, int(30 + 70 * k), 0.6 + 0.8 * k)
	Fx.feathers(fx_root, pos, -falcon.velocity, Color(0.95, 0.95, 0.95), sp.belly, int(10 + 25 * k), 0.4)
	Fx.ring(fx_root, pos, falcon.dir, 3.0 + 6.0 * k, Color(1, 0.95, 0.85, 0.8))
	Sfx.play("hit", 2.0, lerpf(1.05, 0.85, k))
	Sfx.play("boom", lerpf(-8.0, 0.0, k), lerpf(1.1, 0.85, k))
	Sfx.play("feathers", -4.0)
	camera.add_trauma(0.45 + 0.5 * k)
	camera.punch(-(8.0 + 14.0 * k))
	_flash = 0.18 + 0.2 * k
	_aberr = 1.0 + k
	if Input.get_connected_joypads().size() > 0:
		Input.start_joy_vibration(0, 0.5 + 0.5 * k, 1.0, 0.25 + 0.2 * k)
	var title := Loc.t("perfect") if perfect else Loc.t("strike")
	var col := Color(1.0, 0.55, 0.2) if perfect else Color(1, 0.84, 0.3)
	hud.popup(title, "%d km/h" % int(kmh), col, 1.1)
	if juice_lock:
		return
	juice_lock = true
	_focus = false
	Engine.time_scale = 0.02
	Sfx.wind_muffle = 1.0
	var stop := lerpf(0.05, 0.12, k) + (0.05 if perfect else 0.0)
	await get_tree().create_timer(stop, true, false, true).timeout
	if perfect and Settings.killcam:
		camera.start_killcam(pos, falcon.dir)
	Engine.time_scale = 0.22 if perfect else lerpf(0.6, 0.35, k)
	var hold := 0.55 if perfect else 0.2 + 0.2 * k
	await get_tree().create_timer(hold, true, false, true).timeout
	camera.end_killcam()
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_method(_set_time_scale, Engine.time_scale, 1.0, 0.45)
	await tw.finished
	Engine.time_scale = 1.0
	Sfx.wind_muffle = 0.0
	juice_lock = false


func _set_time_scale(v: float) -> void:
	Engine.time_scale = v
	Sfx.wind_muffle = 1.0 - v


func _bind_juice(p: Prey, title: String) -> void:
	var sp: Dictionary = p.model.s
	Fx.feathers(fx_root, p.global_position, falcon.velocity, sp.back, sp.belly, 18, 0.5)
	Sfx.play("hit_med", -2.0, 1.1)
	Sfx.play("feathers", -8.0, 1.2)
	camera.add_trauma(0.3)
	camera.punch(-5.0)
	_flash = 0.12
	hud.popup(title, Loc.t("prey_" + p.kind), Color(0.75, 1.0, 0.6), 0.9)
	if juice_lock:
		return
	juice_lock = true
	Engine.time_scale = 0.08
	await get_tree().create_timer(0.05, true, false, true).timeout
	Engine.time_scale = 1.0
	juice_lock = false


# ---------- 조준 & 집중 ----------

func _update_targeting() -> void:
	var r = hud.reticle
	_eye = move_toward(_eye, 1.0 if (Input.is_action_pressed("falcon_eye") and falcon.state == Falcon.State.FLYING) else 0.0, get_process_delta_time() * 4.0)
	r.eye = _eye
	if falcon.state != Falcon.State.FLYING:
		r.target = null
		r.has_lead = false
		_end_focus()
		return
	var look := falcon.aim_dir()
	var tgt: Node3D = prey_mgr.best_target(falcon.global_position, look, 450.0 + 900.0 * _eye, 11.0 + 14.0 * _eye)
	r.target = tgt
	r.has_lead = false
	r.confusion = 0.0
	falcon.assist_target = null
	if tgt == null:
		_end_focus()
		return
	var p: Prey = tgt as Prey
	if p.flock and is_instance_valid(p.flock):
		r.confusion = p.flock.confusion() * (1.0 if falcon.global_position.distance_to(p.global_position) > 30.0 else 0.2)
	# 빽빽한 새떼 속에서는 조준 보조가 듣지 않는다(혼란 효과)
	falcon.assist_target = tgt if r.confusion < 0.5 else null
	# 요격 지점: |P + V t - F| = s t
	var rel := p.global_position - falcon.global_position
	var v: Vector3 = p.vel if p.state != Prey.S.STUNNED else p.vel
	var s := maxf(falcon.speed, 5.0)
	var a := v.dot(v) - s * s
	var b := 2.0 * rel.dot(v)
	var c := rel.dot(rel)
	var tt := -1.0
	if absf(a) < 0.0001:
		tt = -c / b if absf(b) > 0.0001 else -1.0
	else:
		var disc := b * b - 4.0 * a * c
		if disc >= 0.0:
			var sq := sqrt(disc)
			var t1 := (-b - sq) / (2.0 * a)
			var t2 := (-b + sq) / (2.0 * a)
			tt = minf(t1, t2) if minf(t1, t2) > 0.0 else maxf(t1, t2)
	if tt > 0.0 and tt < 10.0:
		r.lead = p.global_position + v * tt
		r.has_lead = true
	# 집중(짧은 슬로모션): 빠르게 꽂히기 직전
	var rv := falcon.velocity - p.vel
	var rv2 := rv.length_squared()
	var should_focus := false
	if falcon.speed > 45.0 and rv2 > 1.0 and (p.state == Prey.S.FLY or p.state == Prey.S.FLEE):
		var tca := rel.dot(rv) / rv2
		var closest := (rel - rv * tca).length()
		if tca > 0.0 and tca < 0.22 and closest < 6.0:
			should_focus = true
	if should_focus and not juice_lock:
		_focus = true
		Engine.time_scale = lerpf(Engine.time_scale, 0.4, 0.5)
		Sfx.wind_muffle = 0.6
	elif _focus:
		_end_focus()


func _end_focus() -> void:
	if _focus and not juice_lock:
		Engine.time_scale = 1.0
		Sfx.wind_muffle = 0.0
	_focus = false


# ---------- 안내 문구 ----------

func _update_prompts() -> void:
	if eating > 0.0:
		return
	if prologue.active and prologue.stage < Prologue.St.FLAP:
		hud.set_prompt(Loc.t("pro_prompt_click") if prologue.stage == Prologue.St.EGG else "")
		return
	var txt := ""
	match falcon.state:
		Falcon.State.FLYING:
			var pr := WorldShape.nearest_perch(falcon.global_position, 14.0)
			if not pr.is_empty() and falcon.speed <= 30.0:
				txt = Loc.t("prompt_land")
			elif not pr.is_empty():
				txt = Loc.t("prompt_slow")
			if falcon.auto_circle:
				txt = Loc.t("prompt_autocircle") % falcon.updraft
			elif falcon.in_thermal:
				txt = Loc.t("prompt_thermal")
			if falcon.carrying:
				var cp := falcon.carrying as Prey
				var small: bool = cp != null and cp.t.get("small", false)
				txt += ("   " if txt != "" else "") + (Loc.t("prompt_eat_air") if small else "") + Loc.t("prompt_drop")
		Falcon.State.PERCHED:
			if falcon.perch.get("kind", "") == "eyrie":
				txt = Loc.t("prompt_rest") + "   " + Loc.t("prompt_takeoff")
			else:
				txt = Loc.t("prompt_takeoff")
			if falcon.carrying:
				txt += "   " + Loc.t("prompt_eat")
	var extra: String = life.prompt_extra()
	if extra != "":
		txt += ("   " if txt != "" else "") + extra
	hud.set_prompt(txt)


# ---------- 이벤트 ----------

func _on_crashed(impact: float, dmg: float) -> void:
	GameState.stats()["crashes"] = int(GameState.stats().get("crashes", 0)) + 1
	camera.add_trauma(0.9)
	_flash = 0.25
	if prologue.active:
		prologue.on_crash()
		return
	if dmg > 1.0:
		hud.popup(Loc.t("crash"), "-%d" % int(dmg), Color(1, 0.35, 0.3), 0.9)
		damage(dmg, "crash")
	life.on_crash()


func _on_landed(p: Dictionary) -> void:
	camera.mode = ChaseCamera.Mode.ORBIT
	camera.orbit_behind(p.get("facing", falcon.dir) if p.get("kind", "") == "eyrie" else falcon.dir)
	if prologue.active:
		prologue.on_land(p)
	else:
		life.on_land(p)


func _on_took_off() -> void:
	camera.mode = ChaseCamera.Mode.FOLLOW
	eating = 0.0
	life.on_takeoff()


func fx_splash(pos: Vector3, size: float) -> void:
	Fx.splash(fx_root, pos, size)


func fx_dust(pos: Vector3) -> void:
	Fx.dust(fx_root, pos)


# ---------- 화면/소리 ----------

func _update_screen_fx(delta: float) -> void:
	var m := screen_fx.material as ShaderMaterial
	var real_dt := delta / maxf(Engine.time_scale, 0.01)
	real_dt = minf(real_dt, 0.1)
	_flash = move_toward(_flash, 0.0, real_dt * 2.2)
	_aberr = move_toward(_aberr, 0.0, real_dt * 2.5)
	_damage = move_toward(_damage, 0.0, real_dt * 0.6)
	var fxk := Settings.fx_intensity
	var sp := 0.0
	var warn := 0.0
	var g := 0.0
	if playing and falcon.state == Falcon.State.FLYING:
		sp = clampf((falcon.speed - 25.0) / 85.0, 0.0, 1.0)
		var p := falcon.global_position
		var above := p.y - WorldShape.floor_y(p.x, p.z)
		var vy := falcon.velocity.y
		if vy < -12.0:
			var tti := above / -vy
			warn = clampf(1.0 - tti / 3.0, 0.0, 1.0)   # 3초 전부터 경고
		g = clampf((falcon.g_load - 7.0) / 10.0, 0.0, 0.6)
	if warn > 0.4:
		_heart_t -= real_dt
		if _heart_t <= 0.0:
			_heart_t = lerpf(0.6, 0.3, warn)
			Sfx.play("heart", -2.0)
	var cloud := world.cloud_density_at(camera.global_position) if world else 0.0
	m.set_shader_parameter("blur", sp * sp * 1.1 * fxk)
	m.set_shader_parameter("lines", clampf((sp - 0.35) * 1.6, 0.0, 1.0) * fxk)
	m.set_shader_parameter("vignette", 0.22 + 0.3 * sp)
	m.set_shader_parameter("g_tunnel", g * fxk)
	m.set_shader_parameter("flash", _flash + cloud * 0.8)
	m.set_shader_parameter("flash_color", Color(1, 1, 1) if cloud < 0.05 else Color(0.9, 0.92, 0.95))
	m.set_shader_parameter("aberration", _aberr + sp * 0.5 * fxk)
	m.set_shader_parameter("damage", _damage)
	m.set_shader_parameter("warn", warn)
	m.set_shader_parameter("eye", _eye)
	m.set_shader_parameter("t", _t)


func _update_audio() -> void:
	var p := camera.global_position
	var sea_k := 0.0
	var gy := WorldShape.ground(p.x, p.z)
	var coast_d := WorldShape.shore_dist(p)
	sea_k = (1.0 - smoothstep(20.0, 300.0, coast_d)) * (1.0 - smoothstep(20.0, 250.0, p.y - maxf(gy, 0.0)))
	Sfx.set_waves(sea_k * 0.8)
