class_name Gull
extends Node3D
## 갈매기: 해안을 맴돌다가 매가 먹이를 들고 있으면 빼앗으러 온다. 떨어진 먹이도 채간다.

enum G { SOAR, HARASS, FETCH, CARRY, FLEE }

var state := G.SOAR
var vel := Vector3.ZERO
var center := Vector3.ZERO
var radius := 90.0
var alt := 35.0
var model: BirdModel
var prey: Prey = null
var _t := 0.0
var _think := 0.0
var _flap := 0.0
var _angle := 0.0
var _harass_t := 0.0
var _flee_t := 0.0
var _carry_t := 0.0
var prev := Vector3.ZERO


func setup(c: Vector3, spec: String = "gull") -> Gull:
	center = c
	radius = randf_range(60.0, 140.0)
	alt = randf_range(20.0, 60.0)
	_angle = randf() * TAU
	position = c + Vector3(cos(_angle) * radius, alt, sin(_angle) * radius)
	prev = position
	model = BirdModel.new()
	add_child(model)
	model.setup(spec)
	return self


func _main():
	return get_tree().get_first_node_in_group("main")


func _process(delta: float) -> void:
	prev = global_position
	_t += delta
	_think -= delta
	var m = _main()
	if m == null:
		return
	var f: Falcon = m.falcon
	var desired := Vector3.ZERO
	match state:
		G.SOAR:
			_angle += delta * 12.0 / radius
			var p := center + Vector3(cos(_angle) * radius, 0, sin(_angle) * radius)
			p.y = WorldShape.floor_y(p.x, p.z) + alt
			desired = (p - global_position).normalized() * 12.0
			if _think <= 0.0:
				_think = randf_range(2.0, 3.5)
				_decide(m, f)
		G.HARASS:
			_harass_t += delta
			if f == null or f.carrying == null or _harass_t > 16.0:
				state = G.SOAR
			else:
				var lead := f.global_position + f.velocity * 0.4
				desired = (lead - global_position).normalized() * 19.5
				var d := global_position.distance_to(f.global_position)
				if d < 2.4 and (f.speed < 24.0 or f.state != Falcon.State.FLYING):
					m.gull_steal(self)
				if randf() < delta * 0.5:
					Sfx.play_at("gull", global_position, -2.0, randf_range(0.9, 1.1), 300.0)
		G.FETCH:
			if prey == null or not is_instance_valid(prey) or not prey.is_loose() or prey.carrier != null:
				prey = null
				state = G.SOAR
			else:
				var tp := prey.global_position + Vector3.UP * 0.4
				desired = (tp - global_position).normalized() * 16.0
				if global_position.distance_to(tp) < 1.6:
					take_prey(prey)
		G.CARRY:
			_carry_t += delta
			var away := center + Vector3(600, 0, 0)
			away.y = 40.0
			desired = (away - global_position).normalized() * 14.0
			if _carry_t > 12.0 and prey and is_instance_valid(prey):
				prey.vanish()
				prey = null
				state = G.SOAR
		G.FLEE:
			_flee_t -= delta
			var away2 := global_position - (f.global_position if f else center)
			away2.y = 0.0
			desired = away2.normalized() * 17.0 + Vector3.UP * 3.0
			if _flee_t <= 0.0:
				state = G.SOAR
	var p2 := global_position
	var gy := WorldShape.floor_y(p2.x, p2.z)
	if p2.y < gy + 6.0 and state != G.FETCH and state != G.HARASS:
		desired.y += 6.0
	vel = vel.lerp(desired, 1.0 - exp(-1.8 * delta))
	position += vel * delta
	if position.y < gy + 0.4:
		position.y = gy + 0.4
	_animate(delta)


func _decide(m, f: Falcon) -> void:
	if f and f.carrying and global_position.distance_to(f.global_position) < 110.0 and randf() < 0.45:
		state = G.HARASS
		_harass_t = 0.0
		Sfx.play_at("gull", global_position, 2.0, 1.0, 400.0)
		GameState.say(Loc.t("gull_warn"), "warn")
		return
	# 떨어진 먹이 찾기
	for p in m.prey_mgr.prey:
		if is_instance_valid(p) and p.is_loose() and p.state != Prey.S.STUNNED and not p.claimed and p.global_position.distance_to(global_position) < 260.0:
			p.claimed = true
			prey = p
			state = G.FETCH
			return


func take_prey(p: Prey) -> void:
	prey = p
	p.take(self)
	state = G.CARRY
	_carry_t = 0.0
	Sfx.play_at("gull", global_position, 0.0, 1.1, 300.0)


func talon_point() -> Vector3:
	return global_transform * Vector3(0, -0.3 * BirdModel.VISUAL, 0)


func knocked() -> void:
	if prey and is_instance_valid(prey) and state == G.CARRY:
		prey.released(vel * 0.5)
		prey = null
	state = G.FLEE
	_flee_t = 20.0
	vel = vel * 0.3 + Vector3.UP * 6.0
	Sfx.play_at("gull", global_position, 4.0, 1.4, 400.0)


func _animate(delta: float) -> void:
	var soar := state == G.SOAR and fmod(_t, 6.0) > 2.0
	_flap += delta * (2.0 if soar else 9.0)
	model.flap_phase = _flap
	model.flap_amp = lerpf(model.flap_amp, 0.06 if soar else 0.6, 1.0 - exp(-5.0 * delta))
	model.talons_out = 1.0 if state == G.CARRY else 0.0
	if vel.length() > 0.5 and absf(vel.normalized().y) < 0.97:
		global_basis = global_basis.slerp(Basis.looking_at(vel.normalized(), Vector3.UP), 1.0 - exp(-6.0 * delta)).orthonormalized()
	model.pose(delta)
