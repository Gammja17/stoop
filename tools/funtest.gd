extends Node
## 개발용: 협동 사냥·먹이 숨기기·매사냥꾼·가을 대이동·포토 모드 점검. godot --path . -- --funtest

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
	print("[fun] shot ", n)


func force(id: String) -> void:
	var ev: EventDirector = main.events
	for i in 80:
		ev._end_quiet()
		ev._start()
		if ev.cur == id:
			return
	print("[fun] could not force ", id)


func _run() -> void:
	await wait(2.0)
	main.start_new_game("시험", "m", "normal", false)
	await wait(2.0)
	main.day_night.set_time(10.0)
	main.events._next = 99999.0
	var f: Falcon = main.falcon
	var life = main.life
	# --- 협동 사냥 ---
	life.L().mate["has"] = true
	life._spawn_mate(true)
	await wait(0.5)
	var spot := WorldShape.fields + Vector3(0, 0, 0)
	var fl: Flock = main.prey_mgr.spawn_group("pigeon", spot, spot, 120.0, 6, "coop_test")
	f.spawn_flying(fl.centroid + Vector3(-60, 80, 0), Vector3.RIGHT, 18.0)
	main.camera.mode = ChaseCamera.Mode.FOLLOW
	life.mate.global_position = fl.centroid + Vector3(120, 30, 0)
	for i in 3:
		await get_tree().process_frame
	life.on_call()
	print("[fun] mate mode after call=%d (DRIVE=%d)" % [life.mate.mode, MateBird.M.DRIVE])
	var flushed: Prey = null
	for i in 40:
		await wait(0.5)
		f.spawn_flying(fl.centroid + Vector3(-60, 80, 0), Vector3.RIGHT, 18.0)
		for m in fl.members:
			if is_instance_valid(m) and m.flushed_t > 0.0:
				flushed = m
		if i % 4 == 0:
			print("[fun]   mate mode=%d d=%.0f members=%d mate_y=%.0f c_y=%.0f" % [life.mate.mode, life.mate.global_position.distance_to(fl.centroid), fl.members.size(), life.mate.global_position.y, fl.centroid.y])
		if flushed:
			break
	print("[fun] flushed=%s" % (flushed != null))
	if flushed:
		await shot("F01_coop_flush")
		f.speed = 70.0
		main._on_contact(flushed, "air")
		await wait(0.5)
	print("[fun] coop record=%s" % Records.has("coop"))
	# --- 먹이 숨기기 ---
	var rock: Dictionary = {}
	for pr in WorldShape.perches:
		if pr.kind == "rock":
			rock = pr
			break
	f.land_at(rock, true)
	await wait(0.3)
	var pf: Flock = main.prey_mgr.spawn_group("pigeon", f.global_position, f.global_position, 30.0, 1, "cache_test")
	var p: Prey = pf.members[0]
	p.take(f)
	f.grab(p)
	main._drop()
	print("[fun] caches after drop=%d carrying=%s" % [main.caches().size(), f.carrying != null])
	var e0 := float(GameState.falcon().energy)
	main._start_eating()
	print("[fun] caches after eat=%d energy %.0f -> %.0f" % [main.caches().size(), e0, float(GameState.falcon().energy)])
	# --- 매사냥꾼 ---
	force("falconer")
	await wait(1.0)
	var fz: Falconer = main.events.falconer
	var lp := fz.lure_pos()
	f.spawn_flying(fz.global_position + Vector3(-25, 12, -25), (fz.global_position + Vector3(0, 3, 0) - (fz.global_position + Vector3(-25, 12, -25))).normalized(), 14.0)
	await wait(0.6)
	await shot("F02_falconer")
	for i in 60:
		f.spawn_flying(fz.lure_pos() - Vector3(0.5, 0, 0), Vector3.RIGHT, 12.0)
		await get_tree().process_frame
		if main.events.cur != "falconer":
			break
	print("[fun] falconer -> cur='%s' shichimi=%s" % [main.events.cur, Records.has_plumage("shichimi")])
	# --- 가을 대이동 ---
	GameState.data["season"] = 2
	force("migration")
	var mf: Flock = main.events.mig_flock
	var c0: Vector3 = mf.centroid
	for i in 10:
		f.spawn_flying(mf.centroid + Vector3(0, 30, -40), Vector3.RIGHT, 18.0)
		await wait(1.0)
	print("[fun] migration moved %.0f m, with=%.0fs obj=%s" % [c0.distance_to(mf.centroid), main.events._mig_with, main.events.objective().get("text", "")])
	await shot("F03_migration")
	# --- 포토 모드 ---
	main.photo.enter()
	await wait(0.3)
	main.photo._yaw += 1.0
	await wait(0.5)
	await shot("F04_photo")
	var paused := get_tree().paused
	main.photo.exit()
	await wait(0.3)
	print("[fun] photo paused_in=%s paused_after=%s" % [paused, get_tree().paused])
	GameState.data["season"] = 0
	get_tree().quit()
