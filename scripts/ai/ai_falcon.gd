class_name AIFalcon
extends Node3D
## 짝·침입자·새끼·수리부엉이가 공유하는 비행 몸체. 목표 방향으로 조향하고 날갯짓/접기 애니메이션을 한다.

var model: BirdModel
var vel := Vector3.ZERO
var perched := false
var perch_pos := Vector3.ZERO
var perch_facing := Vector3.RIGHT
var tuck := 0.0
var carrying: Prey = null
var prev := Vector3.ZERO
var _flap_t := 0.0
var _glide := 0.0
var _land_t := -1.0
var _land_from := Vector3.ZERO


func init_model(spec: String) -> void:
	model = BirdModel.new()
	add_child(model)
	model.setup(spec)
	prev = position


func main_node():
	return get_tree().get_first_node_in_group("main")


func player() -> Falcon:
	var m = main_node()
	return m.falcon if m else null


func steer(desired: Vector3, delta: float, rate: float = 2.0) -> void:
	perched = false
	vel = vel.lerp(desired, 1.0 - exp(-rate * delta))
	var p := global_position + vel * delta
	var fy := WorldShape.floor_y(p.x, p.z)
	if p.y < fy + 3.0:
		p.y = lerpf(p.y, fy + 3.0, 0.3)
		vel.y = maxf(vel.y, 2.0)
	if WorldShape.hits_obstacle(p, 2.0):
		vel += Vector3.UP * 20.0 * delta
		p.y += 10.0 * delta
	global_position = p


func circle_point(center: Vector3, radius: float, alt: float, angle: float) -> Vector3:
	var p := center + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
	p.y = maxf(WorldShape.floor_y(p.x, p.z), center.y) + alt
	return p


func perch_at(pos: Vector3, facing: Vector3) -> void:
	perch_pos = pos
	perch_facing = facing
	_land_from = global_position
	_land_t = 0.0


func update_landing(delta: float) -> bool:
	if _land_t < 0.0:
		return perched
	_land_t += delta / 1.2
	var t := smoothstep(0.0, 1.0, minf(_land_t, 1.0))
	global_position = _land_from.lerp(perch_pos, t) + Vector3.UP * sin(t * PI) * 2.0
	vel = (perch_pos - _land_from) * 0.5 * (1.0 - t)
	if _land_t >= 1.0:
		_land_t = -1.0
		perched = true
		vel = Vector3.ZERO
		global_position = perch_pos
	return perched


func is_landing() -> bool:
	return _land_t >= 0.0


func take_prey(p: Prey) -> void:
	carrying = p
	p.take(self)


func talon_point() -> Vector3:
	return global_transform * Vector3(0, -0.22 * BirdModel.VISUAL, 0.02)


func animate(delta: float) -> void:
	if model == null:
		return
	prev = global_position
	var m := model
	if perched:
		m.perched = move_toward(m.perched, 1.0, delta * 3.0)
		m.fold = move_toward(m.fold, 1.0, delta * 3.0)
		m.flap_amp = move_toward(m.flap_amp, 0.0, delta * 3.0)
		var f := Vector3(perch_facing.x, 0, perch_facing.z)
		if f.length() > 0.1:
			global_basis = global_basis.slerp(Basis.looking_at(f.normalized(), Vector3.UP), 1.0 - exp(-5.0 * delta)).orthonormalized()
	else:
		m.perched = move_toward(m.perched, 0.0, delta * 4.0)
		m.fold = lerpf(m.fold, tuck, 1.0 - exp(-10.0 * delta))
		var climbing := vel.y > 1.0 or vel.length() < 12.0 or is_landing()
		_glide -= delta
		if _glide < -2.0:
			_glide = randf_range(1.0, 3.0)
		var flap := climbing or _glide < 0.0
		_flap_t += delta * (11.0 if flap else 1.5)
		m.flap_phase = _flap_t
		m.flap_amp = lerpf(m.flap_amp, (0.7 if flap else 0.05) * (1.0 - tuck), 1.0 - exp(-6.0 * delta))
		m.talons_out = 1.0 if carrying or is_landing() else 0.0
		if vel.length() > 0.5:
			var fwd := vel.normalized()
			if absf(fwd.y) < 0.98:
				var target := Basis.looking_at(fwd, Vector3.UP)
				global_basis = global_basis.slerp(target, 1.0 - exp(-7.0 * delta)).orthonormalized()
	m.pose(delta)
