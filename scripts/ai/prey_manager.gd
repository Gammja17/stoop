class_name PreyManager
extends Node3D
## 서식지별 사냥감 생성/유지와 매-사냥감 충돌 판정.

signal contact(prey: Prey, how: String)
signal gull_hit(gull: Gull)

var main
var falcon: Falcon
var prey: Array = []
var flocks: Array = []
var gulls: Array = []
var village_pigeons: VillagePigeons
var habitats: Array = []
var _spawn_t := 0.0


func setup(p_main) -> void:
	main = p_main
	falcon = main.falcon
	process_priority = 5
	var cl := WorldShape.cliffs_center + Vector3(90, 0, 0)
	# groups: 계절별(봄,여름,가을,겨울) 유지할 무리 수
	habitats = [
		{"id": "cliffs", "kind": "pigeon", "center": cl, "r": 480.0, "size": [3, 5], "groups": [3, 3, 3, 2], "flock": true},
		{"id": "village", "kind": "pigeon", "center": WorldShape.village + Vector3(40, 0, 0), "r": 260.0, "size": [4, 7], "groups": [2, 2, 2, 3], "flock": true},
		{"id": "fields", "kind": "starling", "center": WorldShape.fields, "r": 480.0, "size": [14, 26], "groups": [2, 2, 3, 1], "flock": true},
		{"id": "bay", "kind": "sandpiper", "center": WorldShape.bay, "r": 360.0, "size": [16, 30], "groups": [3, 1, 3, 0], "flock": true},
		{"id": "bay_ducks", "kind": "duck", "center": WorldShape.bay + Vector3(150, 0, -120), "r": 420.0, "size": [3, 6], "groups": [1, 0, 2, 3], "flock": true},
		{"id": "sea_ducks", "kind": "duck", "center": Vector3(WorldShape.coast_x(-500) + 450.0, 0, -300), "r": 500.0, "size": [3, 5], "groups": [0, 0, 1, 2], "flock": true},
	]
	for i in 7:
		var c := Vector3(WorldShape.coast_x(-1000.0 + i * 330.0) + randf_range(40, 200), 0, -1000.0 + i * 330.0)
		var g: Gull = Gull.new().setup(c)
		add_child(g)
		gulls.append(g)
	village_pigeons = VillagePigeons.new()
	add_child(village_pigeons)
	var plaza := WorldShape.village + Vector3(-15, 0, 12)
	plaza.y = WorldShape.ground(plaza.x, plaza.z)
	village_pigeons.setup(plaza)
	_maintain(true)


func _process(delta: float) -> void:
	if main == null:
		return
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 2.5
		_cleanup()
		_maintain(false)
	_check_hits()


func _cleanup() -> void:
	var alive := []
	for p in prey:
		if is_instance_valid(p) and p.state != Prey.S.GONE:
			alive.append(p)
	prey = alive
	var fl := []
	for f in flocks:
		if is_instance_valid(f):
			fl.append(f)
	flocks = fl


func _maintain(initial: bool) -> void:
	var season := int(GameState.data.get("season", 0))
	var night: bool = main.day_night.is_night()
	for h in habitats:
		var want: int = h.groups[season]
		if night:
			want = int(ceil(want * 0.3))
		var have := 0
		for f in flocks:
			if f.get_meta("habitat", "") == h.id and f.members.size() >= 2:
				have += 1
		if have < want:
			var n := randi_range(h.size[0], h.size[1])
			var spot := _spawn_spot(h.center, h.r, not initial)
			spawn_group(h.kind, spot, h.center, h.r, n, h.id)
	# 너무 먼 곳의 여분 새 정리
	if prey.size() > 180:
		for p in prey:
			if p.state == Prey.S.FLY and p.global_position.distance_to(falcon.global_position) > 900.0:
				p.vanish()
				break


func _spawn_spot(center: Vector3, r: float, far_from_player: bool) -> Vector3:
	var best := center
	for i in 12:
		var a := randf() * TAU
		var rr := sqrt(randf()) * r
		var p := center + Vector3(cos(a) * rr, 0, sin(a) * rr)
		if not far_from_player or p.distance_to(falcon.global_position) > 320.0:
			return p
		best = p
	return best


