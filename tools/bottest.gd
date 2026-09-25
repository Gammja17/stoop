extends Node
## 개발용: 조준/날개 접기/날갯짓 입력만으로 사냥하는 간단한 봇. 사냥이 실제로 가능한지와 결과 비율을 본다.
## 사용: godot --headless --path . -- --bottest

var main
var f: Falcon
var results := {"strike": 0, "bind": 0, "catch": 0, "pickup": 0, "dodged": 0, "bounced": 0, "crash": 0}
var t := 0.0
var target: Prey = null
var retarget_t := 0.0
var max_kmh := 0.0
var _log_t := 0.0
var mode := "climb"
const DURATION := 150.0


func _ready() -> void:
	main = get_parent()
	_run()


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	main.start_new_game("봇", "m", "normal", false)
	await get_tree().create_timer(1.5).timeout
	f = main.falcon
	main.prey_mgr.contact.connect(_on_contact)
	f.crashed.connect(func(_i, _d): results.crash += 1)
	main.day_night.set_time(9.0)
	f.spawn_flying(WorldShape.bay + Vector3(-100, 200, -150), Vector3(1, 0, 0), 25.0)


func _on_contact(p: Prey, how: String) -> void:
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	if how == "catch":
		results.catch += 1
	elif how == "pickup":
		results.pickup += 1
	elif p.state == Prey.S.STUNNED:
		results.strike += 1
	elif p.state == Prey.S.CARRIED:
		results.bind += 1
	elif p.kind == "duck":
		results.bounced += 1
	else:
		results.dodged += 1


func _process(delta: float) -> void:
	if f == null or not main.playing:
		return
	t += delta
	max_kmh = maxf(max_kmh, f.kmh())
	if t > DURATION:
		print("[bot] %ds  results=%s  max=%d km/h  prey_total=%d  energy=%d  health=%d" % [int(DURATION), str(results), int(max_kmh), int(GameState.stats().prey_total), int(GameState.falcon().energy), int(GameState.falcon().health)])
		get_tree().quit()
		return
	if f.state == Falcon.State.PERCHED:
		f.take_off()
		return
	if f.state != Falcon.State.FLYING:
		return
	# 들고 있으면 날면서 먹거나 버린다
	if f.carrying:
		var cp := f.carrying as Prey
		f.carrying = null
		if cp:
			cp.vanish()
		target = null
	retarget_t -= delta
	if target == null or not is_instance_valid(target) or retarget_t <= 0.0 or target.state == Prey.S.CARRIED or target.state == Prey.S.GONE or target.state == Prey.S.SWIM:
		retarget_t = 4.0
		target = _pick()
	var p := f.global_position
	var aim := Vector3.ZERO
	var tuck := false
	var flap := false
	if target == null:
		aim = (WorldShape.bay + Vector3(0, 220, 0) - p)
		flap = p.y < 150.0 and f.stamina > 40.0
		mode = "climb"
	else:
		var tp := target.global_position
		var rel := tp - p
		var horiz := Vector2(rel.x, rel.z).length()
		var adv := -rel.y
		if target.state == Prey.S.STUNNED or target.state == Prey.S.GROUND or target.state == Prey.S.WATER:
			mode = "fetch"
			aim = rel + target.vel * 0.3
			if target.state != Prey.S.STUNNED:
				aim.y += 2.0
			flap = f.speed < 22.0
		else:
			if mode == "stoop" and (adv < -5.0 or agl() < 30.0):
				mode = "climb"
			if mode != "stoop" and adv > 110.0 and horiz < adv * 1.2:
				mode = "stoop"
			if mode == "climb" or mode == "fetch":
				mode = "climb"
				# 목표 근처를 돌며 날갯짓으로 높이를 번다
				var orbit := Vector3(rel.x, 0, rel.z)
				if horiz > 90.0:
					aim = orbit.normalized() * 50.0 + Vector3(0, 18, 0)
				else:
					aim = orbit.normalized().rotated(Vector3.UP, 1.4) * 50.0 + Vector3(0, 20, 0)
				flap = f.stamina > 25.0 or f.speed < 14.0
			else:
				var s := maxf(f.speed, 10.0)
				var v := target.vel
				var a := v.dot(v) - s * s
				var b := 2.0 * rel.dot(v)
				var c := rel.dot(rel)
				var disc := b * b - 4.0 * a * c
				var lead := tp
				if disc >= 0.0 and absf(a) > 0.001:
					var t1 := (-b - sqrt(disc)) / (2.0 * a)
					var t2 := (-b + sqrt(disc)) / (2.0 * a)
					var tt := minf(t1, t2) if minf(t1, t2) > 0.0 else maxf(t1, t2)
					if tt > 0.0:
						lead = tp + v * tt
				aim = lead - p
				tuck = agl() > 25.0 and rel.length() > 45.0
				if agl() < 80.0 and f.velocity.y < -40.0:
					tuck = false
	_log_t -= delta
	if _log_t <= 0.0:
		_log_t = 3.0
		if target:
			var rr := target.global_position - p
			print(("[bot] t=%.0f %s tgt=%s st=%d dist=%.0f adv=%.0f  f: alt=%.0f %.0fkmh tuck=%.1f stam=%.0f") % [t, mode, target.kind, target.state, rr.length(), -rr.y, agl(), f.kmh(), f.tuck, f.stamina])
		else:
			print("[bot] t=%.0f no target  alt=%.0f" % [t, agl()])
	if aim.length() > 0.01:
		var d := aim.normalized()
		f.aim_yaw = atan2(-d.x, -d.z)
		f.aim_pitch = clampf(asin(clampf(d.y, -1.0, 1.0)), deg_to_rad(-85.0), deg_to_rad(60.0))
	# 너무 낮으면 빠져나온다
	if agl() < 35.0 and f.velocity.y < -8.0:
		tuck = false
		f.aim_pitch = deg_to_rad(20.0)
	_act("tuck", tuck)
	_act("flap", flap)


func agl() -> float:
	var p := f.global_position
	return p.y - WorldShape.floor_y(p.x, p.z)


func _act(action: StringName, on: bool) -> bool:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)
	return true


func _pick() -> Prey:
	var best: Prey = null
	var bd := 900.0
	for p in main.prey_mgr.prey:
		if not is_instance_valid(p):
			continue
		if not (p.state == Prey.S.FLY or p.state == Prey.S.FLEE or p.state == Prey.S.STUNNED or p.state == Prey.S.GROUND or p.state == Prey.S.WATER):
			continue
		var d: float = p.global_position.distance_to(f.global_position)
		if p.state == Prey.S.STUNNED:
			d *= 0.2
		if d < bd:
			bd = d
			best = p
	return best
