extends Node
## 개발용: 돌발 이벤트·도전과 성장 점검. godot --path . -- --eventtest

var main


func _ready() -> void:
	main = get_parent()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.shots"))
	_run()


func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.shots/" + n + ".png"))
	print("[ev] shot ", n)


func force(id: String) -> void:
	var ev: EventDirector = main.events
	ev._end_quiet()
	ev.cur = ""
	ev._next = 0.0
	# 원하는 이벤트만 나오게
	var tries := 0
	while tries < 60:
		tries += 1
		ev._end_quiet()
		ev._start()
		if ev.cur == id:
			return
	print("[ev] could not force ", id)


func xp_s() -> String:
	var g := Growth.g()
	return "Lv.%d xp=%d pts=%d" % [g.level, g.xp, g.points]


func _run() -> void:
	await wait(2.0)
	main.start_new_game("시험", "m", "normal", false)
	await wait(2.0)
	main.day_night.set_time(10.0)
	var f: Falcon = main.falcon
	var ev: EventDirector = main.events
	f.spawn_flying(WorldShape.fields + Vector3(0, 120, 0), Vector3.RIGHT, 18.0)
	main.camera.mode = ChaseCamera.Mode.FOLLOW
	print("[ev] start ", xp_s())
	# 황금 비둘기
	force("golden")
	await wait(1.0)
	await shot("E01_golden_start")
	f.speed = 80.0
	main._on_contact(ev.golden, "air")
	await wait(0.3)
	print("[ev] golden -> cur='%s' %s" % [ev.cur, xp_s()])
	await wait(2.0)
	# 고도 도전
	force("climb")
	f.spawn_flying(f.global_position + Vector3(0, 450, 0), Vector3.RIGHT, 18.0)
	await wait(0.5)
	print("[ev] climb -> cur='%s' %s" % [ev.cur, xp_s()])
	# 먹이 쟁탈: 가만히 있으면 다른 매가 먼저 채 간다
	force("race")
	var t := 0.0
	while ev.cur == "race" and t < 40.0:
		await wait(0.5)
		t += 0.5
	print("[ev] race (idle) -> cur='%s' after %.0fs hunter_done=%s" % [ev.cur, t, ev.hunter == null])
	# 도둑 까마귀: 앉아서 먹이를 들고 있으면 채 간다 → 들이받아 되찾기
	var fl = main.prey_mgr.spawn_group("pigeon", f.global_position, f.global_position, 50.0, 1, "test")
	var p: Prey = fl.members[0]
	var gp := WorldShape.fields + Vector3(30, 0, 30)
	gp.y = WorldShape.ground(gp.x, gp.z) + 0.2
	f.spawn_perched({"pos": gp, "kind": "ground", "facing": Vector3.RIGHT})
	p.take(f)
	f.grab(p)
	force("thief")
	t = 0.0
	while t < 20.0 and not ev._stolen:
		await wait(0.5)
		t += 0.5
	print("[ev] thief stolen=%s after %.0fs" % [ev._stolen, t])
	await shot("E02_thief")
	if ev._stolen and ev.thief:
		main._on_gull_hit(ev.thief)
		await wait(0.2)
		main._on_contact(ev.thief_prey, "catch")
		await wait(0.3)
	print("[ev] thief -> cur='%s' %s" % [ev.cur, xp_s()])
	# 성장: 포인트 쓰기와 깃털
	Growth.add_xp(2000)
	print("[ev] after xp ", xp_s(), " plumage silver=", Records.has_plumage("silver"), " dark=", Records.has_plumage("dark"))
	var sp0 := f.speed_mult
	Growth.spend("dive")
	Growth.spend("dive")
	f.apply_stats()
	print("[ev] dive rank=%d speed_mult %.2f -> %.2f" % [Growth.rank("dive"), sp0, f.speed_mult])
	Growth.g()["plumage"] = "rufous"
	main.refresh_plumage()
	f.spawn_flying(WorldShape.eyrie + Vector3(40, 60, 0), Vector3(1, 0, 0.3).normalized(), 18.0)
	main.camera.first_person = false
	await wait(1.0)
	await shot("E03_rufous")
	main.menus.open_growth("game")
	await wait(0.5)
	await shot("E04_growth_screen")
	get_tree().quit()
