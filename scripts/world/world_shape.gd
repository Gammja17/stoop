class_name WorldShape
extends RefCounted
## 섬 해안 지형의 모양을 정의한다. 동쪽(+X)이 바다, 서쪽(-X)이 육지.
## 렌더링 메시와 충돌 판정이 같은 높이 격자를 쓰도록 격자를 한 번 만들어 둔다.

const HALF := 1400.0          # 본섬 영역 반경
const X_MIN := -1400.0        # 비행 영역: 서쪽 끝
const X_MAX := 3000.0         # 비행 영역: 동쪽 바다의 섬들까지
const RENDER_HALF := 2000.0   # 지형 메시 반경
const CELL := 10.0
const GRID := int(RENDER_HALF * 2.0 / CELL) + 1
const SEA := 0.0
const MAX_ALT := 900.0

static var is_ready := false
static var _n_coast: FastNoiseLite
static var _n_big: FastNoiseLite
static var _n_mid: FastNoiseLite
static var _n_fine: FastNoiseLite
static var grid := PackedFloat32Array()

static var stacks: Array = []        # {pos: Vector3(바닥 중심), r, h}
static var perches: Array = []       # {pos, kind, facing}
static var thermals: Array = []      # {pos: Vector3(지면), r, power}
static var eyrie := Vector3.ZERO
static var eyrie_facing := Vector3.RIGHT
static var village := Vector3.ZERO
static var lighthouse := Vector3.ZERO
static var bay := Vector3.ZERO
static var fields := Vector3.ZERO
static var cliffs_center := Vector3.ZERO
static var islands: Array = []       # Island (먼 바다의 섬)

## 먼 섬: 자기만의 작은 높이 격자를 가진다 (본섬 격자는 그대로)
const ISLAND_SPECS := [
	{"id": "seabird", "pos": Vector2(1850, -850), "rot": 0.3, "ra": 240.0, "rb": 120.0, "cell": 6.0},
	{"id": "seals", "pos": Vector2(2500, 300), "rot": -0.15, "ra": 380.0, "rb": 85.0, "cell": 8.0},
	{"id": "bats", "pos": Vector2(1600, 1050), "rot": 0.0, "ra": 80.0, "rb": 70.0, "cell": 4.0},
]


class Island:
	var id: String
	var center := Vector3.ZERO
	var rot := 0.0
	var ra := 0.0     # 남북 반지름
	var rb := 0.0     # 동서 반지름
	var x0 := 0.0
	var z0 := 0.0
	var cell := 8.0
	var nx := 0
	var nz := 0
	var h := PackedFloat32Array()
	var info := {}    # 특징 지점: top, colony, cave, knoll, haulouts

	func contains(x: float, z: float) -> bool:
		return x >= x0 and z >= z0 and x < x0 + (nx - 1) * cell and z < z0 + (nz - 1) * cell

	func hgt(i: int, j: int) -> float:
		return h[clampi(j, 0, nz - 1) * nx + clampi(i, 0, nx - 1)]

	## 본섬과 같은 삼각형 분할로 보간 (메시와 동일)
	func sample(x: float, z: float) -> float:
		var fx := (x - x0) / cell
		var fz := (z - z0) / cell
		var i := int(floor(fx))
		var j := int(floor(fz))
		fx -= i
		fz -= j
		var a := h[j * nx + i]
		var b := h[j * nx + i + 1]
		var c := h[(j + 1) * nx + i]
		var d := h[(j + 1) * nx + i + 1]
		if fx >= fz:
			return a + (b - a) * fx + (d - b) * fz
		return a + (d - c) * fx + (c - a) * fz

	## 섬 좌표 (u: 동서, v: 남북) → 월드
	func to_world(u: float, v: float) -> Vector3:
		var x := center.x + u * cos(rot) + v * sin(rot)
		var z := center.z - u * sin(rot) + v * cos(rot)
		return Vector3(x, 0.0, z)


static func setup(seed_value: int = 20260925) -> void:
	if is_ready:
		return
	_n_coast = FastNoiseLite.new()
	_n_coast.seed = seed_value
	_n_coast.frequency = 0.0032
	_n_coast.fractal_octaves = 3
	_n_big = FastNoiseLite.new()
	_n_big.seed = seed_value + 1
	_n_big.frequency = 0.0017
	_n_big.fractal_octaves = 4
	_n_mid = FastNoiseLite.new()
	_n_mid.seed = seed_value + 2
	_n_mid.frequency = 0.009
	_n_mid.fractal_octaves = 3
	_n_fine = FastNoiseLite.new()
	_n_fine.seed = seed_value + 3
	_n_fine.frequency = 0.045
	_n_fine.fractal_octaves = 2
	_build_grid()
	_build_islands()
	_compute_features()
	is_ready = true


