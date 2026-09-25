extends Node
## 개발용: 손을 뗀 채 상승기류에 들어가면 자동 선회로 올라가는지 잰다.
## godot --headless --path . -- --thermaltest

var main


func _ready() -> void:
	main = get_parent()
	_run()


func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _run() -> void:
	await wait(1.0)
	main.start_new_game("시험", "m", "normal", false)
	await wait(1.0)
	main.day_night.set_time(12.0)
	var f: Falcon = main.falcon
	for t in WorldShape.thermals.slice(0, 3):
		var c: Vector3 = t.pos
		# 기둥 가장자리 바깥에서 기둥 쪽으로, 옆으로 비껴 들어간다
		var start := c + Vector3(-t.r * 1.6, 70.0, t.r * 0.4)
		f.spawn_flying(start, (c + Vector3(0, 70, 0) - start).normalized(), 18.0)
		var y0 := f.global_position.y
		var auto_t := 0.0
		for i in 12:
			await wait(2.0)
			if f.auto_circle:
				auto_t += 2.0
			var d := Vector2(f.global_position.x - c.x, f.global_position.z - c.z).length()
			print("[thermal] r=%.0f t=%2ds alt=%+.0f dist=%.0f auto=%s spd=%.0f up=%.1f" % [t.r, (i + 1) * 2, f.global_position.y - y0, d, f.auto_circle, f.speed, f.updraft])
		print("[thermal] RESULT climb=%.0f m in 24 s, auto %.0f s" % [f.global_position.y - y0, auto_t])
	get_tree().quit()
