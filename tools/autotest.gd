extends Node
## 개발용 자동 점검: --autotest 인자로 실행하면 주요 장면을 돌며 스크린샷을 .shots/에 저장하고 종료한다.
## 사용: godot --path . -- --autotest

var main
var dir := "res://.shots/"
var _hit := false


func _ready() -> void:
	main = get_parent()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_run()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(dir + name + ".png"))
	print("[autotest] shot ", name, "  fps=", Engine.get_frames_per_second())


func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _run() -> void:
	await wait(3.0)
	await shot("01_title")
	main.start_new_game("시험", "m", "normal", false)
	await wait(2.5)
	await shot("02_eyrie")
	var f: Falcon = main.falcon
	f.take_off()
	Input.action_press("flap")
	await wait(2.0)
	Input.action_release("flap")
	await wait(1.0)
	await shot("03_takeoff")
	# 높은 곳에서 갯벌 쪽으로 급강하
	var start := WorldShape.bay + Vector3(-150, 700, -250)
	f.spawn_flying(start, Vector3(0.5, -0.05, 0.6).normalized(), 25.0)
	await wait(1.5)
	await shot("04_high")
	f.set_heading(Vector3(0.3, -0.9, 0.35).normalized())
	Input.action_press("tuck")
	await wait(4.5)
	await shot("05_stoop")
	# 진행 방향 앞에 비둘기 떼를 놓아 명중을 확인한다
	main.prey_mgr.contact.connect(func(_p, _h): _hit = true)
	var ahead := f.global_position + f.dir * f.speed * 1.2
	ahead.y = maxf(ahead.y, WorldShape.floor_y(ahead.x, ahead.z) + 20.0)
	var fl = main.prey_mgr.spawn_group("pigeon", ahead, ahead, 50.0, 1, "test")
	for p in fl.members:
		p.global_position = ahead
		p.vel = Vector3.ZERO
		p.t = p.t.duplicate()
		p.t["cruise"] = 0.0
		p.t["max"] = 0.0
		p.t["detect"] = 0.0
	f.set_heading((ahead - f.global_position).normalized())
	for i in 240:
		if _hit:
			break
		if not fl.members.is_empty() and is_instance_valid(fl.members[0]):
			f.aim_yaw = atan2(-(fl.members[0].global_position - f.global_position).x, -(fl.members[0].global_position - f.global_position).z)
			var dd: Vector3 = (fl.members[0].global_position - f.global_position).normalized()
			f.aim_pitch = asin(clampf(dd.y, -1.0, 1.0))
		await get_tree().process_frame
	await shot("06_strike")
	Input.action_release("tuck")
	await wait(0.3)
	print("[autotest] cam mode=", main.camera.mode, " pos=", main.camera.global_position, " falcon=", main.falcon.global_position)
	await shot("07_after_strike")
	await wait(0.25)
	await shot("07b_killcam")
	await wait(1.5)
	await shot("08_after2")
	# 맵과 메뉴
	main.menus.open_map()
	await wait(0.5)
	await shot("09_map")
	main.menus.resume()
	main.menus.open_pause()
	await wait(0.3)
	await shot("10_pause")
	main.menus.resume()
	# 둥지 착지
	f.spawn_perched({"pos": WorldShape.eyrie, "kind": "eyrie", "facing": WorldShape.eyrie_facing})
	main.camera.mode = ChaseCamera.Mode.ORBIT
	await wait(1.0)
	main.menus.open_rest()
	await wait(0.3)
	await shot("11_rest")
	main.menus.resume()
	# 해질녘 절벽
	main.day_night.set_time(18.9)
	f.spawn_flying(WorldShape.eyrie + Vector3(80, 40, 60), Vector3(-1, -0.1, 0).normalized(), 20.0)
	await wait(2.0)
	await shot("12_dusk")
	main.day_night.set_time(22.5)
	await wait(1.5)
	await shot("13_night")
	# 겨울
	main.day_night.set_time(11.0)
	main.world.set_season(3)
	main.world.set_snow(1.0)
	GameState.data["season"] = 3
	main.day_night.apply_weather("snow", true)
	f.spawn_flying(WorldShape.village + Vector3(80, 60, -120), Vector3(-0.3, -0.2, 1).normalized(), 22.0)
	await wait(2.0)
	await shot("14_winter")
	get_tree().quit()
