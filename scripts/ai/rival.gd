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
var _alt := 0.0        # 맴도는 높이: 매를 천천히만 따라 올라온다 (상승기류로 위를 잡을 수 있게)
var hinted := false


func setup(pos: Vector3, p_need: int) -> RivalFalcon:
	position = pos
	need_hits = p_need
	_alt = pos.y
	timer = 10.0
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
			angle += delta * 0.6
			_alt = move_toward(_alt, f.global_position.y + 40.0, 2.5 * delta)
			var c := Vector3(f.global_position.x, _alt, f.global_position.z)
			var tgt := c + Vector3(cos(angle) * 60.0, 0, sin(angle) * 60.0)
			steer((tgt - global_position).normalized() * 20.0, delta, 1.8)
			if timer <= 0.0 and f.state == Falcon.State.FLYING and global_position.y > f.global_position.y + 25.0:
				mode = R.WARN
				timer = 1.8
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
			_stoop_dir = _stoop_dir.slerp(aim, 1.0 - exp(-0.5 * delta)).normalized()
			steer(_stoop_dir * 55.0, delta, 3.0)
			if global_position.distance_to(f.global_position) < 1.8 and f.state == Falcon.State.FLYING:
				hit_player.emit()
				_recover()
			elif timer <= 0.0 or global_position.y < f.global_position.y - 30.0 or global_position.y < WorldShape.floor_y(global_position.x, global_position.z) + 15.0:
				_recover()
		R.RECOVER:
			# 급강하 뒤엔 느리게 수평으로 날며 숨을 고른다 → 반격 기회
			tuck = 0.0
			var flat := Vector3(vel.x, 0.0, vel.z)
			if flat.length() < 1.0:
				flat = Vector3.RIGHT
			steer((flat.normalized() + Vector3.UP * 0.15).normalized() * 12.0, delta, 1.5)
			if timer <= 0.0:
				mode = R.CIRCLE
				_alt = global_position.y
				timer = randf_range(12.0, 18.0)
		R.LEAVE:
			tuck = 0.2
			steer(Vector3(-1, 0.4, 0.3).normalized() * 26.0, delta, 1.0)
			if timer <= 0.0:
				queue_free()
	animate(delta)


func _recover() -> void:
	mode = R.RECOVER
	timer = 6.0


func vulnerable() -> bool:
	return mode == R.RECOVER


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
		_recover()
		_alt = global_position.y
