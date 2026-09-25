extends Node
## 개발용: 다이나믹 음악 상태 전환 점검. godot --headless --path . -- --musictest

var main


func _ready() -> void:
	main = get_parent()
	_run()


func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func log_state(tag: String) -> void:
	print("[music] %-14s state=%s cur=%s gain=%.1f" % [tag, main._mus_state, Sfx._music_cur, Sfx.music_gain])


func _run() -> void:
	await wait(1.0)
	main.start_new_game("시험", "m", "normal", false)
	await wait(2.0)
	main.day_night.set_time(9.0)
	var f: Falcon = main.falcon
	log_state("perched")
	f.spawn_flying(WorldShape.eyrie + Vector3(60, 300, 0), Vector3(1, 0, 0), 18.0)
	await wait(1.5)
	log_state("high")
	f.set_heading(Vector3(0.3, -0.9, 0.2).normalized())
	Input.action_press("tuck")
	await wait(3.0)
	log_state("stoop")
	Input.action_release("tuck")
	main._mus_after_hit = 6.0
	await wait(0.5)
	log_state("after hit")
	f.spawn_flying(WorldShape.eyrie + Vector3(60, 40, 0), Vector3(1, 0, 0), 18.0)
	await wait(14.0)
	log_state("calm again")
	main.life._spawn_rival()
	await wait(1.0)
	log_state("rival")
	get_tree().quit()
