class_name BirdModel
extends Node3D
## 저폴리 새 모델을 코드로 만든다. 날개가 어깨/손목 두 관절이라 날갯짓·급강하 접기가 가능하다.
## 앞쪽이 -Z.

const SPECS := {
	"falcon": {
		"scale": 1.0, "back": Color(0.24, 0.28, 0.33), "wing": Color(0.27, 0.31, 0.37), "prim": Color(0.13, 0.15, 0.18),
		"belly": Color(0.9, 0.88, 0.82), "under": Color(0.78, 0.77, 0.74), "head": Color(0.11, 0.12, 0.14), "cheek": Color(0.95, 0.94, 0.9),
		"beak": Color(0.96, 0.78, 0.18), "tip": Color(0.18, 0.2, 0.24), "feet": Color(0.98, 0.8, 0.15),
		"arm": 0.22, "hand": 0.27, "chord": 0.13, "point": 1.0, "body": 1.0, "tail": 0.2, "beak_len": 0.045, "malar": true,
	},
	"falcon_f": {
		"base": "falcon", "scale": 1.14, "back": Color(0.27, 0.28, 0.31), "wing": Color(0.3, 0.31, 0.35),
	},
	"juvenile": {
		"base": "falcon", "scale": 0.96, "back": Color(0.36, 0.27, 0.2), "wing": Color(0.4, 0.3, 0.22), "prim": Color(0.2, 0.15, 0.11),
		"belly": Color(0.84, 0.73, 0.56), "under": Color(0.72, 0.62, 0.48), "head": Color(0.28, 0.2, 0.15), "feet": Color(0.7, 0.75, 0.6),
	},
	"rival": {
		"base": "falcon", "scale": 1.06, "back": Color(0.16, 0.18, 0.22), "wing": Color(0.19, 0.21, 0.25), "belly": Color(0.8, 0.77, 0.7),
	},
	"pigeon": {
		"scale": 0.82, "back": Color(0.56, 0.59, 0.64), "wing": Color(0.6, 0.63, 0.68), "prim": Color(0.25, 0.26, 0.3),
		"belly": Color(0.66, 0.68, 0.72), "under": Color(0.8, 0.82, 0.85), "head": Color(0.36, 0.39, 0.46), "cheek": Color(0.4, 0.5, 0.48),
		"beak": Color(0.2, 0.2, 0.22), "tip": Color(0.15, 0.15, 0.15), "feet": Color(0.85, 0.4, 0.45),
		"arm": 0.18, "hand": 0.2, "chord": 0.14, "point": 0.6, "body": 1.15, "tail": 0.17, "beak_len": 0.025, "malar": false,
	},
	"starling": {
		"scale": 0.52, "back": Color(0.12, 0.11, 0.15), "wing": Color(0.14, 0.13, 0.17), "prim": Color(0.08, 0.08, 0.1),
		"belly": Color(0.16, 0.15, 0.2), "under": Color(0.3, 0.3, 0.34), "head": Color(0.1, 0.1, 0.13), "cheek": Color(0.2, 0.15, 0.3),
		"beak": Color(0.95, 0.85, 0.3), "tip": Color(0.8, 0.7, 0.2), "feet": Color(0.5, 0.35, 0.3),
		"arm": 0.18, "hand": 0.2, "chord": 0.13, "point": 0.95, "body": 0.95, "tail": 0.13, "beak_len": 0.04, "malar": false,
	},
	"sandpiper": {
		"scale": 0.5, "back": Color(0.52, 0.45, 0.36), "wing": Color(0.5, 0.44, 0.36), "prim": Color(0.25, 0.22, 0.2),
		"belly": Color(0.93, 0.92, 0.9), "under": Color(0.92, 0.92, 0.92), "head": Color(0.5, 0.44, 0.37), "cheek": Color(0.9, 0.88, 0.85),
		"beak": Color(0.15, 0.14, 0.13), "tip": Color(0.1, 0.1, 0.1), "feet": Color(0.2, 0.2, 0.2),
		"arm": 0.18, "hand": 0.22, "chord": 0.12, "point": 1.0, "body": 0.9, "tail": 0.12, "beak_len": 0.1, "malar": false,
	},
	"duck": {
		"scale": 1.0, "back": Color(0.42, 0.34, 0.26), "wing": Color(0.46, 0.4, 0.33), "prim": Color(0.3, 0.28, 0.26),
		"belly": Color(0.62, 0.58, 0.52), "under": Color(0.8, 0.78, 0.74), "head": Color(0.08, 0.34, 0.2), "cheek": Color(0.08, 0.3, 0.18),
		"beak": Color(0.95, 0.8, 0.2), "tip": Color(0.3, 0.3, 0.2), "feet": Color(0.95, 0.55, 0.2),
		"arm": 0.17, "hand": 0.18, "chord": 0.12, "point": 0.8, "body": 1.35, "tail": 0.1, "beak_len": 0.05, "malar": false,
	},
	"gull": {
		"scale": 1.3, "back": Color(0.66, 0.7, 0.74), "wing": Color(0.66, 0.7, 0.75), "prim": Color(0.08, 0.08, 0.09),
		"belly": Color(0.97, 0.97, 0.97), "under": Color(0.94, 0.95, 0.96), "head": Color(0.97, 0.97, 0.97), "cheek": Color(0.97, 0.97, 0.97),
		"beak": Color(0.95, 0.85, 0.2), "tip": Color(0.85, 0.2, 0.15), "feet": Color(0.95, 0.75, 0.55),
		"arm": 0.25, "hand": 0.3, "chord": 0.12, "point": 0.9, "body": 1.0, "tail": 0.14, "beak_len": 0.05, "malar": false,
	},
	"owl": {
		"scale": 1.7, "back": Color(0.4, 0.3, 0.21), "wing": Color(0.45, 0.34, 0.23), "prim": Color(0.3, 0.22, 0.15),
		"belly": Color(0.66, 0.52, 0.34), "under": Color(0.72, 0.6, 0.42), "head": Color(0.42, 0.31, 0.21), "cheek": Color(0.58, 0.45, 0.3),
		"beak": Color(0.15, 0.13, 0.12), "tip": Color(0.1, 0.1, 0.1), "feet": Color(0.6, 0.5, 0.35),
		"arm": 0.22, "hand": 0.22, "chord": 0.18, "point": 0.35, "body": 1.25, "tail": 0.13, "beak_len": 0.03, "malar": false, "tufts": true, "big_head": true,
	},
	"murrelet": {
		"scale": 0.58, "back": Color(0.3, 0.33, 0.37), "wing": Color(0.27, 0.29, 0.33), "prim": Color(0.1, 0.1, 0.12),
		"belly": Color(0.95, 0.95, 0.95), "under": Color(0.9, 0.9, 0.9), "head": Color(0.08, 0.08, 0.09), "cheek": Color(0.1, 0.1, 0.12),
		"beak": Color(0.9, 0.86, 0.72), "tip": Color(0.6, 0.55, 0.45), "feet": Color(0.5, 0.55, 0.65),
		"arm": 0.13, "hand": 0.15, "chord": 0.1, "point": 0.8, "body": 1.1, "tail": 0.07, "beak_len": 0.025, "malar": false,
	},
	"bat": {
		"scale": 0.5, "back": Color(0.24, 0.17, 0.12), "wing": Color(0.17, 0.12, 0.09), "prim": Color(0.12, 0.09, 0.07),
		"belly": Color(0.32, 0.24, 0.17), "under": Color(0.2, 0.15, 0.12), "head": Color(0.22, 0.16, 0.11), "cheek": Color(0.22, 0.16, 0.11),
		"beak": Color(0.15, 0.1, 0.1), "tip": Color(0.1, 0.08, 0.08), "feet": Color(0.1, 0.08, 0.07),
		"arm": 0.16, "hand": 0.2, "chord": 0.16, "point": 0.3, "body": 0.8, "tail": 0.05, "beak_len": 0.01, "malar": false, "tufts": true,
	},
	"eagle": {
		"scale": 2.3, "back": Color(0.33, 0.24, 0.16), "wing": Color(0.3, 0.22, 0.15), "prim": Color(0.12, 0.1, 0.08),
		"belly": Color(0.36, 0.26, 0.18), "under": Color(0.3, 0.22, 0.16), "head": Color(0.74, 0.66, 0.52), "cheek": Color(0.7, 0.62, 0.48),
		"beak": Color(0.97, 0.82, 0.25), "tip": Color(0.9, 0.75, 0.2), "feet": Color(0.98, 0.8, 0.2),
		"arm": 0.3, "hand": 0.3, "chord": 0.19, "point": 0.12, "body": 1.1, "tail": 0.13, "beak_len": 0.06, "malar": false,
		"tail_top": Color(0.95, 0.94, 0.9), "tail_tip": Color(0.92, 0.9, 0.86), "tail_under": Color(0.95, 0.94, 0.9),
	},
	"crow": {
		"scale": 0.95, "back": Color(0.07, 0.07, 0.09), "wing": Color(0.08, 0.08, 0.1), "prim": Color(0.05, 0.05, 0.06),
		"belly": Color(0.09, 0.09, 0.11), "under": Color(0.1, 0.1, 0.12), "head": Color(0.06, 0.06, 0.08), "cheek": Color(0.07, 0.07, 0.09),
		"beak": Color(0.05, 0.05, 0.05), "tip": Color(0.04, 0.04, 0.04), "feet": Color(0.06, 0.06, 0.06),
		"arm": 0.2, "hand": 0.21, "chord": 0.14, "point": 0.45, "body": 1.05, "tail": 0.16, "beak_len": 0.05, "malar": false,
	},
}

