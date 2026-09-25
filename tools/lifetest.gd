extends Node
## 개발용: 한 해 전체 흐름을 빠르게 돌려 런타임 오류와 화면을 점검한다.
## 사용: godot --path . -- --lifetest

var main
var dir := "res://.shots/"


func _ready() -> void:
	main = get_parent()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_run()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(dir + name + ".png"))
	print("[lifetest] shot ", name)


func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func note(s: String) -> void:
	print("[lifetest] ", s)


func _run() -> void:
	await wait(2.5)
	await shot("L00_title_cam")
	main.start_new_game("시험", "f", "normal", false)
	await wait(2.0)
	var life: LifeDirector = main.life
	var f: Falcon = main.falcon
	main.hud.hide_hint()
	# 침입자
	f.take_off()
	f.spawn_flying(WorldShape.eyrie + Vector3(60, 60, 0), Vector3(1, 0, 0), 25.0)
	life._spawn_rival()
	await wait(3.0)
	await shot("L01_rival")
	for i in life.rival.need_hits:
		life.rival._hurt = 0.0
		life.rival.take_hit(f.velocity)
		life.L()["rival_hits"] = life.rival.hits
		await wait(0.3)
	note("territory=%s" % life.L().territory)
	life._mate_spawn_t = 0.1
	await wait(1.0)
	note("mate=%s" % str(life.mate))
	f.spawn_flying(life.mate.global_position + Vector3(-30, 10, -20), Vector3(1, 0, 0.3).normalized(), 25.0)
	await wait(1.5)
	await shot("L02_mate_courting")
	life.on_display_dive(260.0, 2)
	await wait(0.5)
	life._add_bond(40.0, "test")
	await wait(0.5)
	life._add_bond(40.0, "test")
	await wait(2.0)
	note("paired=%s name=%s" % [life.L().mate.has, life.L().mate.name])
	# 다음 날 알
	life.on_new_day()
	note("eggs=%d season=%d day=%d" % [life.L().eggs, GameState.data.season, GameState.data.day])
	f.spawn_perched({"pos": WorldShape.eyrie, "kind": "eyrie", "facing": WorldShape.eyrie_facing})
	main.camera.mode = ChaseCamera.Mode.ORBIT
	await wait(2.0)
	await shot("L03_eggs")
	life.L()["incubation_food"] = 2
	GameState.data["day"] = 3
	life.on_new_day()
	note("chicks=%d season=%d" % [life.alive_chicks().size(), GameState.data.season])
	await wait(2.5)
	await shot("L04_chicks")
	# 먹이 배달
	var fl = main.prey_mgr.spawn_group("pigeon", WorldShape.eyrie + Vector3(40, 20, 0), WorldShape.eyrie, 50.0, 1, "test")
	var pg: Prey = fl.members[0]
	pg.take(f)
	f.grab(pg)
	life.on_land({"kind": "eyrie"})
	note("fed chicks: %s" % str(life.alive_chicks().map(func(c): return int(c.food))))
	# 수리부엉이
	main.day_night.set_time(21.0)
	life._owl_tonight = true
	life.on_hour(21)
	await wait(2.0)
	f.spawn_flying(life.owl.global_position + Vector3(-20, 15, 10), (life.owl.global_position - (life.owl.global_position + Vector3(-20, 15, 10))).normalized(), 20.0)
	await wait(0.5)
	await shot("L05_owl_night")
	life.owl.take_hit(f.velocity)
	await wait(3.5)
	life.owl.take_hit(f.velocity)
	await wait(0.5)
	note("owl mode=%d" % life.owl.mode)
	# 여름 끝 → 가을
	main.day_night.set_time(9.0)
	for c in life.alive_chicks():
		c["growth"] = 1.0
	GameState.data["day"] = 4
	life.on_new_day()
	note("season=%d fledglings=%d" % [GameState.data.season, life.fledglings.size()])
	f.spawn_flying(WorldShape.eyrie + WorldShape.eyrie_facing * 60.0 + Vector3(0, 50, 0), -WorldShape.eyrie_facing, 18.0)
	await wait(4.0)
	await shot("L06_autumn_fledglings")
	# 가르치기: 새끼 바로 위에서 떨어뜨린다
	if life.fledglings.size() > 0:
		var yf: Fledgling = life.fledglings[0]
		var fl2 = main.prey_mgr.spawn_group("pigeon", yf.global_position + Vector3(0, 12, 0), yf.global_position, 50.0, 1, "test")
		var p2: Prey = fl2.members[0]
		p2.take(f)
		f.grab(p2)
		f.global_position = yf.global_position + Vector3(0, 12, 0)
		main._drop()
		await wait(3.0)
		note("lesson skill=%d lessons=%d" % [int(yf.data.get("skill", 0)), int(yf.data.get("lessons", 0))])
	# 가을 끝 → 겨울
	GameState.data["day"] = 3
	life.on_new_day()
	note("season=%d offspring=%d" % [GameState.data.season, life.L().offspring.size()])
	await wait(2.0)
	await shot("L07_winter")
	# 겨울 끝 → 결산
	GameState.data["day"] = 2
	life.on_new_day()
	await wait(1.0)
	await shot("L08_summary")
	main.menus.summary._on_next()
	await wait(1.5)
	note("year=%d season=%d age=%d" % [GameState.data.year, GameState.data.season, GameState.falcon().age])
	await shot("L09_new_year")
	# 죽음 → 혈통
	main.damage(500.0, "old")
	await wait(3.0)
	await shot("L10_death")
	var kids := GameState.living_offspring()
	note("kids=%d" % kids.size())
	if kids.size() > 0:
		main.continue_lineage(kids[0])
		await wait(3.0)
		note("gen=%d name=%s" % [GameState.data.generation, GameState.falcon().name])
		await shot("L11_next_gen")
	# 저장/불러오기
	GameState.save_game()
	var ok := GameState.load_game()
	note("reload ok=%s" % ok)
	GameState.delete_save()
	get_tree().quit()
