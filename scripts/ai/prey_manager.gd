class_name PreyManager
extends Node3D
## 서식지별 사냥감 생성/유지와 매-사냥감 충돌 판정.

signal contact(prey: Prey, how: String)
signal gull_hit(gull: Gull)
signal mobber_hit(m: Mobber)
signal eagle_hit(e: SeaEagle)

var main
var falcon: Falcon
var prey: Array = []
var flocks: Array = []
var gulls: Array = []
var village_pigeons: VillagePigeons
var habitats: Array = []
var mobbers: Array = []       # 까마귀·번식지 갈매기
var colony_gulls: Array = []
var crows: Array = []
var eagle: SeaEagle
var foxes: Array = []
var sea_life: SeaLife
var bats_out := 0.0           # 박쥐가 동굴에서 나오는 중이면 남은 시간
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
	# 먼 섬들
	var sb := WorldShape.island_by_id("seabird")
	var se := WorldShape.island_by_id("seals")
	# near: 매가 이 거리 안에 있을 때만 새를 채운다 (멀면 정리해서 프레임을 아낀다)
	habitats.append({"id": "murrelets", "kind": "murrelet", "center": sb.to_world(sb.rb + 200.0, 0.0), "r": 330.0, "size": [4, 7], "groups": [3, 3, 1, 1], "flock": true, "near": 1400.0})
	habitats.append({"id": "rock_doves", "kind": "pigeon", "center": sb.center, "r": 260.0, "size": [3, 5], "groups": [1, 1, 1, 1], "flock": true, "near": 1400.0})
	habitats.append({"id": "sands", "kind": "sandpiper", "center": se.center, "r": 360.0, "size": [14, 24], "groups": [1, 0, 3, 1], "flock": true, "near": 1400.0})
	_spawn_island_life()
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
	Prey.focus = falcon.global_position
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 2.5
		_cleanup()
		_maintain(false)
		_update_seasonal()
	if bats_out > 0.0:
		bats_out -= delta
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
		if h.has("near"):
			var hd := Vector2(falcon.global_position.x - h.center.x, falcon.global_position.z - h.center.z).length()
			if hd > h.near:
				want = 0
				if hd > h.near + 300.0:
					_clear_habitat(h.id)
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


## 멀어진 서식지의 새떼를 치운다 (날고 있는 새만)
func _clear_habitat(id: String) -> void:
	for f in flocks:
		if is_instance_valid(f) and f.get_meta("habitat", "") == id:
			for m in f.members.duplicate():
				if is_instance_valid(m) and m.state == Prey.S.FLY:
					m.vanish()


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


# ---------- 섬과 본섬의 새 동물 ----------

func _spawn_island_life() -> void:
	# 까마귀 떼: 숲 가장자리와 마을 뒤
	for c: Vector3 in [WorldShape.fields + Vector3(-80, 0, -260), WorldShape.village + Vector3(-260, 0, -60)]:
		var grp := []
		for i in 5:
			var m: Mobber = Mobber.new().setup("crow", c, randf_range(50.0, 90.0), randf_range(18.0, 30.0), grp)
			add_child(m)
			mobbers.append(m)
			crows.append(m)
	# 바닷새섬 번식지의 갈매기
	var sb := WorldShape.island_by_id("seabird")
	var cgrp := []
	for i in 10:
		var col: Vector3 = sb.info.colony
		var g: Mobber = Mobber.new().setup("gull", Vector3(col.x, 0, col.z), randf_range(60.0, 140.0), randf_range(25.0, 60.0), cgrp)
		g.trigger_r = 170.0
		add_child(g)
		mobbers.append(g)
		colony_gulls.append(g)
	# 흰꼬리수리
	var se := WorldShape.island_by_id("seals")
	eagle = SeaEagle.new().setup(se.info.knoll)
	add_child(eagle)
	# 여우
	for c2: Vector3 in [WorldShape.fields, WorldShape.village + Vector3(-300, 0, -200)]:
		var fx: Fox = Fox.new().setup(c2, 280.0)
		add_child(fx)
		foxes.append(fx)
	# 바다 생물
	sea_life = SeaLife.new()
	add_child(sea_life)
	sea_life.setup(main)


