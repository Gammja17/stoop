class_name RivalFalcon
extends AIFalcon
## 영역 침입자 매. 플레이어 위를 맴돌다가 경고 울음 뒤 급강하로 들이받는다. 세 번 맞히면 떠난다.

signal hit_player
signal defeated

enum R { CIRCLE, WARN, STOOP, RECOVER, LEAVE }

var mode := R.CIRCLE
var angle := 0.0
var timer := 6.0
var hits := 0
var need_hits := 3
var _stoop_dir := Vector3.DOWN
var _hurt := 0.0


func setup(pos: Vector3, p_need: int) -> RivalFalcon:
	position = pos
	need_hits = p_need
	init_model("rival")
	return self


func _process(delta: float) -> void:
	var f := player()
	if f == null:
		return
	timer -= delta
	_hurt -= delta
	match mode:
		R.CIRCLE:
			tuck = 0.0
			angle += delta * 0.7
			var c := f.global_position + Vector3(0, 55.0, 0)
			var tgt := c + Vector3(cos(angle) * 45.0, 0, sin(angle) * 45.0)
			steer((tgt - global_position).normalized() * 24.0, delta, 1.8)
			if timer <= 0.0 and f.state == Falcon.State.FLYING and global_position.y > f.global_position.y + 25.0:
				mode = R.WARN
				timer = 1.1
				Sfx.play_at("screech", global_position, 6.0, 1.0, 800.0)
				GameState.say(Loc.t("rival_attack"), "warn")
		R.WARN:
			tuck = 0.5
			steer(vel.lerp(Vector3.UP * 5.0, 0.1), delta, 1.0)
			if timer <= 0.0:
				mode = R.STOOP
				timer = 3.0
				_stoop_dir = ((f.global_position + f.velocity * 0.8) - global_position).normalized()
		R.STOOP:
			tuck = 1.0
			var aim := ((f.global_position + f.velocity * 0.3) - global_position).normalized()
			_stoop_dir = _stoop_dir.slerp(aim, 1.0 - exp(-1.3 * delta)).normalized()
			steer(_stoop_dir * 62.0, delta, 3.0)
			if global_position.distance_to(f.global_position) < 2.3 and f.state == Falcon.State.FLYING:
				hit_player.emit()
				mode = R.RECOVER
				timer = 4.0
			elif timer <= 0.0 or global_position.y < f.global_position.y - 30.0 or global_position.y < WorldShape.floor_y(global_position.x, global_position.z) + 15.0:
				mode = R.RECOVER
				timer = 4.0
		R.RECOVER:
			tuck = 0.0
			steer((vel.normalized() + Vector3.UP * 1.2).normalized() * 18.0, delta, 1.5)
			if timer <= 0.0:
				mode = R.CIRCLE
				timer = randf_range(6.0, 10.0)
		R.LEAVE:
			tuck = 0.2
			steer(Vector3(-1, 0.4, 0.3).normalized() * 26.0, delta, 1.0)
			if timer <= 0.0:
				queue_free()
	animate(delta)


## 플레이어에게 맞았다
func take_hit(from_vel: Vector3) -> void:
	if _hurt > 0.0 or mode == R.LEAVE:
		return
	_hurt = 1.0
	hits += 1
	vel = from_vel * 0.4 + Vector3.UP * 4.0
	if hits >= need_hits:
		mode = R.LEAVE
		timer = 12.0
		defeated.emit()
	else:
		mode = R.RECOVER
		timer = 3.5