func spawn_group(kind: String, spot: Vector3, center: Vector3, r: float, n: int, habitat_id: String) -> Flock:
	var fl: Flock = Flock.new().setup(kind, center, r)
	fl.set_meta("habitat", habitat_id)
	add_child(fl)
	flocks.append(fl)
	var alt: Array = Prey.TYPES[kind].alt
	var base_y := WorldShape.floor_y(spot.x, spot.z) + randf_range(alt[0], alt[1])
	for i in n:
		var pos := Vector3(spot.x + randf_range(-6, 6), base_y + randf_range(-3, 3), spot.z + randf_range(-6, 6))
		pos.y = maxf(pos.y, WorldShape.floor_y(pos.x, pos.z) + 3.0)
		var p: Prey = Prey.new().setup(kind, pos, center, r)
		add_child(p)
		prey.append(p)
		fl.add(p)
	return fl


func spawn_from_ground(positions: Array, center: Vector3) -> void:
	var fl: Flock = Flock.new().setup("pigeon", center, 220.0)
	fl.set_meta("habitat", "plaza")
	add_child(fl)
	flocks.append(fl)
	for pos in positions:
		var p: Prey = Prey.new().setup("pigeon", (pos as Vector3) + Vector3.UP * 0.3, center, 220.0)
		p.vel = Vector3(randf_range(-4, 4), 9.0, randf_range(-4, 4))
		add_child(p)
		prey.append(p)
		fl.add(p)
	fl.alarm()


static func seg_dist(a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.000001:
		return a.length()
	var t := clampf(-a.dot(ab) / l2, 0.0, 1.0)
	return (a + ab * t).length()


func _check_hits() -> void:
	if falcon == null or falcon.state != Falcon.State.FLYING:
		return
	var a := falcon._prev_pos
	var b := falcon.global_position
	var sp := falcon.speed
	for p in prey:
		if not is_instance_valid(p):
			continue
		var st: int = p.state
		if st == Prey.S.CARRIED or st == Prey.S.GONE or st == Prey.S.SWIM:
			continue
		var pp: Vector3 = p.global_position
		if pp.distance_squared_to(b) > 2500.0:
			continue
		var d := seg_dist(a - p.prev, b - pp)
		var how := ""
		if st == Prey.S.FLY or st == Prey.S.FLEE:
			var r := 1.8 + sp * 0.012 + (0.4 if p.kind == "duck" else 0.0)
			if d < r:
				how = "air"
		elif st == Prey.S.STUNNED:
			if d < 3.0 and falcon.carrying == null and p.catch_lock <= 0.0:
				how = "catch"
		elif st == Prey.S.GROUND or st == Prey.S.WATER:
			if d < 2.4 and falcon.carrying == null and sp < 26.0:
				how = "pickup"
		if how != "":
			contact.emit(p, how)
			return
	for g in gulls:
		if not is_instance_valid(g) or g.state == Gull.G.FLEE:
			continue
		var gp: Vector3 = g.global_position
		if gp.distance_squared_to(b) > 2500.0:
			continue
		if seg_dist(a - g.prev, b - gp) < 2.0 and sp > 18.0:
			gull_hit.emit(g)
			return


## 조준 보조: 화면 중앙 방향 원뿔 안의 가장 좋은 목표
func best_target(origin: Vector3, look: Vector3, max_dist: float, cone_deg: float) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	var cos_lim := cos(deg_to_rad(cone_deg))
	for p in prey:
		if not is_instance_valid(p):
			continue
		if not (p.state == Prey.S.FLY or p.state == Prey.S.FLEE or p.state == Prey.S.STUNNED):
			continue
		var to: Vector3 = p.global_position - origin
		var d := to.length()
		if d > max_dist or d < 1.0:
			continue
		var c := to.normalized().dot(look)
		if c < cos_lim:
			continue
		var score := (1.0 - c) * 900.0 + d * 0.15
		if score < best_score:
			best_score = score
			best = p
	return best
