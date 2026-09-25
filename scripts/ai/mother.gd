class_name MotherBird
extends AIFalcon
## 프롤로그의 어미 매. 둥지에 앉아 있다가 앞장서 날고, 상승기류 안을 돌고, 먹이를 떨어뜨려 주고, 마지막엔 떠난다.

enum M { PERCH, LEAD, CIRCLE, ESCORT, DROP, LEAVE }

var mode := M.PERCH
var goal := Vector3.ZERO          # LEAD 목적지
var center := Vector3.ZERO        # CIRCLE 중심(지면 기준)
var circle_alt := 60.0
var angle := 0.0
var _wait_player := true
var _leave_t := 0.0


func setup(pos: Vector3) -> MotherBird:
	position = pos
	init_model("falcon_f")
	return self


func nest_spot() -> Vector3:
	var side := WorldShape.eyrie_facing.cross(Vector3.UP).normalized()
	return WorldShape.eyrie + side * 1.4 + Vector3(0, 0.05, 0)


func sit_at_nest() -> void:
	mode = M.PERCH
	perched = true
	perch_pos = nest_spot()
	perch_facing = WorldShape.eyrie_facing
	global_position = perch_pos


func lead_to(p: Vector3) -> void:
	mode = M.LEAD
	goal = p
	perched = false


func circle_at(c: Vector3, alt: float) -> void:
	mode = M.CIRCLE
	center = c
	circle_alt = alt
	perched = false


func escort() -> void:
	mode = M.ESCORT
	perched = false


func hold_above_player() -> void:
	mode = M.DROP
	perched = false


func release_prey() -> Prey:
	var p := carrying
	carrying = null
	if p:
		p.released(vel * 0.3)
		p.catch_lock = 0.0
	return p


func leave() -> void:
	mode = M.LEAVE
	perched = false
	_leave_t = 14.0


func _process(delta: float) -> void:
	var f := player()
	match mode:
		M.PERCH:
			if not perched:
				update_landing(delta)
		M.LEAD:
			var d := goal - global_position
			var spd := 17.0
			# 플레이어가 뒤처지면 속도를 늦춘다
			if f and f.global_position.distance_to(global_position) > 60.0:
				spd = 9.0
			if d.length() < 25.0:
				circle_at(Vector3(goal.x, WorldShape.floor_y(goal.x, goal.z), goal.z), goal.y - WorldShape.floor_y(goal.x, goal.z))
			else:
				steer(d.normalized() * spd, delta, 1.6)
		M.CIRCLE:
			angle += delta * 0.45
			var alt := circle_alt
			# 상승기류 안에서는 플레이어보다 조금 위에서 돈다
			if f and f.state == Falcon.State.FLYING:
				alt = maxf(circle_alt, f.global_position.y - center.y + 12.0)
			var tgt := center + Vector3(cos(angle) * 32.0, alt, sin(angle) * 32.0)
			steer((tgt - global_position).normalized() * 15.0, delta, 1.6)
		M.ESCORT:
			if f:
				angle += delta * 0.5
				var tgt2 := f.global_position + Vector3(cos(angle) * 30.0, 14.0, sin(angle) * 30.0)
				var d2 := tgt2 - global_position
				steer(d2.normalized() * clampf(d2.length(), 8.0, maxf(f.speed + 8.0, 20.0)), delta, 1.8)
		M.DROP:
			if f:
				var ahead := Vector3(f.dir.x, 0, f.dir.z)
				if ahead.length() < 0.1:
					ahead = Vector3.RIGHT
				var tgt3 := f.global_position + ahead.normalized() * 22.0 + Vector3.UP * 22.0
				var d3 := tgt3 - global_position
				steer(d3.normalized() * clampf(d3.length() * 1.2, 6.0, 30.0), delta, 2.2)
		M.LEAVE:
			_leave_t -= delta
			steer(Vector3(-0.8, 0.35, 0.4).normalized() * 22.0, delta, 1.0)
			if _leave_t <= 0.0:
				queue_free()
	animate(delta)


func near_player() -> bool:
	var f := player()
	return f != null and f.global_position.distance_to(global_position) < 40.0
