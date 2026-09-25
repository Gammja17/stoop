class_name MateBird
extends AIFalcon
## 짝(또는 짝 후보). 구애 중엔 절벽 위를 맴돌며 플레이어의 비행을 지켜보고, 짝이 된 뒤엔 둥지를 지킨다.

enum M { COURT, FOLLOW, NEST, HUNT, CATCH, DEFEND, DRIVE }

var mode := M.COURT
var angle := 0.0
var follow_t := 0.0
var hunt_t := 0.0
var catch_prey: Prey = null
var eat_t := 0.0
var _call_t := 0.0
var drive_flock: Flock = null
var drive_t := 0.0
var back_t := 0.0        # 협동 사냥 뒤 둥지로 돌아가기까지


func setup(spec: String, pos: Vector3) -> MateBird:
	position = pos
	init_model(spec)
	angle = randf() * TAU
	return self


func nest_spot() -> Vector3:
	var side := WorldShape.eyrie_facing.cross(Vector3.UP).normalized()
	return WorldShape.eyrie + side * 1.3 + Vector3(0, 0.05, 0)


func go_nest() -> void:
	mode = M.NEST
	perch_at(nest_spot(), WorldShape.eyrie_facing)


func start_catch(p: Prey) -> void:
	catch_prey = p
	mode = M.CATCH
	perched = false


func _process(delta: float) -> void:
	var f := player()
	_call_t -= delta
	match mode:
		M.COURT:
			angle += delta * 0.35
			var c := WorldShape.eyrie + Vector3(60, 60, 0)
			if f and follow_t > 0.0:
				follow_t -= delta
				c = f.global_position + Vector3(0, 12, 0)
			steer((circle_point(c, 55.0, 20.0, angle) - global_position).normalized() * 17.0, delta, 1.5)
		M.FOLLOW:
			back_t -= delta
			if back_t < 0.0 and back_t > -1.0 and GameState.life().mate.get("has", false):
				go_nest()
			if f:
				angle += delta * 0.6
				var tgt := f.global_position + Vector3(cos(angle) * 25.0, 8.0, sin(angle) * 25.0)
				var d := tgt - global_position
				steer(d.normalized() * clampf(d.length() * 0.8, 10.0, maxf(f.speed + 6.0, 20.0)), delta, 2.0)
				if f.state == Falcon.State.PERCHED and f.perch.get("kind", "") == "eyrie":
					go_nest()
		M.NEST:
			if not perched:
				update_landing(delta)
			else:
				# 알을 품는 동안이 아니면 낮에 가끔 사냥 비행을 나간다
				hunt_t -= delta
				var l := GameState.life()
				var h := float(GameState.data.get("time", 12.0))
				if hunt_t <= -randf_range(50.0, 90.0) and int(l.get("eggs", 0)) == 0 and h > 7.0 and h < 18.0:
					mode = M.HUNT
					hunt_t = randf_range(30.0, 50.0)
					perched = false
					vel = WorldShape.eyrie_facing * 10.0 + Vector3.UP * 4.0
		M.HUNT:
			hunt_t -= delta
			angle += delta * 0.25
			steer((circle_point(WorldShape.cliffs_center + Vector3(200, 0, 0), 260.0, 70.0, angle) - global_position).normalized() * 20.0, delta, 1.2)
			if hunt_t <= 0.0:
				go_nest()
		M.CATCH:
			if catch_prey == null or not is_instance_valid(catch_prey) or catch_prey.state != Prey.S.STUNNED:
				catch_prey = null
				mode = M.FOLLOW if not GameState.life().mate.get("has", false) else M.NEST
				if mode == M.NEST:
					go_nest()
			else:
				var tp := catch_prey.global_position + catch_prey.vel * 0.2
				var d2 := tp - global_position
				steer(d2.normalized() * 30.0, delta, 4.0)
				if d2.length() < 2.2:
					take_prey(catch_prey)
					catch_prey = null
					eat_t = 4.0
					var ld = get_tree().get_first_node_in_group("life")
					if ld:
						ld.mate_caught(carrying)
		M.DEFEND:
			pass
		M.DRIVE:
			drive_t -= delta
			if drive_flock == null or not is_instance_valid(drive_flock) or drive_flock.members.is_empty() or drive_t <= 0.0:
				_end_drive()
			else:
				# 새떼 밑으로 파고들어 위로 몰아 올린다
				var c := drive_flock.centroid
				var tgt := c + Vector3(0, -8, 0)
				steer((tgt - global_position).normalized() * 30.0, delta, 2.5)
				if global_position.distance_to(c) < 16.0:
					for m in drive_flock.members:
						if is_instance_valid(m):
							m.alarm()
							m.flushed_t = 8.0
							m.vel += Vector3.UP * 12.0
					drive_flock.target = c + Vector3(0, 70, 0)
					Sfx.play_at("call", global_position, 4.0, 1.2, 700.0)
					GameState.say(Loc.t("coop_flushed"), "gold")
					_end_drive()
	if carrying:
		eat_t -= delta
		if eat_t <= 0.0:
			carrying.vanish()
			carrying = null
			if mode == M.CATCH:
				mode = M.FOLLOW
	animate(delta)


func start_drive(fl: Flock) -> void:
	drive_flock = fl
	mode = M.DRIVE
	drive_t = 40.0
	perched = false
	_land_t = -1.0


func _end_drive() -> void:
	drive_flock = null
	mode = M.FOLLOW
	back_t = 25.0


func call_back() -> void:
	if _call_t > 0.0:
		return
	_call_t = 4.0
	get_tree().create_timer(0.7).timeout.connect(func(): Sfx.play_at("call", global_position, 0.0, 1.15, 600.0))
