class_name WhiteFalcon
extends AIFalcon
## 전설의 해동청. 높은 하늘에서 기다리다가, 다가오면 술래잡기를 한다.
## 가까이 오면 급가속·급강하로 피한다. 세 번 닿으면 인정한다.

enum W { WAIT, EVADE, LEAVE }

var mode := W.WAIT
var home := Vector3.ZERO
var tags := 0
var _angle := 0.0
var _wp := Vector3.ZERO
var _burst := 0.0
var _cool := 0.0
var _call_t := 0.0


func setup(p_home: Vector3) -> WhiteFalcon:
	home = p_home
	position = p_home + Vector3(60, 0, 0)
	init_model("pl_white")
	model.scale *= 1.2
	flap_rate = 8.0
	return self


func _process(delta: float) -> void:
	_burst -= delta
	_cool -= delta
	_call_t -= delta
	var f := player()
	if f == null:
		return
	match mode:
		W.WAIT:
			_angle += delta * 0.35
			var tp := home + Vector3(cos(_angle) * 70.0, sin(_angle * 2.0) * 8.0, sin(_angle) * 70.0)
			steer((tp - global_position).normalized() * 16.0, delta, 1.2)
		W.EVADE:
			var to_me := global_position - f.global_position
			var d := to_me.length()
			if global_position.distance_to(_wp) < 40.0 or _wp == Vector3.ZERO:
				_new_wp()
			var want := (_wp - global_position).normalized() * 24.0
			# 가까이 오면 옆·아래로 튀어 달아난다
			if d < 30.0 and _cool <= 0.0:
				_cool = 2.5
				_burst = 1.4
				var side := to_me.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
				vel += (side * 0.8 + to_me.normalized() * 0.6 + Vector3.DOWN * randf_range(0.0, 0.8)).normalized() * 26.0
				Sfx.play_at("call", global_position, 0.0, 1.4, 500.0)
			if _burst > 0.0:
				want = vel.normalized() * 44.0
			steer(want, delta, 1.8 if _burst <= 0.0 else 0.6)
			if _call_t <= 0.0:
				_call_t = randf_range(3.0, 6.0)
				Sfx.play_at("call", global_position, -2.0, 1.3, 600.0)
		W.LEAVE:
			steer(Vector3(0.3, 0.6, -1.0).normalized() * 30.0, delta, 0.8)
	animate(delta)


func _new_wp() -> void:
	var a := randf() * TAU
	_wp = home + Vector3(cos(a) * randf_range(120.0, 260.0), randf_range(-120.0, 40.0), sin(a) * randf_range(120.0, 260.0))
	_wp.y = maxf(_wp.y, WorldShape.floor_y(_wp.x, _wp.z) + 60.0)


## 매가 닿았다
func tagged() -> void:
	tags += 1
	_cool = 0.0
	_burst = 1.8
	vel = (global_position - player().global_position).normalized() * 30.0 + Vector3.UP * 8.0
	_new_wp()
