class_name Fox
extends Node3D
## 여우: 본섬 들판과 숲 가장자리를 돌아다닌다.
## 땅에 떨어진 먹이를 물어 가고, 땅에 앉아 먹는 매에게 몰래 다가와 덮친다.

enum X { WANDER, REST, TO_PREY, CARRY, STALK, POUNCE }

var mode := X.WANDER
var home := Vector3.ZERO
var home_r := 260.0
var target := Vector3.ZERO
var vel := Vector3.ZERO
var model: Node3D
var legs: Array = []
var tail: Node3D
var head: Node3D
var prey: Prey = null
var warned := false
var _think := 0.0
var _gait := 0.0
var _timer := 0.0


func setup(p_home: Vector3, r: float) -> Fox:
	home = p_home
	home_r = r
	position = _land_point(home, 60.0)
	model = CritterModel.fox()
	add_child(model)
	var lg := model.get_node("legs")
	for c in lg.get_children():
		legs.append(c)
	tail = model.get_node("body/tail")
	head = model.get_node("body/head")
	_pick_target()
	return self


func _main():
	return get_tree().get_first_node_in_group("main")


## 물이 아니고 너무 가파르지 않은 땅 한 점
func _land_point(c: Vector3, r: float) -> Vector3:
	for i in 20:
		var a := randf() * TAU
		var rr := sqrt(randf()) * r
		var p := c + Vector3(cos(a) * rr, 0, sin(a) * rr)
		p.y = WorldShape.ground(p.x, p.z)
		if p.y > 2.0 and WorldShape.normal(p.x, p.z).y > 0.8 and WorldShape.island_near(p, 100.0) == null:
			return p
	var q := c
	q.y = WorldShape.ground(c.x, c.z)
	return q


func _pick_target() -> void:
	target = _land_point(home, home_r)


func _process(delta: float) -> void:
	_think -= delta
	_timer -= delta
	var m = _main()
	if m == null:
		return
	var f: Falcon = m.falcon
	var spd := 0.0
	match mode:
		X.WANDER:
			spd = 3.2
			if _flat_dist(target) < 3.0:
				mode = X.REST
				_timer = randf_range(3.0, 9.0)
			if _think <= 0.0:
				_think = randf_range(0.7, 1.1)
				_look_around(m, f)
		X.REST:
			spd = 0.0
			if _timer <= 0.0:
				_pick_target()
				mode = X.WANDER
			if _think <= 0.0:
				_think = randf_range(0.7, 1.1)
				_look_around(m, f)
		X.TO_PREY:
			spd = 8.0
			if prey == null or not is_instance_valid(prey) or prey.state != Prey.S.GROUND or prey.carrier != null:
				prey = null
				mode = X.WANDER
			else:
				target = prey.global_position
				if _flat_dist(target) < 1.2:
					prey.take(self)
					mode = X.CARRY
					_timer = 14.0
					var away := global_position - f.global_position
					away.y = 0.0
					target = _land_point(global_position + away.normalized() * 120.0, 40.0)
					Sfx.play_at("step", global_position, -2.0, 0.8, 120.0)
		X.CARRY:
			spd = 6.5
			if _flat_dist(target) < 3.0:
				target = _land_point(global_position, 80.0)
			if _timer <= 0.0:
				if prey and is_instance_valid(prey):
					prey.vanish()
				prey = null
				mode = X.WANDER
				_pick_target()
		X.STALK:
			spd = 1.8
			if not _falcon_on_ground(f):
				mode = X.WANDER
				_pick_target()
			else:
				target = f.global_position
				var d := _flat_dist(target)
				if d < 25.0 and not warned:
					warned = true
					m.fox_warn(self)
				if d < 8.0:
					mode = X.POUNCE
		X.POUNCE:
			spd = 9.5
			if not _falcon_on_ground(f):
				mode = X.WANDER
				_pick_target()
			else:
				target = f.global_position
				if _flat_dist(target) < 1.6:
					m.fox_pounce(self)
					if mode == X.POUNCE:   # 먹이를 물었으면 take()가 CARRY로 바꿔 둔다
						mode = X.WANDER
						_pick_target()
	_move(delta, spd)
	_animate(delta, spd)


func _look_around(m, f: Falcon) -> void:
	# 떨어진 먹이 냄새
	for p in m.prey_mgr.prey:
		if is_instance_valid(p) and p.state == Prey.S.GROUND and not p.claimed and _flat_dist(p.global_position) < 170.0:
			p.claimed = true
			prey = p
			mode = X.TO_PREY
			return
	# 땅에서 먹고 있는 매
	if _falcon_on_ground(f) and f.carrying and not m.prologue.active and _flat_dist(f.global_position) < 130.0:
		mode = X.STALK
		warned = false


func _falcon_on_ground(f: Falcon) -> bool:
	if f.state != Falcon.State.PERCHED:
		return false
	var k: String = f.perch.get("kind", "")
	if k != "ground" and k != "rock":
		return false
	var p := f.global_position
	return p.y - WorldShape.ground(p.x, p.z) < 2.5 and WorldShape.island_near(p, 100.0) == null


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _move(delta: float, spd: float) -> void:
	var to := target - global_position
	to.y = 0.0
	var want := Vector3.ZERO
	if spd > 0.0 and to.length() > 0.3:
		want = to.normalized() * spd
	vel = vel.lerp(want, 1.0 - exp(-4.0 * delta))
	var np := global_position + vel * delta
	var g := WorldShape.ground(np.x, np.z)
	if g < 1.2:
		# 물가에서는 돌아선다
		vel = -vel * 0.5
		_pick_target()
		return
	np.y = g
	global_position = np
	if vel.length() > 0.3:
		var n := WorldShape.normal(np.x, np.z)
		var fwd := Vector3(vel.x, 0, vel.z).normalized()
		fwd = (fwd - n * fwd.dot(n)).normalized()
		global_basis = global_basis.slerp(Basis.looking_at(fwd, n), 1.0 - exp(-8.0 * delta)).orthonormalized()


func _animate(delta: float, spd: float) -> void:
	var moving := vel.length()
	_gait += delta * (2.0 + moving * 2.2)
	var amp := clampf(moving / 6.0, 0.0, 1.0) * 0.7
	for i in legs.size():
		var ph := _gait + (PI if i == 1 or i == 2 else 0.0)
		(legs[i] as Node3D).rotation.x = sin(ph) * amp
	tail.rotation.y = sin(_gait * 0.7) * 0.25
	var crouch := 1.0 if mode == X.STALK else 0.0
	model.position.y = lerpf(model.position.y, -0.12 * crouch, 1.0 - exp(-4.0 * delta))
	head.rotation.x = lerpf(head.rotation.x, 0.25 * crouch + (0.35 if mode == X.REST and spd == 0.0 else 0.0), 1.0 - exp(-3.0 * delta))


## 입에 문 먹이 위치
func talon_point() -> Vector3:
	return global_transform * Vector3(0, 0.45 * CritterModel.VISUAL, -0.62 * CritterModel.VISUAL)


func take(p: Prey) -> void:
	prey = p
	p.take(self)
	mode = X.CARRY
	_timer = 14.0
	target = _land_point(global_position, 150.0)