const VISUAL := 1.5   # 실제보다 크게 보여 줘서 먼 곳의 새도 읽히게 한다

static var _cache: Dictionary = {}
static var _mat: StandardMaterial3D

var spec_id := "falcon"
var s: Dictionary
var shoulder_l: Node3D
var shoulder_r: Node3D
var wrist_l: Node3D
var wrist_r: Node3D
var tail_node: Node3D
var legs: Node3D
var body_node: Node3D

var flap_phase := 0.0
var flap_amp := 0.0
var fold := 0.0
var sweep := 0.0          # 날개 앞/뒤(브레이크 시 음수)
var tail_spread := 0.0
var talons_out := 0.0
var perched := 0.0
var _body_hidden := false


static func resolve(id: String) -> Dictionary:
	var sp: Dictionary = SPECS[id].duplicate()
	if sp.has("base"):
		var base: Dictionary = SPECS[sp["base"]].duplicate()
		for k in sp:
			base[k] = sp[k]
		sp = base
	return sp


func setup(id: String) -> BirdModel:
	spec_id = id
	s = resolve(id)
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.roughness = 0.85
	if not _cache.has(id):
		_cache[id] = _build_meshes()
	var m: Dictionary = _cache[id]
	var sc: float = s["scale"]
	scale = Vector3.ONE * sc * VISUAL
	body_node = Node3D.new()
	add_child(body_node)
	_mi(body_node, m["body"])
	tail_node = Node3D.new()
	tail_node.position = Vector3(0, 0.01, 0.12 * s["body"])
	body_node.add_child(tail_node)
	_mi(tail_node, m["tail"])
	legs = Node3D.new()
	legs.position = Vector3(0, -0.06 * s["body"], 0.02)
	body_node.add_child(legs)
	_mi(legs, m["legs"])
	legs.visible = false
	for side: int in [-1, 1]:
		var sh := Node3D.new()
		sh.position = Vector3(0.045 * side * s["body"], 0.03, -0.04)
		body_node.add_child(sh)
		_mi(sh, m["arm_r"] if side > 0 else m["arm_l"])
		var wr := Node3D.new()
		wr.position = Vector3(s["arm"] * side, 0, 0)
		sh.add_child(wr)
		_mi(wr, m["hand_r"] if side > 0 else m["hand_l"])
		if side < 0:
			shoulder_l = sh
			wrist_l = wr
		else:
			shoulder_r = sh
			wrist_r = wr
	return self


