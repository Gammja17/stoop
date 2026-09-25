extends Node
## 개발용: 터치 조작 화면 배치와 가상 스틱. godot --path . -- --touchtest

var main


func _ready() -> void:
	main = get_parent()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.shots"))
	_run()


func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _run() -> void:
	await wait(2.0)
	main._enable_touch()
	main.start_new_game("시험", "m", "normal", false)
	await wait(2.5)
	var f: Falcon = main.falcon
	var yaw0: float = main.camera.orbit_yaw
	Falcon.touch_stick = Vector2(1, 0)
	await wait(1.0)
	Falcon.touch_stick = Vector2.ZERO
	print("[touch] perched orbit yaw %.2f -> %.2f" % [yaw0, main.camera.orbit_yaw])
	f.take_off()
	await wait(1.0)
	var ay: float = f.aim_yaw
	Falcon.touch_stick = Vector2(-1, 0)
	await wait(1.0)
	Falcon.touch_stick = Vector2.ZERO
	print("[touch] flying aim yaw %.2f -> %.2f  mouse=%d visible=%s" % [ay, f.aim_yaw, Input.mouse_mode, main.touch.visible])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.shots/T01_touch.png"))
	get_tree().quit()
