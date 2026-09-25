class_name WorldShape
extends RefCounted
## 섬 해안 지형의 모양을 정의한다. 동쪽(+X)이 바다, 서쪽(-X)이 육지.
## 렌더링 메시와 충돌 판정이 같은 높이 격자를 쓰도록 격자를 한 번 만들어 둔다.

const HALF := 1400.0          # 플레이 영역 반경
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


## 메시 삼각형과 정확히 같은 지면 높이
static func ground(x: float, z: float) -> float:
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


static func in_bounds(p: Vector3) -> bool:
	return absf(p.x) < HALF and absf(p.z) < HALF


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
		thermals.append({"pos": Vector3(tp.x, gy, tp.y), "r": rng.randf_range(40.0, 60.0), "power": rng.randf_range(7.5, 10.5)})
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


static func nearest_perch(p: Vector3, radius: float) -> Dictionary:
	var best := {}
	var bd := radius
	for pr in perches:
		var d := (pr.pos as Vector3).distance_to(p)
		if d < bd:
			bd = d
			best = pr
	return best
