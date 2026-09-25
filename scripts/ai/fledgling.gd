class_name Fledgling
extends AIFalcon
## 둥지를 떠날 준비를 하는 어린 매. 둥지 주변을 날며, 떨어뜨려 준 먹이를 받아내는 연습을 한다.

signal lesson(success: bool)

enum F { PERCH, FLY, CATCH }

var data: Dictionary
var mode := F.PERCH
var angle := 0.0
var timer := 0.0
var catch_prey: Prey = null
var _chance := 0.5
var eat_t := 0.0
var index := 0


func setup(d: Dictionary, i: int) -> Fledgling:
	data = d
	index = i
	var side := WorldShape.eyrie_facing.cross(Vector3.UP).normalized()
	perch_pos = WorldShape.eyrie + side * (-1.0 - 0.8 * i) + Vector3(0, 0.05, 0.3 * i)
	perch_facing = WorldShape.eyrie_facing
	position = perch_pos
	perched = true
	init_model("juvenile")
	model.scale *= 0.92
	angle = randf() * TAU + i
	timer = randf_range(4.0, 12.0)
	return self


func start_catch(p: Prey, chance: float) -> void:
	catch_prey = p
	_chance = chance
	mode = F.CATCH
	perched = false


func _process(delta: float) -> void:
	timer -= delta
	match mode:
		F.PERCH:
			if not perched:
				update_landing(delta)
			elif timer <= 0.0:
				mode = F.FLY
				timer = randf_range(20.0, 40.0)
				vel = WorldShape.eyrie_facing * 8.0 + Vector3.UP * 3.0
		F.FLY:
			angle += delta * (0.35 + 0.05 * index)
			var p := player()
			var c := WorldShape.eyrie + WorldShape.eyrie_facing * 90.0
			if p and p.carrying and p.global_position.distance_to(WorldShape.eyrie) < 400.0:
				c = p.global_position - Vector3(0, 18.0, 0)
			var tgt := circle_point(c, 40.0 + 12.0 * index, 25.0 + 8.0 * index, angle)
			steer((tgt - global_position).normalized() * 17.0, delta, 1.4)
			if timer <= 0.0:
				mode = F.PERCH
				timer = randf_range(10.0, 25.0)
				perch_at(perch_pos, perch_facing)
		F.CATCH:
			if catch_prey == null or not is_instance_valid(catch_prey) or catch_prey.state != Prey.S.STUNNED:
				catch_prey = null
				mode = F.FLY
				timer = 15.0
			else:
				var tp := catch_prey.global_position + catch_prey.vel * 0.25
				var d := tp - global_position
				steer(d.normalized() * 26.0, delta, 3.0)
				if d.length() < 2.4:
					if randf() < _chance:
						take_prey(catch_prey)
						eat_t = 3.5
						lesson.emit(true)
					else:
						vel += Vector3(randf_range(-6, 6), 4.0, randf_range(-6, 6))
						lesson.emit(false)
					catch_prey = null
					mode = F.FLY
					timer = 12.0
	if carrying:
		eat_t -= delta
		if eat_t <= 0.0:
			carrying.vanish()
			carrying = null
	animate(delta)
