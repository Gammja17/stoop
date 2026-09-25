class_name HunterFalcon
extends AIFalcon
## 먹이 쟁탈전의 다른 매: 새떼 위를 맴돌다가 급강하해 한 마리를 채 간다.

enum H { CIRCLE, STOOP, CARRY }

var mode := H.CIRCLE
var flock: Flock
var timer := 14.0
var target: Prey
var done := false
var _angle := 0.0


func setup(pos: Vector3, fl: Flock) -> HunterFalcon:
	position = pos
	flock = fl
	init_model("hunter")
	return self


func _process(delta: float) -> void:
	timer -= delta
	match mode:
		H.CIRCLE:
			tuck = 0.0
			_angle += delta * 0.6
			var c := global_position
			if is_instance_valid(flock) and not flock.members.is_empty():
				c = flock.centroid
			var tgt := c + Vector3(cos(_angle) * 60.0, 90.0, sin(_angle) * 60.0)
			steer((tgt - global_position).normalized() * 20.0, delta, 1.5)
			if timer <= 0.0 and is_instance_valid(flock) and not flock.members.is_empty():
				target = flock.members[randi() % flock.members.size()]
				mode = H.STOOP
				timer = 8.0
				Sfx.play_at("screech", global_position, 2.0, 1.15, 700.0)
		H.STOOP:
			tuck = 1.0
			if target == null or not is_instance_valid(target) or not (target.state == Prey.S.FLY or target.state == Prey.S.FLEE):
				mode = H.CIRCLE
				timer = 5.0
			else:
				var aim := (target.global_position + target.vel * 0.3 - global_position).normalized()
				steer(aim * 52.0, delta, 3.0)
				if global_position.distance_to(target.global_position) < 2.6:
					target.knock(vel * 0.2)
					take_prey(target)
					done = true
					mode = H.CARRY
					timer = 20.0
					Sfx.play_at("hit_med", global_position, 0.0, 0.9, 500.0)
				elif timer <= 0.0:
					mode = H.CIRCLE
					timer = 6.0
		H.CARRY:
			tuck = 0.0
			steer(Vector3(-1, 0.35, 0.2).normalized() * 18.0, delta, 1.0)
			if timer <= 0.0:
				if carrying and is_instance_valid(carrying):
					carrying.vanish()
				queue_free()
	animate(delta)