# ---------- 해석적 높이 (격자 생성용) ----------

static func bay_factor(z: float) -> float:
	var u := (z - 560.0) / 340.0
	if absf(u) >= 1.0:
		return 0.0
	var c := cos(u * PI * 0.5)
	return c * c


static func cliff_factor(z: float) -> float:
	return 1.0 - smoothstep(-120.0, 260.0, z)


static func coast_x(z: float) -> float:
	return 25.0 * sin(z * 0.0027) + 55.0 * _n_coast.get_noise_1d(z) - 380.0 * bay_factor(z)


static func raw_height(x: float, z: float) -> float:
	var c := coast_x(z)
	var d := c - x
	if d < -700.0:
		return -45.0   # 먼 바다 바닥 (아래 식도 여기선 -45로 잘린다)
	var cf := cliff_factor(z)
	var big := _n_big.get_noise_2d(x, z)
	var plateau := lerpf(14.0, 118.0, cf) + 22.0 * big + 7.0 * _n_mid.get_noise_2d(x, z)
	plateau += maxf(0.0, -x - 250.0) * 0.11
	plateau += maxf(0.0, -x - 950.0) * 0.4 * (0.6 + 0.4 * big)
	var h: float
	if d >= 0.0:
		var ramp := lerpf(150.0, 15.0, cf)
		var e := smoothstep(0.0, ramp, d)
		h = lerpf(1.0, plateau, e)
		h += 1.8 * _n_fine.get_noise_2d(x, z) * e
	else:
		var deep := -3.0 - 5.0 * cf + d * 0.07
		h = maxf(lerpf(1.0, deep, smoothstep(0.0, lerpf(40.0, 12.0, cf), -d)), -45.0)
	var bf := bay_factor(z)
	if bf > 0.0 and d < 0.0 and d > -560.0:
		var flat := -0.45 + 1.0 * _n_mid.get_noise_2d(x * 1.6, z * 1.6) + 0.3 * _n_fine.get_noise_2d(x, z)
		var w := bf * smoothstep(-560.0, -120.0, d) * smoothstep(0.0, 30.0, -d)
		h = lerpf(h, flat, w)
	return h


static func _build_grid() -> void:
	grid.resize(GRID * GRID)
	for j in GRID:
		var z := -RENDER_HALF + j * CELL
		for i in GRID:
			var x := -RENDER_HALF + i * CELL
			grid[j * GRID + i] = raw_height(x, z)


# ---------- 격자 기반 조회 (메시와 동일) ----------

static func gh(i: int, j: int) -> float:
	i = clampi(i, 0, GRID - 1)
	j = clampi(j, 0, GRID - 1)
	return grid[j * GRID + i]


## 메시 삼각형과 정확히 같은 지면 높이 (먼 바다에선 섬 격자도 본다)
static func ground(x: float, z: float) -> float:
	var h := _grid_ground(x, z)
	if h < -12.0:
		for isl: Island in islands:
			if isl.contains(x, z):
				return maxf(h, isl.sample(x, z))
	return h


static func _grid_ground(x: float, z: float) -> float:
	if grid.is_empty():
		return 0.0
	var fx := (x + RENDER_HALF) / CELL
	var fz := (z + RENDER_HALF) / CELL
	var i := int(floor(fx))
	var j := int(floor(fz))
	if i < 0 or j < 0 or i >= GRID - 1 or j >= GRID - 1:
		return -40.0
	fx -= i
	fz -= j
	var a := grid[j * GRID + i]
	var b := grid[j * GRID + i + 1]
	var c := grid[(j + 1) * GRID + i]
	var d := grid[(j + 1) * GRID + i + 1]
	if fx >= fz:
		return a + (b - a) * fx + (d - b) * fz
	return a + (d - c) * fx + (c - a) * fz


## 지면과 수면 중 높은 쪽
static func floor_y(x: float, z: float) -> float:
	return maxf(ground(x, z), SEA)


