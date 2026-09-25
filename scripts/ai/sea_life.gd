class_name SeaLife
extends Node3D
## 바다의 배경 생물: 모래톱의 물범, 섬 사이를 오가는 돌고래 떼, 가끔 떠오르는 고래, 어선.
## 바닷새섬 절벽의 번식지(앉아 있는 바닷새들)도 여기서 만든다.

const BOATS := "res://assets/models/boats/"

var main
var seals: Array = []       # {node, head, home, mode, t, swim_c, swim_a}
var dolphins: Array = []    # {node, tail, phase, off}
var pod_path: Array = []
var pod_s := 0.0
var whale: Node3D
var whale_t := 60.0
var whale_state := -1.0     # <0: 숨어 있음, 0..1: 떠오름 진행
var whale_pos := Vector3.ZERO
var whale_dir := Vector3.FORWARD
var boats: Array = []       # {node, path, s, speed}
var _t := 0.0
var _seal_call := 3.0


func setup(p_main) -> void:
	main = p_main
	_build_colony()
	_spawn_seals()
	_spawn_dolphins()
	_spawn_boats()
	whale = CritterModel.whale()
	whale.visible = false
	add_child(whale)


# ---------- 번식지 ----------

func _build_colony() -> void:
	var isl := WorldShape.island_by_id("seabird")
	if isl == null:
		return
	var xs := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var col: Vector3 = isl.info.colony
	for i in 900:
		if xs.size() >= 160:
			break
		var p := col + Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-150, 150))
		# 절벽 면을 따라 안쪽으로 걸어 들어가며 선반을 찾는다
		var inward := (isl.center - p)
		inward.y = 0.0
		inward = inward.normalized()
		var y := rng.randf_range(8.0, 70.0)
		for k in 40:
			var g := WorldShape.ground(p.x, p.z)
			if g >= y:
				break
			p += inward * 0.8
		var g2 := WorldShape.ground(p.x, p.z)
		if g2 < 6.0 or absf(g2 - y) > 3.0:
			continue
		var n := WorldShape.normal(p.x, p.z)
		if n.y > 0.75:
			continue
		p.y = y + 0.1
		var face := Vector3(n.x, 0, n.z).normalized()
		xs.append(Transform3D(Basis.looking_at(face, Vector3.UP).scaled(Vector3.ONE * rng.randf_range(0.9, 1.2)), p - inward * 0.2))
	if xs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = CritterModel.sitting_bird_mesh()
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = 1400.0
	mmi.name = "Colony"
	add_child(mmi)


# ---------- 물범 ----------

func _spawn_seals() -> void:
	var isl := WorldShape.island_by_id("seals")
	if isl == null:
		return
	var outs: Array = isl.info.get("haulouts", [])
	for i in mini(outs.size(), 8):
		var n := CritterModel.seal()
		add_child(n)
		var hp: Vector3 = outs[i]
		n.position = hp
		n.rotation.y = randf() * TAU
		seals.append({"node": n, "head": n.get_node("body/head"), "home": hp, "mode": 0, "t": randf() * 10.0, "swim_a": 0.0, "home_rot": n.rotation.y})


func _update_seals(delta: float, fp: Vector3, near: bool) -> void:
	var isl := WorldShape.island_by_id("seals")
	for s in seals:
		var n: Node3D = s.node
		s.t += delta
		match int(s.mode):
			0:  # 모래 위에서 쉰다: 가끔 고개를 든다
				(s.head as Node3D).rotation.x = -maxf(sin(s.t * 0.35), 0.0) * 0.5
				n.position.y = s.home.y + sin(s.t * 1.2) * 0.02
				if near and Vector2(fp.x - n.position.x, fp.z - n.position.z).length() < 28.0 and fp.y - n.position.y < 22.0:
					s.mode = 1
					s.t = 0.0
					var out: Vector3 = n.position - isl.center
					out.y = 0.0
					s.swim_a = atan2(out.z, out.x)
					if near:
						Sfx.play_at("seal", n.position, 0.0, randf_range(0.9, 1.1), 250.0)
			1:  # 놀라서 물로 미끄러져 들어간다 → 섬 주위를 헤엄친다
				var r := maxf(isl.rb, 60.0) * 1.35
				s.swim_a = float(s.swim_a) + delta * 2.0 / r
				var tp := isl.to_world(cos(s.swim_a) * r * 0.9, sin(s.swim_a) * isl.ra * 1.1)
				var to: Vector3 = tp - n.position
				to.y = 0.0
				var step := to.normalized() * minf(to.length(), 3.0 * delta)
				n.position += step
				var g := WorldShape.ground(n.position.x, n.position.z)
				n.position.y = maxf(g, -0.35)
				if step.length() > 0.001:
					n.rotation.y = lerp_angle(n.rotation.y, atan2(-step.x, -step.z), 1.0 - exp(-3.0 * delta))
				if s.t > 30.0:
					s.mode = 2
			2:  # 다시 제자리로 올라온다
				var to2: Vector3 = s.home - n.position
				to2.y = 0.0
				if to2.length() < 0.5:
					s.mode = 0
					n.rotation.y = s.home_rot
				else:
					var st2 := to2.normalized() * minf(to2.length(), 2.0 * delta)
					n.position += st2
					var g2 := WorldShape.ground(n.position.x, n.position.z)
					n.position.y = maxf(g2, -0.35)
					n.rotation.y = lerp_angle(n.rotation.y, atan2(-st2.x, -st2.z), 1.0 - exp(-3.0 * delta))
	_seal_call -= delta
	if near and _seal_call <= 0.0 and not seals.is_empty():
		_seal_call = randf_range(5.0, 11.0)
		var sn: Node3D = seals[randi() % seals.size()].node
		Sfx.play_at("seal", sn.position, -4.0, randf_range(0.85, 1.1), 250.0)


