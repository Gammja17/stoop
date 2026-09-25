extends Node
## 개발용: SKEAM 등록용 홍보 스크린샷. godot --path . -- --promoshot
## N##_*.png = UI 없는 홍보 소재 (배너·포스터·라이브러리 배경 원본)
## S##_*.png = HUD 포함 상점 스크린샷

var main
var _hit := false


func _ready() -> void:
	main = get_parent()
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.shots"))
	_run()


func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func shot(n: String) -> void:
	main.hud.hide_hint()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.shots/" + n + ".png"))
	print("[promo] shot ", n)


func ui(v: bool) -> void:
	main.get_node("UILayer").visible = v


func _run() -> void:
	await wait(2.5)
	main.start_new_game("홍보", "m", "normal", false)
	await wait(2.0)
	main.events._next = 9999.0
	main.day_night.apply_weather("clear", true)
	var f: Falcon = main.falcon
	main.camera.mode = ChaseCamera.Mode.FOLLOW

	# ── N01: 새벽 바다 위 활공 (배너·라이브러리 원본) ──
	main.day_night.set_time(6.6)
	var start := WorldShape.bay + Vector3(-300, 420, 200)
	f.spawn_flying(start, Vector3(0.9, 0.02, -0.35).normalized(), 16.0)
	await wait(2.0)
	ui(false)
	await shot("N01_hero_dawn")

	# ── N02: 급강하 (세로 포스터 원본) ──
	ui(true)
	main.day_night.set_time(9.0)
	f.spawn_flying(WorldShape.bay + Vector3(-150, 700, -250), Vector3(0.4, -0.1, 0.55).normalized(), 30.0)
	await wait(0.8)
	f.set_heading(Vector3(0.3, -0.85, 0.4).normalized())
	Input.action_press("tuck")
	await wait(3.5)
	ui(false)
	await shot("N02_stoop_dive")
	Input.action_release("tuck")

	# ── N03: 황금빛 절벽 둥지 (라이브러리 배경 원본) ──
	ui(true)
	main.day_night.set_time(18.2)
	var e := WorldShape.eyrie
	f.spawn_flying(e + Vector3(-120, 80, 160), (e + Vector3(0, 40, 0) - (e + Vector3(-120, 80, 160))).normalized(), 15.0)
	await wait(1.8)
	ui(false)
	await shot("N03_cliff_dusk")

	# ── N04: 밤 도시 (여분) ──
	ui(true)
	main.day_night.set_time(21.5)
	var c := Vector3(WorldShape.CITY_C.x, WorldShape.CITY_LEVEL, WorldShape.CITY_C.y)
	f.spawn_flying(c + Vector3(400, 150, 280), (c + Vector3(0, 70, 0) - (c + Vector3(400, 150, 280))).normalized(), 17.0)
	await wait(1.8)
	ui(false)
	await shot("N04_city_night")
	ui(true)

	# ── S01: 아침 활공 (상점 스크린샷) ──
	main.day_night.set_time(6.7)
	f.spawn_flying(WorldShape.bay + Vector3(-300, 400, 200), Vector3(0.9, 0.02, -0.35).normalized(), 15.0)
	await wait(2.0)
	await shot("S01_soaring")

	# ── S02+S03: 급강하 → 명중 (PERFECT STOOP) ──
	main.day_night.set_time(10.0)
	f.spawn_flying(WorldShape.bay + Vector3(-150, 700, -250), Vector3(0.5, -0.05, 0.6).normalized(), 25.0)
	await wait(1.0)
	f.set_heading(Vector3(0.3, -0.9, 0.35).normalized())
	Input.action_press("tuck")
	await wait(3.0)
	await shot("S02_stoop")
	main.prey_mgr.contact.connect(func(_p, _h): _hit = true)
	var ahead := f.global_position + f.dir * f.speed * 1.2
	ahead.y = maxf(ahead.y, WorldShape.floor_y(ahead.x, ahead.z) + 25.0)
	var fl = main.prey_mgr.spawn_group("pigeon", ahead, ahead, 50.0, 3, "promo")
	for p in fl.members:
		p.global_position = ahead + Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
		p.vel = Vector3.ZERO
		p.t = p.t.duplicate()
		p.t["cruise"] = 0.0
		p.t["max"] = 0.0
		p.t["detect"] = 0.0
	var t0 := Time.get_ticks_msec()
	while not _hit and Time.get_ticks_msec() - t0 < 6000:
		await get_tree().process_frame
	await wait(0.12)
	await shot("S03_strike")
	Input.action_release("tuck")
	await wait(2.0)

	# ── S04: 밤 도시 사냥터 ──
	main.day_night.set_time(21.5)
	f.spawn_flying(c + Vector3(380, 140, 260), (c + Vector3(0, 70, 0) - (c + Vector3(380, 140, 260))).normalized(), 17.0)
	await wait(1.8)
	await shot("S04_city")

	# ── S05: 지도 ──
	main.menus.open_map()
	await wait(0.6)
	await shot("S05_map")

	get_tree().quit()
