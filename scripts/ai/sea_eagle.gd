class_name SeaEagle
extends AIFalcon
## 흰꼬리수리: 물범 모래톱의 바위 언덕에 앉아 있다가 먹이를 든 매를 보면 빼앗으러 온다.
## 느리지만 끈질기다. 빠르게 들이받으면 물러난다(실제 송골매도 수리를 급강하로 쫓아낸다).

enum E { PERCH, SOAR, CHASE, FETCH, HOME, FLEE }

const CHASE_SPEED := 21.0

var mode := E.PERCH
var home := Vector3.ZERO
var timer := 0.0
var prey: Prey = null
var _think := 0.0
var _call_t := 0.0
var _angle := 0.0


func setup(knoll: Vector3) -> SeaEagle:
	home = knoll + Vector3(0, 0.4, 0)
	position = home
	init_model("eagle")
	flap_rate = 5.5
	perched = true
	perch_pos = home
	perch_facing = Vector3.LEFT
	return self


func _process(delta: float) -> void:
	timer -= delta
	_think -= delta
	_call_t -= delta
	var m = main_node()
	if m == null:
		return
	var f: Falcon = m.falcon
	match mode:
		E.PERCH:
			if is_landing():
				update_landing(delta)
			elif perched:
				vel = Vector3.ZERO
			if _think <= 0.0 and not is_landing():
				_think = randf_range(0.8, 1.2)
				_decide(m, f)
				if mode == E.PERCH and randf() < 0.02:
					_soar(40.0)
		E.SOAR:
			_angle += delta * 9.0 / 160.0
			var tp := home + Vector3(cos(_angle) * 160.0, 70.0 + sin(_angle * 2.0) * 15.0, sin(_angle) * 220.0)
			steer((tp - global_position).normalized() * 10.0, delta, 0.9)
			if _think <= 0.0:
				_think = randf_range(0.8, 1.2)
				_decide(m, f)
				if mode == E.SOAR and timer <= 0.0:
					_go_home()
		E.CHASE:
			if f.carrying == null or timer <= 0.0 or global_position.distance_to(f.global_position) > 650.0:
				_soar(20.0)
			else:
				var lead := f.global_position + f.velocity * 0.5
				steer((lead - global_position).normalized() * CHASE_SPEED, delta, 1.6)
				if _call_t <= 0.0:
					_call_t = randf_range(2.0, 3.5)
					Sfx.play_at("eagle", global_position, 2.0, randf_range(0.95, 1.05), 600.0)
				if global_position.distance_to(f.global_position) < 3.2 and (f.speed < 28.0 or not f.is_flying()):
					m.eagle_steal(self)
		E.FETCH:
			if prey == null or not is_instance_valid(prey) or not prey.is_loose() or prey.carrier != null:
				prey = null
				_soar(20.0)
			else:
				var tp2 := prey.global_position + Vector3.UP * 0.8
				steer((tp2 - global_position).normalized() * 14.0, delta, 1.6)
				if global_position.distance_to(tp2) < 2.2:
					take_prey(prey)
					_go_home()
		E.HOME:
			# 바위 언덕으로 돌아가 앉는다. 먹이가 있으면 거기서 먹는다
			if is_landing():
				if update_landing(delta):
					timer = 25.0
			elif perched:
				if carrying == null or timer <= 0.0:
					if carrying and is_instance_valid(carrying):
						carrying.vanish()
					carrying = null
					prey = null
					mode = E.PERCH
			else:
				var to := home - global_position
				if to.length() < 12.0:
					perch_at(home, Vector3.LEFT)
				else:
					var tp3 := home + Vector3(0, minf(to.length() * 0.2, 40.0), 0)
					steer((tp3 - global_position).normalized() * 12.0, delta, 1.2)
		E.FLEE:
			var away := global_position - f.global_position
			away.y = 0.0
			steer(away.normalized() * 15.0 + Vector3.UP * 4.0, delta, 1.0)
			if timer <= 0.0:
				_soar(15.0)
	animate(delta)


func _decide(m, f: Falcon) -> void:
	if f.carrying and f.global_position.distance_to(home) < 400.0 and f.global_position.y < home.y + 260.0:
		mode = E.CHASE
		timer = 25.0
		_call_t = 0.0
		m.eagle_warn(self)
		return
	for p in m.prey_mgr.prey:
		if is_instance_valid(p) and p.is_loose() and p.state != Prey.S.STUNNED and not p.claimed and p.global_position.distance_to(home) < 320.0:
			p.claimed = true
			prey = p
			mode = E.FETCH
			return


func _soar(t: float) -> void:
	mode = E.SOAR
	timer = t
	perched = false
	_angle = atan2(global_position.z - home.z, global_position.x - home.x)


func _go_home() -> void:
	mode = E.HOME


func take_hit(from_vel: Vector3) -> void:
	if mode == E.FLEE:
		return
	if carrying and is_instance_valid(carrying):
		carrying.released(vel * 0.5)
	carrying = null
	prey = null
	perched = false
	_land_t = -1.0
	mode = E.FLEE
	timer = 14.0
	vel = from_vel * 0.3 + Vector3.UP * 5.0
	Sfx.play_at("eagle", global_position, 6.0, 1.25, 700.0)


func talon_point() -> Vector3:
	return global_transform * Vector3(0, -0.5 * BirdModel.VISUAL, 0.05)
