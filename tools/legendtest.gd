extends Node
## 개발용: 해동청 퀘스트를 끝까지 진행. godot --path . -- --legendtest

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
	print("[lg] shot ", n)


func fly_to(p: Vector3) -> void:
	var f: Falcon = main.falcon
	f.spawn_flying(p + Vector3(-20, 3, 0), Vector3.RIGHT, 14.0)
	await wait(0.3)
	f.spawn_flying(p, Vector3.RIGHT, 14.0)
	await wait(0.4)


func _run() -> void:
	await wait(2.0)
	main.start_new_game("시험", "m", "normal", false)
	await wait(2.0)
	main.day_night.set_time(10.0)
	main.events._next = 9999.0
	var lg: LegendQuest = main.legend
	Growth.add_xp(120)
	await wait(0.5)
	print("[lg] stage=%d feathers=%s" % [lg.stage(), lg.feathers.keys()])
	var f: Falcon = main.falcon
	var sp: Vector3 = lg.feathers["start"].global_position
	f.spawn_flying(sp + Vector3(-60, 20, -40), (sp - (sp + Vector3(-60, 20, -40))).normalized(), 14.0)
	main.camera.mode = ChaseCamera.Mode.FOLLOW
	await wait(0.8)
	await shot("L01_start_feather")
	await fly_to(sp)
	print("[lg] stage=%d feathers=%s" % [lg.stage(), lg.feathers.keys()])
	var sbp: Vector3 = lg.feathers["seabird"].global_position
	f.spawn_flying(sbp + Vector3(160, 40, 120), (sbp - (sbp + Vector3(160, 40, 120))).normalized(), 14.0)
	await wait(0.8)
	await shot("L02_island_feather")
	for id in ["seabird", "seals", "bats"]:
		await fly_to(lg.feathers[id].global_position)
	print("[lg] stage=%d got=%s white=%s" % [lg.stage(), lg.q().got, lg.white != null])
	var wp: Vector3 = lg.white.global_position
	f.spawn_flying(wp + Vector3(-70, 10, 0), Vector3.RIGHT, 18.0)
	await wait(0.6)
	await shot("L03_white_falcon")
	print("[lg] stage=%d (3=chase)" % lg.stage())
	for i in 3:
		lg._tag_cd = 0.0
		f.spawn_flying(lg.white.global_position - Vector3(0, 0, 1), Vector3.RIGHT, 20.0)
		await wait(0.1)
		await wait(1.6)
	print("[lg] stage=%d white plumage=%s legend=%s" % [lg.stage(), Records.has_plumage("white"), Records.has("legend")])
	Growth.g()["plumage"] = "white"
	main.refresh_plumage()
	f.spawn_flying(WorldShape.eyrie + Vector3(40, 60, 0), Vector3(1, 0, 0.3).normalized(), 18.0)
	await wait(1.0)
	await shot("L04_white_plumage")
	get_tree().quit()
