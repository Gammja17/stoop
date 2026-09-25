class_name Flock
extends Node3D
## 새떼. 분리·정렬·응집(보이드) + 목표 배회. 한 마리가 놀라면 전부 흩어지며 소용돌이친다.
## 떼가 빽빽하면 조준이 흔들린다(혼란 효과) — HUD가 confusion()을 읽는다.

var kind := "starling"
var members: Array = []
var home := Vector3.ZERO
var home_r := 300.0
var target := Vector3.ZERO
var alarmed_t := 0.0
var swirl := 0.0
var centroid := Vector3.ZERO
var cruise := 15.0
var alt_lo := 10.0
var alt_hi := 50.0


func setup(p_kind: String, p_home: Vector3, p_r: float) -> Flock:
	kind = p_kind
	home = p_home
	home_r = p_r
	var t: Dictionary = Prey.TYPES[kind]
	cruise = t.cruise
	alt_lo = t.alt[0]
	alt_hi = t.alt[1]
	_new_target()
	return self


func add(p: Prey) -> void:
	members.append(p)
	p.flock = self


func remove(p: Prey) -> void:
	members.erase(p)


func alarm() -> void:
	if alarmed_t <= 0.0:
		swirl = 1.0 if randf() < 0.5 else -1.0
	alarmed_t = 5.0
	for m in members:
		if is_instance_valid(m) and m.state == Prey.S.FLY:
			m.state = Prey.S.FLEE
			m.calm_t = 0.0


func _new_target() -> void:
	var a := randf() * TAU
	var r := sqrt(randf()) * home_r
	target = home + Vector3(cos(a) * r, 0, sin(a) * r)
	target.y = WorldShape.floor_y(target.x, target.z) + randf_range(alt_lo, alt_hi)


func confusion() -> float:
	var n := 0
	for m in members:
		if is_instance_valid(m) and (m.global_position - centroid).length() < 10.0:
			n += 1
	return clampf(float(n - 6) / 14.0, 0.0, 1.0)


var _lod_n := randi() % 4
var _lod_acc := 0.0


func _process(delta: float) -> void:
	# 먼 떼는 가끔만 계산한다
	var d2 := centroid.distance_squared_to(Prey.focus)
	if alarmed_t <= 0.0 and d2 > Prey.LOD_NEAR * Prey.LOD_NEAR:
		_lod_acc += delta
		_lod_n += 1
		if _lod_n % (8 if d2 > Prey.LOD_DIST * Prey.LOD_DIST else 3) != 0:
			return
		delta = _lod_acc
	_lod_acc = 0.0
	var alive := []
	for m in members:
		if is_instance_valid(m) and (m.state == Prey.S.FLY or m.state == Prey.S.FLEE):
			alive.append(m)
	if alive.is_empty():
		if members.is_empty():
			queue_free()
		return
	alarmed_t -= delta
	var c := Vector3.ZERO
	var av := Vector3.ZERO
	for m in alive:
		c += m.global_position
		av += m.vel
	c /= alive.size()
	av /= alive.size()
	centroid = c
	if c.distance_to(target) < 40.0:
		_new_target()
	var to_t := (target - c).normalized()
	var n := alive.size()
	for i in n:
		var m: Prey = alive[i]
		var p: Vector3 = m.global_position
		var sep := Vector3.ZERO
		for j in n:
			if i == j:
				continue
			var d: Vector3 = p - alive[j].global_position
			var l2 := d.length_squared()
			if l2 < 9.0 and l2 > 0.0001:
				sep += d / l2
		var coh := (c - p)
		var desired := av * 0.55 + to_t * cruise * 0.45 + coh * 0.35 + sep * 6.0
		if alarmed_t > 0.0:
			# 소용돌이 + 흩어짐
			var tang := Vector3.UP.cross(coh).normalized() * swirl
			desired += tang * 8.0 - coh * 0.2 + Vector3(0, sin(Time.get_ticks_msec() * 0.003 + i) * 4.0, 0)
		m.boid = desired.normalized() * cruise * (1.25 if alarmed_t > 0.0 else 1.0) if desired.length() > 0.01 else m.vel
