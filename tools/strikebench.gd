extends Node
## 개발용: 고정 조건 명중률. 위에서 비둘기 한 마리를 향해 20번 급강하한다.
## godot --headless --path . -- --strikebench

var main
var hits := 0


func _ready() -> void:
	main = get_parent()
	_run()


func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _run() -> void:
	await wait(1.0)
	main.start_new_game("봇", "m", "normal", false)
	await wait(1.0)
	main.day_night.set_time(9.0)
	if main.get("events"):
		main.events._next = 99999.0
	var f: Falcon = main.falcon
	f.input_enabled = false
	main.prey_mgr.contact.connect(func(_p, how): if how == "air": hits += 1)
	seed(1234)
	var base := WorldShape.fields + Vector3(0, 0, 0)
	for trial in 20:
		var spot := base + Vector3(randf_range(-200, 200), 0, randf_range(-200, 200))
		spot.y = WorldShape.floor_y(spot.x, spot.z) + 40.0
		var fl = main.prey_mgr.spawn_group("pigeon", spot, spot, 40.0, 1, "bench")
		var p: Prey = fl.members[0]
		p.global_position = spot
		p.vel = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 14.0
		p.t = p.t.duplicate()
		p.t["detect"] = 0.0      # 알아채지 않게 (순수한 비행·조준 성능만 잰다)
		var a := randf() * TAU
		var start := spot + Vector3(cos(a) * 110.0, 150.0, sin(a) * 110.0)
		f.spawn_flying(start, (spot - start).normalized(), 30.0)
		Input.action_press("tuck")
		var before := hits
		for k in 360:
			await get_tree().physics_frame
			if not is_instance_valid(p) or hits > before:
				break
			var lead := p.global_position + p.vel * clampf(f.global_position.distance_to(p.global_position) / maxf(f.speed, 1.0), 0.0, 2.0)
			var d := (lead - f.global_position).normalized()
			f.aim_yaw = atan2(-d.x, -d.z)
			f.aim_pitch = asin(clampf(d.y, -1.0, 1.0))
			f._aim_idle = 0.0
			if f.global_position.y < p.global_position.y - 15.0 or f.state != Falcon.State.FLYING:
				break
		Input.action_release("tuck")
		if is_instance_valid(p):
			p.vanish()
		await wait(0.2)
	print("[bench] hits=%d/20" % hits)
	get_tree().quit()