## 계절·밤낮에 따라 누가 활동하는지
func _update_seasonal() -> void:
	var season := int(GameState.data.get("season", 0))
	var night: bool = main.day_night.is_night()
	var calm: bool = main.prologue.active
	for c in crows:
		c.active = not night and not calm
	for g in colony_gulls:
		g.active = season <= 1 and not night and not calm   # 번식기에만 둥지를 지킨다
	# 흰꼬리수리는 여름에는 북쪽으로 떠난다
	var here := season != 1
	if eagle.visible != here:
		eagle.visible = here
		eagle.process_mode = Node.PROCESS_MODE_INHERIT if here else Node.PROCESS_MODE_DISABLED
		if here:
			eagle.global_position = eagle.home
			eagle.mode = SeaEagle.E.PERCH
			eagle.perched = true


## 해 질 녘: 박쥐섬 동굴에서 박쥐 떼가 쏟아져 나온다
func emerge_bats() -> void:
	var ba := WorldShape.island_by_id("bats")
	var cave: Vector3 = ba.info.cave
	bats_out = 40.0
	for k in 3:
		var n := 14 + randi() % 5
		var fl := spawn_group("bat", cave + Vector3(-12, 3, 0), ba.center + Vector3(-250, 0, 0), 420.0, n, "bats")
		for p in fl.members:
			p.global_position = cave + Vector3(randf_range(-4, 2), randf_range(0, 5), randf_range(-5, 5))
			p.vel = Vector3(-randf_range(6, 10), randf_range(1, 4), randf_range(-3, 3))
			p.visible = false
			p.process_mode = Node.PROCESS_MODE_DISABLED
			var delay := k * 9.0 + randf() * 8.0
			get_tree().create_timer(delay, false).timeout.connect(func():
				if is_instance_valid(p):
					p.visible = true
					p.process_mode = Node.PROCESS_MODE_INHERIT
					p.global_position = cave + Vector3(randf_range(-4, 2), randf_range(0, 5), randf_range(-5, 5)))
	Sfx.play_at("bat", cave, 4.0, 1.0, 600.0)


## 새벽: 박쥐는 동굴로 돌아간다
func clear_bats() -> void:
	for p in prey:
		if is_instance_valid(p) and p.kind == "bat" and p.state in [Prey.S.FLY, Prey.S.FLEE]:
			p.vanish()


func markers() -> Array:
	var out := []
	if eagle and eagle.visible and eagle.mode == SeaEagle.E.CHASE:
		out.append({"pos": eagle.global_position, "color": Color(1.0, 0.3, 0.25), "label": Loc.t("mk_eagle")})
	if bats_out > 0.0:
		var ba := WorldShape.island_by_id("bats")
		out.append({"pos": (ba.info.cave as Vector3) + Vector3(0, 20, 0), "color": Color(0.8, 0.6, 1.0), "label": Loc.t("mk_bats")})
	return out


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
		if not is_instance_valid(p) or not p.visible:
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
	for m in mobbers:
		if m.mode == Mobber.M.FLEE:
			continue
		var mp: Vector3 = m.global_position
		if mp.distance_squared_to(b) > 2500.0:
			continue
		if seg_dist(a - m.prev, b - mp) < 2.2 and sp > 16.0:
			mobber_hit.emit(m)
			return
	if eagle and eagle.visible and eagle.mode != SeaEagle.E.FLEE:
		var ep := eagle.global_position
		if ep.distance_squared_to(b) < 2500.0 and seg_dist(a - eagle.prev, b - ep) < 3.4 and sp > 24.0:
			eagle_hit.emit(eagle)
			return


## 조준 보조: 화면 중앙 방향 원뿔 안의 가장 좋은 목표
func best_target(origin: Vector3, look: Vector3, max_dist: float, cone_deg: float) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	var cos_lim := cos(deg_to_rad(cone_deg))
	for p in prey:
		if not is_instance_valid(p) or not p.visible:
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