func _mi(parent: Node3D, mesh: Mesh) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.visibility_range_end = 900.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)


## 1인칭일 때 몸통·꼬리·다리를 숨긴다(날개만 보이게)
func set_body_visible(v: bool) -> void:
	_body_hidden = not v
	if body_node == null:
		return
	for c in body_node.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = v
	tail_node.visible = v


## 매 프레임 포즈 적용
func pose(delta: float) -> void:
	if shoulder_l == null:
		return
	var f := fold
	var flap := sin(flap_phase) * flap_amp
	var flap2 := sin(flap_phase - 0.9) * flap_amp
	var sw := sweep
	# 어깨: roll(위아래), yaw(뒤로 젖힘)
	var dihedral := deg_to_rad(6.0) * (1.0 - f)
	var perch_drop := perched * deg_to_rad(-35.0)
	for side: int in [-1, 1]:
		var sh: Node3D = shoulder_r if side > 0 else shoulder_l
		var wr: Node3D = wrist_r if side > 0 else wrist_l
		var roll := (flap * 1.0 + dihedral + f * deg_to_rad(8.0) + perch_drop) * side
		var yaw := -(f * deg_to_rad(62.0) + sw * deg_to_rad(28.0)) * side
		sh.rotation = Vector3(0, yaw, roll)
		var wroll := (flap2 * 0.7 - f * deg_to_rad(4.0)) * side
		var wyaw := -(f * deg_to_rad(118.0) - sw * deg_to_rad(10.0)) * side
		wr.rotation = Vector3(0, wyaw, wroll)
	# 몸통 위아래 반동
	body_node.position.y = -cos(flap_phase) * flap_amp * 0.02
	body_node.rotation.x = perched * deg_to_rad(28.0)
	tail_node.scale = Vector3(1.0 + tail_spread * 0.9, 1, 1.0 - tail_spread * 0.15)
	tail_node.rotation.x = perched * deg_to_rad(15.0) + tail_spread * deg_to_rad(12.0)
	legs.visible = (talons_out > 0.05 or perched > 0.5) and not _body_hidden
	legs.rotation.x = deg_to_rad(70.0) * talons_out * (1.0 - perched)