static func is_water(x: float, z: float) -> bool:
	return ground(x, z) < SEA


static func normal(x: float, z: float) -> Vector3:
	var e := CELL * 0.5
	var hx := ground(x + e, z) - ground(x - e, z)
	var hz := ground(x, z + e) - ground(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


## 충돌 장애물(해식 기둥, 등대). 부딪히면 true
static func hits_obstacle(p: Vector3, pad: float = 0.5) -> bool:
	for s in stacks:
		var sp: Vector3 = s.pos
		if p.y < sp.y + s.h:
			var dx := p.x - sp.x
			var dz := p.z - sp.z
			var rr: float = s.r * lerpf(1.0, 0.7, clampf((p.y - sp.y) / s.h, 0.0, 1.0)) + pad
			if dx * dx + dz * dz < rr * rr:
				return true
	if p.y < lighthouse.y + 22.0:
		var ldx := p.x - lighthouse.x
		var ldz := p.z - lighthouse.z
		if ldx * ldx + ldz * ldz < (3.2 + pad) * (3.2 + pad):
			return true
	return false


static func in_bounds(p: Vector3, margin: float = 0.0) -> bool:
	return p.x > X_MIN + margin and p.x < X_MAX - margin and absf(p.z) < HALF - margin


## 경계 밖(또는 margin 안쪽)에서 안으로 향하는 수평 방향
static func inward(p: Vector3, margin: float = 0.0) -> Vector3:
	var v := Vector3.ZERO
	if p.x < X_MIN + margin:
		v.x += 1.0
	elif p.x > X_MAX - margin:
		v.x -= 1.0
	if p.z < -HALF + margin:
		v.z += 1.0
	elif p.z > HALF - margin:
		v.z -= 1.0
	return v.normalized()


## 가까운 섬 (없으면 null)
static func island_near(p: Vector3, extra: float = 0.0) -> Island:
	for isl: Island in islands:
		var d := Vector2(p.x - isl.center.x, p.z - isl.center.z).length()
		if d < maxf(isl.ra, isl.rb) + extra:
			return isl
	return null


static func island_by_id(id: String) -> Island:
	for isl: Island in islands:
		if isl.id == id:
			return isl
	return null


## 해안선까지의 대략적인 수평 거리 (파도 소리용)
static func shore_dist(p: Vector3) -> float:
	var best := absf(p.x - coast_x(p.z))
	for isl: Island in islands:
		var d := Vector2(p.x - isl.center.x, p.z - isl.center.z).length()
		best = minf(best, absf(d - (isl.ra + isl.rb) * 0.5))
	return best


# ---------- 먼 섬 ----------

static func _build_islands() -> void:
	islands.clear()
	for sp in ISLAND_SPECS:
		var isl := Island.new()
		isl.id = sp.id
		isl.center = Vector3(sp.pos.x, 0.0, sp.pos.y)
		isl.rot = sp.rot
		isl.ra = sp.ra
		isl.rb = sp.rb
		isl.cell = sp.cell
		var ex := (absf(isl.rb * cos(isl.rot)) + absf(isl.ra * sin(isl.rot))) * 1.5
		var ez := (absf(isl.rb * sin(isl.rot)) + absf(isl.ra * cos(isl.rot))) * 1.5
		isl.nx = int(ceil(ex * 2.0 / isl.cell)) + 1
		isl.nz = int(ceil(ez * 2.0 / isl.cell)) + 1
		isl.x0 = isl.center.x - ex
		isl.z0 = isl.center.z - ez
		isl.h.resize(isl.nx * isl.nz)
		for j in isl.nz:
			var z := isl.z0 + j * isl.cell
			for i in isl.nx:
				var x := isl.x0 + i * isl.cell
				isl.h[j * isl.nx + i] = _island_raw(isl, x, z)
		islands.append(isl)


static func _island_raw(isl: Island, x: float, z: float) -> float:
	var dx := x - isl.center.x
	var dz := z - isl.center.z
	var u := dx * cos(isl.rot) - dz * sin(isl.rot)     # 동(+) 서(-)
	var v := dx * sin(isl.rot) + dz * cos(isl.rot)     # 남(+) 북(-)
	var q := sqrt(pow(u / isl.rb, 2.0) + pow(v / isl.ra, 2.0))
	q *= 1.0 + 0.1 * _n_coast.get_noise_2d(x * 2.0, z * 2.0)
	var fine := _n_fine.get_noise_2d(x, z)
	var mid := _n_mid.get_noise_2d(x, z)
	match isl.id:
		"seabird":
			# 동쪽이 높은 절벽, 서쪽은 완만한 바위 비탈
			var sea := -3.0 - 35.0 * smoothstep(1.0, 1.45, q)
			if q >= 1.0:
				return lerpf(0.8, sea, smoothstep(1.0, 1.08, q))
			var side := smoothstep(-0.4, 0.5, u / isl.rb)
			var top := 60.0 + 20.0 * clampf(u / isl.rb, -1.0, 1.0) + 7.0 * mid + 5.0 * (1.0 - pow(v / isl.ra, 2.0))
			var m := 1.0 - smoothstep(lerpf(0.5, 0.9, side), 1.0, q)
			return lerpf(0.8, top, m) + 1.5 * fine * m
		"seals":
			# 낮은 모래톱 + 북쪽 끝의 바위 언덕
			var sea2 := -2.0 - 38.0 * smoothstep(1.0, 1.4, q)
			var kn := isl.to_world(0.0, -isl.ra * 0.72)
			var kd := Vector2(x - kn.x, z - kn.z).length()
			var knoll := (1.0 - smoothstep(8.0, 40.0, kd)) * (15.0 + 4.0 * fine)
			if q >= 1.0:
				var hs := lerpf(0.5, sea2, smoothstep(1.0, 1.12, q))
				return maxf(hs, knoll - 2.0) if knoll > 0.0 else hs
			var m2 := 1.0 - smoothstep(0.2, 1.0, q)
			return lerpf(0.5, 3.2 + 1.2 * mid, m2) + maxf(knoll - 2.0, 0.0)
		"bats":
			# 좁고 높은 바위 기둥 섬
			var sea3 := -4.0 - 36.0 * smoothstep(1.0, 1.35, q)
			if q >= 1.0:
				return lerpf(0.5, sea3, smoothstep(1.0, 1.06, q))
			var top3 := 104.0 + 14.0 * (1.0 - q * q) + 6.0 * mid
			var m3 := 1.0 - smoothstep(0.8, 1.0, q)
			return lerpf(0.5, top3, m3) + 2.0 * fine * m3
	return -40.0


## 섬의 특징 지점 (정상, 바닷새 번식지, 박쥐 동굴, 바위 언덕, 물범 쉼터)
static func _island_features(rng: RandomNumberGenerator) -> void:
	for isl: Island in islands:
		# 정상
		var best := Vector3(isl.center.x, -100.0, isl.center.z)
		for j in isl.nz:
			for i in isl.nx:
				var hh := isl.h[j * isl.nx + i]
				if hh > best.y:
					best = Vector3(isl.x0 + i * isl.cell, hh, isl.z0 + j * isl.cell)
		isl.info["top"] = best
		perches.append({"pos": best + Vector3(0, 1.0, 0), "kind": "rock", "facing": Vector3.RIGHT})
		match isl.id:
			"seabird":
				var col := isl.to_world(isl.rb * 0.97, 0.0)
				col.y = 38.0
				isl.info["colony"] = col
				for k in 3:
					var a := -0.9 + k * 0.9
					var sp := isl.to_world(cos(a) * (isl.rb + 70.0), sin(a) * (isl.ra * 0.8))
					_add_stack(rng, sp)
			"seals":
				var kn := isl.to_world(0.0, -isl.ra * 0.72)
				kn.y = ground(kn.x, kn.z)
				isl.info["knoll"] = kn
				var outs := []
				var tries := 0
				while outs.size() < 10 and tries < 200:
					tries += 1
					var hp := isl.to_world(rng.randf_range(-isl.rb, isl.rb) * 0.8, rng.randf_range(-0.4, 0.9) * isl.ra)
					hp.y = ground(hp.x, hp.z)
					if hp.y > 0.6 and hp.y < 3.0 and normal(hp.x, hp.z).y > 0.97:
						outs.append(hp)
				isl.info["haulouts"] = outs
			"bats":
				var cave := isl.to_world(-isl.rb * 0.95, 0.0)
				cave.y = 3.0
				isl.info["cave"] = cave
				_add_stack(rng, isl.to_world(-isl.rb - 60.0, isl.ra * 0.9))
				_add_stack(rng, isl.to_world(isl.rb + 45.0, -isl.ra * 1.1))


static func _add_stack(rng: RandomNumberGenerator, p: Vector3) -> void:
	var base := ground(p.x, p.z)
	if base > -2.0:
		return
	var s := {"pos": Vector3(p.x, base, p.z), "r": rng.randf_range(10.0, 17.0), "h": rng.randf_range(30.0, 60.0) - base}
	stacks.append(s)
	perches.append({"pos": Vector3(p.x, base + s.h + 0.3, p.z), "kind": "stack", "facing": Vector3.RIGHT})


# ---------- 지형 특징 ----------

static func _compute_features() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	# 둥지(절벽 선반): 절벽 면에서 높이의 62% 지점
	var ez := -380.0
	var c := coast_x(ez)
	var top := ground(c - 70.0, ez)
	var ledge_h := top * 0.62
	var ex := c
	var x := c + 10.0
	while x > c - 80.0:
		if ground(x, ez) >= ledge_h:
			ex = x
			break
		x -= 0.5
	eyrie = Vector3(ex + 2.5, ledge_h + 0.6, ez)
	var n := normal(ex, ez)
	eyrie_facing = Vector3(n.x, 0.0, n.z).normalized()
	if eyrie_facing.length() < 0.5:
		eyrie_facing = Vector3.RIGHT
	cliffs_center = Vector3(coast_x(-500.0), 0.0, -500.0)
	# 해식 기둥
	stacks.clear()
	var tries := 0
	while stacks.size() < 9 and tries < 200:
		tries += 1
		var z := rng.randf_range(-1150.0, 120.0)
		var sx := coast_x(z) + rng.randf_range(70.0, 330.0)
		var base := ground(sx, z)
		if base > -2.0:
			continue
		var pos := Vector3(sx, base, z)
		var ok := pos.distance_to(Vector3(eyrie.x, base, eyrie.z)) > 90.0
		for s in stacks:
			if (s.pos as Vector3).distance_to(pos) < 90.0:
				ok = false
		if not ok:
			continue
		stacks.append({"pos": pos, "r": rng.randf_range(11.0, 22.0), "h": rng.randf_range(35.0, 95.0) - base})
	# 마을, 등대, 갯벌, 들판
	var vz := 1090.0
	village = Vector3(coast_x(vz) - 110.0, 0.0, vz)
	village.y = ground(village.x, village.z)
	var lz := 1250.0
	lighthouse = Vector3(coast_x(lz) - 22.0, 0.0, lz)
	lighthouse.y = ground(lighthouse.x, lighthouse.z)
	bay = Vector3(coast_x(560.0) + 170.0, 0.0, 560.0)
	fields = Vector3(-620.0, 0.0, 250.0)
	fields.y = ground(fields.x, fields.z)
	# 상승기류
	thermals.clear()
	for tp in [Vector2(-420, -620), Vector2(-700, 150), Vector2(-380, 520), Vector2(-260, 950), Vector2(-900, -300), Vector2(-150, -150)]:
		var gy := ground(tp.x, tp.y)
		thermals.append({"pos": Vector3(tp.x, gy, tp.y), "r": rng.randf_range(70.0, 90.0), "power": rng.randf_range(27.0, 31.0)})
	# 앉을 곳
	perches.clear()
	perches.append({"pos": eyrie, "kind": "eyrie", "facing": eyrie_facing})
	for s in stacks:
		var sp: Vector3 = s.pos
		perches.append({"pos": Vector3(sp.x, sp.y + s.h + 0.3, sp.z), "kind": "stack", "facing": Vector3.RIGHT})
	perches.append({"pos": lighthouse + Vector3(0, 22.6, 0), "kind": "lighthouse", "facing": Vector3.RIGHT})
	# 절벽 위 전망 바위
	for z in [-1000.0, -760.0, -560.0, -200.0, 40.0]:
		var cx := coast_x(z) - 30.0
		perches.append({"pos": Vector3(cx, ground(cx, z) + 1.2, z), "kind": "rock", "facing": Vector3.RIGHT})
	_island_features(rng)


static func nearest_perch(p: Vector3, radius: float) -> Dictionary:
	var best := {}
	var bd := radius
	for pr in perches:
		var d := (pr.pos as Vector3).distance_to(p)
		if d < bd:
			bd = d
			best = pr
	return best