# ---------- 돌고래 ----------

func _spawn_dolphins() -> void:
	var sb := WorldShape.island_by_id("seabird")
	var se := WorldShape.island_by_id("seals")
	var ba := WorldShape.island_by_id("bats")
	if sb == null or se == null or ba == null:
		return
	# 본섬 앞바다 → 바닷새섬 → 모래톱 → 박쥐섬 → 본섬 앞바다
	pod_path = [
		Vector3(WorldShape.coast_x(-200.0) + 380.0, 0, -200.0),
		sb.center + Vector3(-sb.rb - 150.0, 0, 120.0),
		sb.center + Vector3(sb.rb + 160.0, 0, 250.0),
		se.center + Vector3(-se.rb - 180.0, 0, -250.0),
		se.center + Vector3(-se.rb - 160.0, 0, 250.0),
		ba.center + Vector3(ba.rb + 170.0, 0, -80.0),
		ba.center + Vector3(-ba.rb - 200.0, 0, 60.0),
		Vector3(WorldShape.coast_x(700.0) + 420.0, 0, 700.0),
	]
	for i in 5:
		var n := CritterModel.dolphin()
		add_child(n)
		dolphins.append({"node": n, "phase": randf() * TAU, "off": Vector3(randf_range(-8, 8), 0, randf_range(-6, 6)), "lag": i * 5.0 + randf_range(0, 3)})


func _pod_point(s: float) -> Vector3:
	var total := 0.0
	var n := pod_path.size()
	for i in n:
		total += (pod_path[i] as Vector3).distance_to(pod_path[(i + 1) % n])
	s = fposmod(s, total)
	for i in n:
		var a: Vector3 = pod_path[i]
		var b: Vector3 = pod_path[(i + 1) % n]
		var l := a.distance_to(b)
		if s <= l:
			return a.lerp(b, s / l)
		s -= l
	return pod_path[0]


func _update_dolphins(delta: float, fp: Vector3) -> void:
	if pod_path.is_empty():
		return
	pod_s += delta * 7.0
	if fp.distance_squared_to(_pod_point(pod_s)) > 1100.0 * 1100.0:
		return
	for d in dolphins:
		var n: Node3D = d.node
		var s: float = pod_s - float(d.lag)
		var p := _pod_point(s) + (d.off as Vector3)
		var ahead := _pod_point(s + 4.0) + (d.off as Vector3)
		d.phase = float(d.phase) + delta * 1.6
		# 한 주기의 일부 동안만 물 밖으로 뛰어오른다
		var c := fposmod(float(d.phase), TAU * 2.0) / (TAU * 2.0)
		var y := -1.6
		var pitch := 0.0
		if c < 0.28:
			var k := c / 0.28
			y = -1.2 + sin(k * PI) * 3.0
			pitch = cos(k * PI) * 0.8
			if k > 0.93 and not d.get("splashed", false):
				d["splashed"] = true
				if fp.distance_to(p) < 450.0:
					main.fx_splash(Vector3(p.x, 0, p.z), 0.8)
					Sfx.play_at("splash", Vector3(p.x, 0, p.z), -8.0, 1.2, 300.0)
		else:
			d["splashed"] = false
		n.position = Vector3(p.x, y, p.z)
		var fwd := ahead - p
		fwd.y = 0.0
		if fwd.length() > 0.1:
			n.basis = Basis.looking_at(fwd.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, pitch)


# ---------- 고래 ----------