# ---------- 메시 생성 ----------

func _build_meshes() -> Dictionary:
	var out := {}
	out["body"] = _body_mesh()
	out["tail"] = _tail_mesh()
	out["legs"] = _legs_mesh()
	out["arm_r"] = _wing_part(false, 1)
	out["arm_l"] = _wing_part(false, -1)
	out["hand_r"] = _wing_part(true, 1)
	out["hand_l"] = _wing_part(true, -1)
	return out


func _st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	return st


func _tri2(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	_tri(st, a, b, c, ca, cb, cc)
	_tri(st, a, c, b, ca, cc, cb)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


func _finish(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, _mat)
	return m


func _body_mesh() -> ArrayMesh:
	var st := _st()
	var b: float = s["body"]
	var big_head: bool = s.get("big_head", false)
	var hr := 1.35 if big_head else 1.0
	# (z, 반지름) 앞(-Z)에서 뒤로
	var prof := [
		[-0.225, 0.02 * hr], [-0.2, 0.05 * hr], [-0.165, 0.062 * hr], [-0.13, 0.052 * hr],
		[-0.08, 0.082], [0.0, 0.092], [0.07, 0.074], [0.13, 0.042], [0.17, 0.02],
	]
	var seg := 7
	var rings := []
	for p in prof:
		var ring := []
		var z: float = p[0] * b
		var r: float = p[1] * b
		for k in seg:
			var a := TAU * k / seg + PI * 0.5
			ring.append(Vector3(cos(a) * r, sin(a) * r * 0.95, z))
		rings.append(ring)
	for ri in rings.size() - 1:
		for k in seg:
			var k2 := (k + 1) % seg
			var a: Vector3 = rings[ri][k]
			var bb: Vector3 = rings[ri][k2]
			var c: Vector3 = rings[ri + 1][k]
			var d: Vector3 = rings[ri + 1][k2]
			_tri(st, a, d, bb, _body_col(a, ri), _body_col(d, ri + 1), _body_col(bb, ri))
			_tri(st, a, c, d, _body_col(a, ri), _body_col(c, ri + 1), _body_col(d, ri + 1))
	# 앞/뒤 마개
	var front: Vector3 = Vector3(0, 0, prof[0][0] * b - 0.004)
	var back: Vector3 = Vector3(0, 0, prof[prof.size() - 1][0] * b + 0.01)
	for k in seg:
		var k2 := (k + 1) % seg
		_tri(st, front, rings[0][k], rings[0][k2], s["head"], s["head"], s["head"])
		var lr: Array = rings[rings.size() - 1]
		_tri(st, back, lr[k2], lr[k], s["back"], s["back"], s["back"])
	# 부리
	var bl: float = s["beak_len"] * b
	var bz: float = prof[0][0] * b
	var by := -0.008 * b
	var bw := 0.016 * b
	var tipv := Vector3(0, by - bl * 0.25, bz - bl)
	var bpts := [Vector3(-bw, by + bw, bz + 0.01), Vector3(bw, by + bw, bz + 0.01), Vector3(bw, by - bw, bz + 0.01), Vector3(-bw, by - bw, bz + 0.01)]
	for k in 4:
		_tri(st, bpts[(k + 1) % 4], bpts[k], tipv, s["beak"], s["beak"], s["tip"])
	# 눈
	var ey := 0.018 * b * hr
	var ez := -0.18 * b
	var ex := 0.046 * b * hr
	for side: int in [-1, 1]:
		var cx: float = ex * side
		var e := 0.011 * b * hr
		var eye_col := Color(0.95, 0.55, 0.1) if big_head else Color(0.04, 0.04, 0.05)
		_tri2(st, Vector3(cx, ey + e, ez), Vector3(cx + 0.004 * side, ey, ez - e), Vector3(cx, ey - e, ez), eye_col, eye_col, eye_col)
		_tri2(st, Vector3(cx, ey + e, ez), Vector3(cx, ey - e, ez), Vector3(cx + 0.004 * side, ey, ez + e), eye_col, eye_col, eye_col)
	# 귀깃(부엉이)
	if s.get("tufts", false):
		for side: int in [-1, 1]:
			var base := Vector3(0.035 * side * b * hr, 0.055 * b * hr, -0.17 * b)
			var tip := base + Vector3(0.015 * side, 0.05 * b, 0.02)
			_tri2(st, base + Vector3(-0.012, 0, 0), tip, base + Vector3(0.012, 0, 0.01), s["back"], s["prim"], s["back"])
			_tri2(st, base + Vector3(0.012, 0, 0.01), tip, base + Vector3(-0.012, 0, 0), s["back"], s["prim"], s["back"])
	return _finish(st)


func _body_col(v: Vector3, ring: int) -> Color:
	var up := v.y
	var side := absf(v.x)
	if ring <= 3:
		# 머리
		if s.get("malar", false) and up < 0.02 and up > -0.03 and side > 0.025:
			return s["head"]
		if up < -0.005:
			return s["cheek"]
		return s["head"]
	if up > 0.01:
		return s["back"]
	return s["belly"]


func _tail_mesh() -> ArrayMesh:
	var st := _st()
	var L: float = s["tail"]
	var w0 := 0.028
	var w1 := 0.055
	var top_c: Color = s.get("tail_top", s["back"])
	var tip_c: Color = s.get("tail_tip", s["prim"])
	var bot_c: Color = s.get("tail_under", s["under"])
	var a := Vector3(-w0, 0, 0)
	var b := Vector3(w0, 0, 0)
	var c := Vector3(w1, -0.005, L)
	var d := Vector3(-w1, -0.005, L)
	var mid := Vector3(0, 0, L * 1.04)
	_tri(st, a, b, c, top_c, top_c, tip_c)
	_tri(st, a, c, mid, top_c, tip_c, tip_c)
	_tri(st, a, mid, d, top_c, tip_c, tip_c)
	var o := Vector3(0, -0.004, 0)
	_tri(st, a + o, c + o, b + o, bot_c, bot_c, bot_c)
	_tri(st, a + o, mid + o, c + o, bot_c, bot_c, bot_c)
	_tri(st, a + o, d + o, mid + o, bot_c, bot_c, bot_c)
	return _finish(st)


func _legs_mesh() -> ArrayMesh:
	var st := _st()
	var fc: Color = s["feet"]
	for side: int in [-1, 1]:
		var x := 0.025 * side
		var top := Vector3(x, 0, 0)
		var bot := Vector3(x, -0.06, 0.0)
		var w := 0.008
		_tri2(st, top + Vector3(-w, 0, 0), top + Vector3(w, 0, 0), bot + Vector3(0, 0, -w), fc, fc, fc)
		_tri2(st, top + Vector3(w, 0, 0), top + Vector3(-w, 0, 0), bot + Vector3(0, 0, w), fc, fc, fc)
		# 발가락
		for t: int in [-1, 0, 1]:
			var toe := bot + Vector3(0.012 * t, -0.004, -0.03)
			_tri2(st, bot + Vector3(-0.004, 0, 0), bot + Vector3(0.004, 0, 0), toe, fc, fc, Color(0.1, 0.1, 0.1))
			_tri2(st, bot + Vector3(0.004, 0, 0), bot + Vector3(-0.004, 0, 0), toe + Vector3(0, 0.003, 0), fc, fc, Color(0.1, 0.1, 0.1))
	return _finish(st)


## 날개 한 조각. hand=true면 바깥쪽(첫째날개깃) 부분. side=+1 오른쪽
func _wing_part(hand: bool, side: int) -> ArrayMesh:
	var st := _st()
	var chord: float = s["chord"]
	var pts: Array
	if not hand:
		var L: float = s["arm"]
		pts = [Vector3(0, 0, -0.025), Vector3(L, 0, -0.012), Vector3(L, 0, chord * 0.85), Vector3(0, 0, chord)]
	else:
		var L: float = s["hand"]
		var point: float = s["point"]
		# 뾰족함: 끝이 뒤로 휘는 정도
		var tip := Vector3(L, 0, lerpf(0.02, 0.09, point))
		var aft := Vector3(L * lerpf(0.92, 0.7, point), 0, chord * lerpf(0.7, 0.55, point))
		pts = [Vector3(0, 0, -0.012), Vector3(L * 0.55, 0, -0.01), tip, aft, Vector3(0, 0, chord * 0.85)]
	var top_c: Color = s["prim"] if hand else s["wing"]
	var bot_c: Color = s["under"]
	var mid_c: Color = s["wing"]
	var n := pts.size()
	# 위쪽 면 (팬 삼각분할)
	for i in range(1, n - 1):
		var a: Vector3 = pts[0]
		var b: Vector3 = pts[i]
		var c: Vector3 = pts[i + 1]
		a.x *= side
		b.x *= side
		c.x *= side
		var ca := mid_c if hand else top_c
		if side > 0:
			_tri(st, a, b, c, ca, top_c, top_c)
			_tri(st, a + Vector3(0, -0.003, 0), c + Vector3(0, -0.003, 0), b + Vector3(0, -0.003, 0), bot_c, bot_c, bot_c)
		else:
			_tri(st, a, c, b, ca, top_c, top_c)
			_tri(st, a + Vector3(0, -0.003, 0), b + Vector3(0, -0.003, 0), c + Vector3(0, -0.003, 0), bot_c, bot_c, bot_c)
	return _finish(st)
