class_name OwlRaider
extends AIFalcon
## 수리부엉이. 밤에 내륙에서 둥지로 날아와 새끼를 노린다. 두 번 맞히면 달아난다.

signal reached_nest
signal driven_off

enum O { APPROACH, HURT, FLEE, AT_NEST }

var mode := O.APPROACH
var hits := 0
var timer := 0.0
var _hoot_t := 2.0


func setup(pos: Vector3) -> OwlRaider:
	position = pos
	init_model("owl")
	return self


func _process(delta: float) -> void:
	timer -= delta
	_hoot_t -= delta
	if _hoot_t <= 0.0 and mode == O.APPROACH:
		_hoot_t = randf_range(4.0, 7.0)
		Sfx.play_at("hoot", global_position, 4.0, randf_range(0.95, 1.05), 700.0)
	match mode:
		O.APPROACH:
			var tgt := WorldShape.eyrie + Vector3(0, 2.0, 0)
			var d := tgt - global_position
			if d.length() > 60.0:
				tgt.y += 25.0
			steer(d.normalized() * 11.0, delta, 1.2)
			if global_position.distance_to(WorldShape.eyrie) < 3.5:
				mode = O.AT_NEST
				timer = 3.0
				reached_nest.emit()
		O.HURT:
			steer((vel.normalized() * -0.2 + Vector3.UP).normalized() * 8.0, delta, 2.0)
			if timer <= 0.0:
				mode = O.APPROACH
		O.AT_NEST:
			steer(Vector3.ZERO, delta, 4.0)
			if timer <= 0.0:
				mode = O.FLEE
				timer = 15.0
		O.FLEE:
			steer(Vector3(-1, 0.3, 0).normalized() * 14.0, delta, 1.0)
			if timer <= 0.0:
				queue_free()
	animate(delta)


func take_hit(from_vel: Vector3) -> void:
	if mode == O.HURT or mode == O.FLEE:
		return
	hits += 1
	vel = from_vel * 0.35 + Vector3.UP * 3.0
	Sfx.play_at("hoot", global_position, 6.0, 1.3, 700.0)
	if hits >= 2:
		mode = O.FLEE
		timer = 15.0
		driven_off.emit()
	else:
		mode = O.HURT
		timer = 3.0