func _update_whale(delta: float, fp: Vector3, fdir: Vector3) -> void:
	if whale_state < 0.0:
		whale_t -= delta
		if whale_t <= 0.0:
			# 매가 보고 있는 방향의 먼 바다에서 떠오른다
			var d := Vector3(fdir.x, 0, fdir.z)
			if d.length() < 0.2:
				d = Vector3.RIGHT
			var p := fp + d.normalized().rotated(Vector3.UP, randf_range(-0.5, 0.5)) * randf_range(350.0, 700.0)
			if WorldShape.ground(p.x, p.z) < -20.0 and WorldShape.in_bounds(p, 150.0):
				whale_pos = Vector3(p.x, 0, p.z)
				whale_dir = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
				whale_state = 0.0
				whale.visible = true
				_blow(whale_pos)
			else:
				whale_t = 20.0
		return
	# 12초: 등이 굴러 지나가고 꼬리를 들고 잠수한다
	whale_state += delta / 12.0
	var k := whale_state
	var body: Node3D = whale.get_node("body")
	var fluke: Node3D = whale.get_node("fluke")
	whale.position = whale_pos + whale_dir * (k * 30.0)
	whale.basis = Basis.looking_at(whale_dir, Vector3.UP)
	var rise := sin(clampf(k / 0.7, 0.0, 1.0) * PI)
	body.position.y = lerpf(-3.0, -0.2, rise)   # 등이 1 m쯤 물 위로 올라온다
	body.rotation.x = lerpf(0.15, -0.2, clampf(k / 0.7, 0.0, 1.0))
	var fk := clampf((k - 0.62) / 0.38, 0.0, 1.0)
	fluke.position = Vector3(0, lerpf(-3.0, 2.2, sin(fk * PI)), 7.0 + fk * 2.0)
	fluke.rotation.x = -sin(fk * PI) * 1.1
	if k >= 1.0:
		whale_state = -1.0
		whale.visible = false
		whale_t = randf_range(150.0, 300.0)
		main.fx_splash(whale_pos + whale_dir * 30.0, 1.6)


func _blow(p: Vector3) -> void:
	# 물줄기: 위로 솟는 물보라
	Sfx.play_at("blow", p, 4.0, randf_range(0.9, 1.05), 900.0)
	main.fx_splash(p + Vector3.UP * 1.0, 1.5)


# ---------- 어선 ----------

func _spawn_boats() -> void:
	var sb := WorldShape.island_by_id("seabird")
	var ba := WorldShape.island_by_id("bats")
	if sb == null or ba == null:
		return
	var dock := Vector3(WorldShape.coast_x(WorldShape.village.z) + 80.0, 0, WorldShape.village.z)
	var routes := [
		[dock, dock + Vector3(500, 0, -350), sb.center + Vector3(-260, 0, 250), sb.center + Vector3(-60, 0, 380), dock + Vector3(700, 0, -200)],
		[dock + Vector3(60, 0, 80), ba.center + Vector3(-250, 0, 150), ba.center + Vector3(150, 0, 260), dock + Vector3(900, 0, 300)],
	]
	var files := ["boat-fishing-small.glb", "boat-sail-a.glb"]
	for i in routes.size():
		var ps: PackedScene = load(BOATS + files[i])
		var b: Node3D = ps.instantiate()
		b.scale = Vector3.ONE * 2.2
		b.position = routes[i][0]
		add_child(b)
		boats.append({"node": b, "path": routes[i], "s": randf() * 800.0, "speed": randf_range(4.0, 5.5), "seg": 0})


func _update_boats(delta: float) -> void:
	for bo in boats:
		var path: Array = bo.path
		var n: Node3D = bo.node
		var i: int = bo.seg
		var b: Vector3 = path[(i + 1) % path.size()]
		var to := b - n.position
		to.y = 0.0
		if to.length() < 6.0:
			bo.seg = (i + 1) % path.size()
		var dirv := to.normalized()
		n.position += dirv * float(bo.speed) * delta
		n.position.y = sin(_t * 1.1 + i) * 0.25 - 0.1
		var yaw := atan2(dirv.x, dirv.z)
		n.rotation = Vector3(sin(_t * 0.7 + i) * 0.03, lerp_angle(n.rotation.y, yaw, 1.0 - exp(-0.8 * delta)), sin(_t * 0.9 + i) * 0.04)


func _seals_busy() -> bool:
	for s in seals:
		if int(s.mode) != 0:
			return true
	return false


# ---------- 매 프레임 ----------

func _process(delta: float) -> void:
	if main == null:
		return
	_t += delta
	var f: Falcon = main.falcon
	var fp := f.global_position
	var se := WorldShape.island_by_id("seals")
	var near := se != null and fp.distance_to(se.center) < 700.0
	if near or _seals_busy():
		_update_seals(delta, fp, near)
	_update_dolphins(delta, fp)
	_update_whale(delta, fp, f.dir)
	_update_boats(delta)
