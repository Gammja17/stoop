extends Node
## 개발용: 새 모델을 가까이서 찍어 본다.
## 사용: godot --path . -- --modeltest

var main


func _ready() -> void:
	main = get_parent()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.shots"))
	_run()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.shots/" + name + ".png"))


func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	main.menus.close_all()
	main.menus.title.visible = false
	var base := Vector3(0, 300, 0)
	var ids := ["falcon", "falcon_f", "juvenile", "pigeon", "duck", "gull", "owl", "starling", "sandpiper"]
	var models := []
	for i in ids.size():
		var m := BirdModel.new()
		main.add_child(m)
		m.setup(ids[i])
		m.global_position = base + Vector3((i - 4) * 1.6, 0, 0)
		m.flap_phase = 1.2
		m.flap_amp = 0.35
		m.pose(0.016)
		models.append(m)
	main.falcon.visible = false
	var cam: ChaseCamera = main.camera
	cam.mode = ChaseCamera.Mode.CINEMATIC
	cam.set_process(false)
	main.day_night.set_time(12.0)
	# 위에서
	cam.global_position = base + Vector3(0, 6, 5)
	cam.look_at(base, Vector3.UP)
	cam.fov = 60
	await get_tree().create_timer(0.5).timeout
	await shot("M01_above")
	# 아래에서
	cam.global_position = base + Vector3(0, -5, 4)
	cam.look_at(base, Vector3.UP)
	await get_tree().create_timer(0.3).timeout
	await shot("M02_below")
	# 매 접은 날개(급강하)
	for m in models:
		m.fold = 1.0
		m.flap_amp = 0.0
		m.talons_out = 1.0
		m.pose(0.016)
	cam.global_position = base + Vector3(-2, 2.5, 3)
	cam.look_at(base + Vector3(-3, 0, 0), Vector3.UP)
	await get_tree().create_timer(0.3).timeout
	await shot("M03_tucked")
	get_tree().quit()
