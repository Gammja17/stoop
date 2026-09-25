extends Node
## 개발용: 비행 모델 수치 점검 (활공 침하율, 상승기류, 급강하 최고속도, 빠져나오기 고도 손실).
## 사용: godot --headless --path . -- --flighttest

var main
var f: Falcon


func _ready() -> void:
	main = get_parent()
	_run()


func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func agl() -> float:
	var p := f.global_position
	return p.y - WorldShape.floor_y(p.x, p.z)


func _run() -> void:
	await wait(1.0)
	main.start_new_game("시험", "m", "normal", false)
	await wait(1.5)
	f = main.falcon
	var sea := Vector3(WorldShape.coast_x(-600) + 500.0, 0, -600)
	# 1) 활공
	f.spawn_flying(sea + Vector3(0, 300, 0), Vector3(0, 0, 1), 20.0)
	f.aim_pitch = 0.0
	var y0 := f.global_position.y
	for i in 10:
		await wait(1.0)
		f.aim_pitch = deg_to_rad(-6.0)
	print("[flight] glide 10s: dy=%.1f m  speed=%.1f km/h  stalled=%s" % [f.global_position.y - y0, f.kmh(), f.stalled])
	# 2) 날갯짓
	f.spawn_flying(sea + Vector3(0, 200, 0), Vector3(0, 0, 1), 15.0)
	f.aim_pitch = deg_to_rad(15.0)
	y0 = f.global_position.y
	Input.action_press("flap")
	await wait(5.0)
	Input.action_release("flap")
	print("[flight] flap 5s @15deg: dy=%.1f m  speed=%.1f km/h  stamina=%.0f" % [f.global_position.y - y0, f.kmh(), f.stamina])
	# 3) 상승기류 (중심에 붙잡아 두고 측정)
	var th: Dictionary = WorldShape.thermals[0]
	var tp: Vector3 = th.pos
	main.day_night.set_time(13.0)
	f.spawn_flying(tp + Vector3(0, 60, 0), Vector3(1, 0, 0), 16.0)
	y0 = f.global_position.y
	for i in 50:
		await wait(0.1)
		f.global_position.x = tp.x
		f.global_position.z = tp.z
		f.aim_pitch = deg_to_rad(-4.0)
	print("[flight] thermal 5s: climb=%.1f m (%.1f m/s)  in_thermal=%s" % [f.global_position.y - y0, (f.global_position.y - y0) / 5.0, f.in_thermal])
	# 4) 급강하
	f.spawn_flying(sea + Vector3(0, 700, 0), Vector3(0, -0.98, 0.2).normalized(), 25.0)
	f.aim_pitch = deg_to_rad(-80.0)
	Input.action_press("tuck")
	var t := 0.0
	var peak := 0.0
	while agl() > 160.0 and t < 30.0:
		await wait(0.5)
		t += 0.5
		peak = maxf(peak, f.kmh())
		f.aim_pitch = deg_to_rad(-80.0)
		if int(t * 2) % 2 == 0:
			print("[flight]   t=%.1fs  alt=%.0f  %.0f km/h" % [t, agl(), f.kmh()])
	print("[flight] stoop 540m: peak=%.0f km/h in %.1fs" % [peak, t])
	# 5) 빠져나오기
	Input.action_release("tuck")
	var a0 := agl()
	f.aim_pitch = deg_to_rad(5.0)
	t = 0.0
	while f.dir.y < -0.05 and t < 10.0 and f.state == Falcon.State.FLYING:
		await get_tree().process_frame
		t += get_process_delta_time()
		f.aim_pitch = deg_to_rad(5.0)
	print("[flight] pull-out from %.0f km/h: lost %.0f m in %.1fs, now %.0f km/h, state=%d" % [peak, a0 - agl(), t, f.kmh(), f.state])
	# 6) 충돌 판정
	f.spawn_flying(sea + Vector3(0, 30, 0), Vector3(0, -1, 0.1).normalized(), 60.0)
	f.aim_pitch = deg_to_rad(-85.0)
	await wait(1.5)
	print("[flight] crash into sea: state=%d  health=%.0f" % [f.state, float(GameState.falcon().health)])
	get_tree().quit()
