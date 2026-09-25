extends Node
## 개발용: 먼 섬들을 찍는다. godot --path . -- --islandtest

var main
var dir := "res://.shots/"


func _ready() -> void:
	main = get_parent()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_run()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(dir + name + ".png"))
	print("[isl] shot ", name, "  fps=", Engine.get_frames_per_second())


func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


## 섬을 향해 날며 한 장
func fly_shot(name: String, from: Vector3, look_at: Vector3, t := 1.2) -> void:
	var f: Falcon = main.falcon
	var d := (look_at - from).normalized()
	f.spawn_flying(from, d, 22.0)
	main.camera.mode = ChaseCamera.Mode.FOLLOW
	main.camera.begin_blend(0.0)
	await wait(t)
	await shot(name)


func _run() -> void:
	await wait(2.0)
	main.start_new_game("시험", "m", "normal", false)
	await wait(2.0)
	main.day_night.set_time(11.0)
	for isl: WorldShape.Island in WorldShape.islands:
		print("[isl] ", isl.id, " grid=", isl.nx, "x", isl.nz, " top=", isl.info.top, " keys=", isl.info.keys())
	var sb := WorldShape.island_by_id("seabird")
	var se := WorldShape.island_by_id("seals")
	var ba := WorldShape.island_by_id("bats")
	# 둥지에서 동쪽 바다를 바라보면 섬들이 보이는가
	await fly_shot("I01_from_eyrie", WorldShape.eyrie + Vector3(40, 90, 0), sb.center + Vector3(0, 60, 0))
	# 바닷새섬: 서쪽에서 다가가기, 동쪽 절벽
	await fly_shot("I02_seabird_west", sb.center + Vector3(-520, 110, 60), sb.center + Vector3(0, 40, 0))
	await fly_shot("I03_seabird_cliff", sb.center + Vector3(420, 45, 200), sb.info.colony)
	# 물범 모래톱
	await fly_shot("I04_seals", se.center + Vector3(-80, 70, 620), se.center + Vector3(0, 0, -100))
	# 박쥐섬: 서쪽의 동굴
	await fly_shot("I05_bats_cave", ba.info.cave + Vector3(-330, 40, -60), ba.info.cave + Vector3(0, 20, 0))
	await fly_shot("I06_bats_top", ba.center + Vector3(-300, 220, 250), ba.center + Vector3(0, 110, 0))
	# 바다 한가운데에서 경계 바깥으로
	var f: Falcon = main.falcon
	f.spawn_flying(Vector3(2950, 150, 0), Vector3.RIGHT, 22.0)
	await wait(4.0)
	print("[isl] boundary pos=", f.global_position, " dir=", f.dir)
	# 지도
	main.menus.open_map()
	await wait(0.6)
	await shot("I07_map")
	get_tree().quit()
