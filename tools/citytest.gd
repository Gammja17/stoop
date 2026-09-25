extends Node
## 개발용: 도시 스크린샷과 옥상 착지·벽 충돌. godot --path . -- --citytest

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
	print("[city] shot ", n, " fps=", Engine.get_frames_per_second())


func _run() -> void:
	await wait(2.0)
	main.start_new_game("시험", "m", "normal", false)
	await wait(2.0)
	main.day_night.set_time(10.5)
	main.events._next = 9999.0
	var f: Falcon = main.falcon
	var c := Vector3(WorldShape.CITY_C.x, WorldShape.CITY_LEVEL, WorldShape.CITY_C.y)
	print("[city] buildings=", WorldShape.buildings.size(), " tower=", WorldShape.city_tower, " roof=", WorldShape.roof_at(WorldShape.city_tower.x, WorldShape.city_tower.z))
	f.spawn_flying(c + Vector3(420, 160, 300), (c + Vector3(0, 60, 0) - (c + Vector3(420, 160, 300))).normalized(), 18.0)
	main.camera.mode = ChaseCamera.Mode.FOLLOW
	await wait(1.5)
	await shot("C01_city_day")
	f.spawn_flying(c + Vector3(150, 70, 60), Vector3(-1, -0.05, 0).normalized(), 18.0)
	await wait(1.2)
	await shot("C02_canyon")
	# 타워 옥상 착지
	var tw: Vector3 = WorldShape.city_tower
	var top := WorldShape.roof_at(tw.x, tw.z)
	f.spawn_flying(Vector3(tw.x - 12, top + 3, tw.z), Vector3.RIGHT, 12.0)
	await wait(0.1)
	var ok := f.try_land()
	await wait(1.0)
	print("[city] tower land try=%s state=%d y=%.1f roof=%.1f" % [ok, f.state, f.global_position.y, top])
	main.camera.orbit_dist = 5.0
	await wait(1.0)
	await shot("C03_tower_roof")
	# 벽 충돌
	var b: Dictionary = WorldShape.buildings[5]
	var mid: Vector3 = (b.min + b.max) * 0.5
	f.spawn_flying(Vector3(b.min.x - 15, mid.y, mid.z), Vector3.RIGHT, 20.0)
	await wait(1.5)
	print("[city] wall hit state=%d y=%.1f street=%.1f" % [f.state, f.global_position.y, WorldShape.CITY_LEVEL])
	# 밤
	main.day_night.set_time(21.5)
	f.spawn_flying(c + Vector3(380, 130, 260), (c + Vector3(0, 60, 0) - (c + Vector3(380, 130, 260))).normalized(), 18.0)
	main.camera.mode = ChaseCamera.Mode.FOLLOW
	await wait(1.5)
	await shot("C04_city_night")
	main.menus.open_map()
	await wait(0.5)
	await shot("C05_map")
	get_tree().quit()
