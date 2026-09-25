extends Node
## 개발용: 모든 메뉴 화면을 찍는다. godot --path . -- --menutest

var main


func _ready() -> void:
	main = get_parent()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.shots"))
	_run()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.shots/" + name + ".png"))


func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _run() -> void:
	await wait(3.0)
	var m = main.menus
	m.open_new_game()
	await wait(0.6)
	await shot("U01_newgame")
	m.open_settings("title")
	await wait(0.4)
	await shot("U02_settings")
	m.open_controls("title")
	await wait(0.4)
	await shot("U03_controls")
	m.open_credits()
	await wait(0.4)
	await shot("U04_credits")
	Records.unlock("first_hunt")
	m.open_records("title")
	await wait(0.4)
	await shot("U07_records")
	Settings.lang = "en"
	Loc.lang = "en"
	m.open_title()
	await wait(0.8)
	await shot("U05_title_en")
	Settings.lang = "ko"
	Loc.lang = "ko"
	main.start_new_game("시험", "m", "normal", false)
	await wait(3.0)
	await shot("U06_start")
	get_tree().quit()
