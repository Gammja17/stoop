extends Node
## 개발용: 침입자 매 난이도 점검. godot --headless --path . -- --rivaltest

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
	main.day_night.set_time(11.0)
	var f: Falcon = main.falcon
	var life = main.life
	var t: Dictionary = WorldShape.thermals[0]
	f.spawn_flying(t.pos + Vector3(-30, 60, 0), Vector3(0, 0, 1), 18.0)
	life._spawn_rival()
	var r: RivalFalcon = life.rival
	var got_hit := [0]
	r.hit_player.connect(func(): got_hit[0] += 1)
	var attacks := 0
	var last_mode := r.mode
	var above_t := 0.0
	for i in 120:
		await wait(0.5)
		if r.mode == RivalFalcon.R.WARN and last_mode != RivalFalcon.R.WARN:
			attacks += 1
		last_mode = r.mode
		if f.global_position.y > r.global_position.y:
			above_t += 0.5
		if i % 10 == 0:
			print("[rival] t=%3ds me=%.0f rival=%.0f mode=%d" % [i / 2, f.global_position.y, r.global_position.y, r.mode])
	print("[rival] 60s: attacks=%d hits_on_me=%d time_above_rival=%.0fs need=%d" % [attacks, got_hit[0], above_t, r.need_hits])
	# 반격: 급강하 뒤 느려졌을 때 위에서 들이받기
	# 느려진 순간을 만들어 놓고 위에서 내리꽂는다
	r._recover()
	await wait(0.5)
	print("[rival] vulnerable=", r.vulnerable())
	var hits_before: int = r.hits
	var rp := r.global_position
	f.spawn_flying(rp + Vector3(0, 40, -20), (rp - (rp + Vector3(0, 40, -20))).normalized(), 45.0)
	Input.action_press("tuck")
	for k in 600:
		# 플레이어처럼 계속 침입자를 겨눈다
		var d := (r.global_position + r.vel * 0.2 - f.global_position).normalized()
		f.aim_yaw = atan2(-d.x, -d.z)
		f.aim_pitch = asin(clampf(d.y, -1.0, 1.0))
		f._aim_idle = 0.0
		await get_tree().process_frame
		if k % 60 == 0:
			print("[rival]   d=%.1f spd=%.0f state=%d" % [f.global_position.distance_to(r.global_position), f.speed, f.state])
		if r.hits > hits_before:
			break
	Input.action_release("tuck")
	print("[rival] strike test: hits %d -> %d mode=%d" % [hits_before, r.hits, r.mode])
	get_tree().quit()
