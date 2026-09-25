extends Node
## 개발용: 폭풍(번개·돌풍·새떼 피난)을 찍는다. godot --path . -- --stormtest

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
	print("[storm] shot ", n)


func _run() -> void:
	await wait(2.0)
	main.start_new_game("시험", "m", "normal", false)
	await wait(2.0)
	main.day_night.set_time(11.5)
	main.life._storm_at = 12
	main.life.on_hour(12)
	var f: Falcon = main.falcon
	f.spawn_flying(WorldShape.eyrie + Vector3(60, 80, 0), Vector3(1, 0, 0.3).normalized(), 18.0)
	main.camera.mode = ChaseCamera.Mode.FOLLOW
	await wait(22.0)
	var g_min := 99.0
	var g_max := -99.0
	for i in 40:
		await wait(0.1)
		g_min = minf(g_min, main.day_night.gust)
		g_max = maxf(g_max, main.day_night.gust)
	print("[storm] storm=%.2f gust %.1f..%.1f wind=%.1f weather=%s" % [main.day_night.cur.storm, g_min, g_max, main.day_night.wind.length(), GameState.data.weather])
	await shot("S01_storm")
	main.day_night._strike()
	await wait(0.05)
	await shot("S02_lightning")
	var n := 0
	for fl in main.prey_mgr.flocks:
		if is_instance_valid(fl) and fl.get_meta("habitat", "") == "storm_flock":
			n += fl.members.size()
	print("[storm] storm flock birds=", n)
	get_tree().quit()
