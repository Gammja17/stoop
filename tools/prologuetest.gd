extends Node
## 개발용: 프롤로그(알 → 어미 교육 → 1년 뒤 봄)를 빠르게 훑으며 화면과 단계 전환을 점검한다.
## 사용: godot --path . -- --prologuetest

var main
var pro: Prologue
var dlg


func _ready() -> void:
	main = get_parent()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.shots"))
	_run()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.shots/" + name + ".png"))
	print("[pro] shot %s  stage=%d" % [name, pro.stage])


func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


## 막혀 있는 대사를 넘긴다
func skip_lines(max_t: float) -> void:
	var t := 0.0
	while t < max_t:
		if dlg.waiting:
			dlg.text_l.visible_characters = -1
			dlg.waiting = false
			dlg.advanced.emit()
		await wait(0.2)
		t += 0.2


func _run() -> void:
	await wait(2.5)
	pro = main.prologue
	dlg = main.dialog
	main.start_new_game("시험", "m", "normal", true)
	await wait(2.5)
	await shot("P01_egg")
	for i in 5:
		pro._crack()
		await wait(0.15)
	await shot("P02_cracking")
	for i in 5:
		pro._crack()
		await wait(0.15)
	await wait(1.6)
	await shot("P03_hatched")
	await skip_lines(8.0)
	await wait(1.0)
	await shot("P04_juvenile")
	await skip_lines(1.5)
	var f: Falcon = main.falcon
	f.take_off()
	Input.action_press("flap")
	await wait(3.2)
	Input.action_release("flap")
	await shot("P05_follow")
	main.camera.toggle_view()
	await wait(1.0)
	await shot("P05b_firstperson")
	main.camera.toggle_view()
	var tp: Vector3 = pro._thermal.pos
	f.spawn_flying(tp + Vector3(20, 60, 0), Vector3(0, 0, 1), 18.0)
	await wait(1.5)
	await shot("P06_thermal")
	f.spawn_flying(tp + Vector3(0, 175, 0), Vector3(0, 0, 1), 18.0)
	await wait(0.5)
	await wait(5.5)
	await shot("P07_stoop_line")
	f.spawn_flying(tp + Vector3(100, 420, 0), Vector3(0.2, -0.97, 0).normalized(), 30.0)
	f.aim_pitch = deg_to_rad(-80.0)
	Input.action_press("tuck")
	await wait(4.0)
	Input.action_release("tuck")
	f.aim_pitch = deg_to_rad(10.0)
	for i in 10:
		await wait(0.5)
		print("[pro]   dir.y=%.2f spd=%.0f aim=%.0f tuck=%.2f state=%d stalled=%s agl=%.0f peak=%.0f" % [f.dir.y, f.kmh(), rad_to_deg(f.aim_pitch), f.tuck, f.state, f.stalled, f.global_position.y - WorldShape.floor_y(f.global_position.x, f.global_position.z), pro._peak])
	await shot("P08_catch")
	await wait(4.0)
	if pro._gift and is_instance_valid(pro._gift):
		var gp: Vector3 = pro._gift.global_position
		f.spawn_flying(gp + Vector3(0, -1.0, -6.0), Vector3(0, 0, 1), 18.0)
	await wait(1.0)
	await wait(2.5)
	await shot("P09_eat")
	f.land_at({"pos": WorldShape.eyrie, "kind": "eyrie", "facing": WorldShape.eyrie_facing}, true)
	await wait(0.5)
	main._start_eating()
	await wait(3.5)
	await wait(3.5)
	await shot("P10_hunt")
	if pro._flock and not pro._flock.members.is_empty():
		var p: Prey = pro._flock.members[0]
		f.spawn_flying(p.global_position + Vector3(0, 20, 0), Vector3.DOWN, 70.0)
		f.speed = 70.0
		main._on_contact(p, "air")
	for i in 60:
		if pro.stage == Prologue.St.HOME:
			break
		await wait(0.2)
	await wait(0.5)
	await shot("P11_home")
	f.spawn_flying(WorldShape.eyrie + WorldShape.eyrie_facing * 8.0 + Vector3(0, 3, 0), -WorldShape.eyrie_facing, 12.0)
	await wait(0.2)
	f.land_at({"pos": WorldShape.eyrie, "kind": "eyrie", "facing": WorldShape.eyrie_facing}, true)
	await wait(1.5)
	await shot("P12_bye")
	await skip_lines(10.0)
	await wait(6.0)
	await shot("P13_spring")
	print("[pro] done prologue=%d active=%s season=%d" % [int(GameState.data.get("prologue", -9)), pro.active, int(GameState.data.get("season", -1))])
	GameState.delete_save()
	get_tree().quit()
