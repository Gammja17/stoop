class_name CritterModel
extends RefCounted
## 새가 아닌 동물(여우·물범·돌고래·고래)의 저폴리 모델을 기본 도형으로 조립한다.
## 앞쪽이 -Z. 움직이는 부위는 이름으로 찾는다 (legs, tail, head, fluke).

const VISUAL := 1.3   # 새처럼 멀리서도 읽히게 조금 크게

static var _mats := {}


static func mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		_mats[key] = m
	return _mats[key]


static func _part(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, sc: Vector3, rot := Vector3.ZERO, nm := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(c)
	mi.position = pos
	mi.scale = sc
	mi.rotation = rot
	mi.visibility_range_end = 700.0
	if nm != "":
		mi.name = nm
	parent.add_child(mi)
	return mi


static func _sphere() -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 10
	s.rings = 6
	return s


static func _cone() -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = 0.5
	c.height = 1.0
	c.radial_segments = 6
	c.rings = 1
	return c


static func _box() -> BoxMesh:
	return BoxMesh.new()


static func _pivot(parent: Node3D, pos: Vector3, nm: String) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = pos
	parent.add_child(n)
	return n


## 여우: 몸 길이 약 1 m (표시 1.3배)
static func fox() -> Node3D:
	var root := Node3D.new()
	root.scale = Vector3.ONE * VISUAL
	var red := Color(0.78, 0.38, 0.13)
	var white := Color(0.93, 0.9, 0.84)
	var dark := Color(0.12, 0.09, 0.08)
	var sph := _sphere()
	var cone := _cone()
	var box := _box()
	var body := _pivot(root, Vector3(0, 0.38, 0), "body")
	_part(body, sph, red, Vector3.ZERO, Vector3(0.28, 0.26, 0.62))
	_part(body, sph, white, Vector3(0, -0.06, -0.2), Vector3(0.2, 0.18, 0.3))
	var head := _pivot(body, Vector3(0, 0.12, -0.34), "head")
	_part(head, sph, red, Vector3.ZERO, Vector3(0.2, 0.18, 0.2))
	_part(head, cone, red, Vector3(0, -0.02, -0.14), Vector3(0.11, 0.2, 0.1), Vector3(-PI * 0.5, 0, 0))
	_part(head, sph, dark, Vector3(0, -0.02, -0.24), Vector3(0.04, 0.04, 0.04))
	_part(head, sph, white, Vector3(0, -0.06, -0.08), Vector3(0.14, 0.08, 0.12))
	for side: int in [-1, 1]:
		_part(head, cone, dark, Vector3(0.06 * side, 0.12, 0.02), Vector3(0.07, 0.12, 0.04))
	var legs := _pivot(root, Vector3.ZERO, "legs")
	var k := 0
	for z: float in [-0.2, 0.2]:
		for side: int in [-1, 1]:
			var hip := _pivot(legs, Vector3(0.09 * side, 0.34, z), "leg%d" % k)
			_part(hip, box, dark, Vector3(0, -0.17, 0), Vector3(0.05, 0.34, 0.05))
			k += 1
	var tail := _pivot(body, Vector3(0, 0.04, 0.3), "tail")
	_part(tail, sph, red, Vector3(0, -0.04, 0.22), Vector3(0.13, 0.13, 0.46), Vector3(0.35, 0, 0))
	_part(tail, sph, white, Vector3(0, -0.12, 0.44), Vector3(0.09, 0.09, 0.12))
	return root


## 물범: 몸 길이 약 1.6 m
static func seal() -> Node3D:
	var root := Node3D.new()
	root.scale = Vector3.ONE * VISUAL
	var grey := Color(0.46, 0.45, 0.42)
	var belly := Color(0.66, 0.64, 0.58)
	var dark := Color(0.1, 0.1, 0.1)
	var sph := _sphere()
	var body := _pivot(root, Vector3(0, 0.22, 0), "body")
	_part(body, sph, grey, Vector3.ZERO, Vector3(0.52, 0.42, 1.5))
	_part(body, sph, belly, Vector3(0, -0.08, -0.1), Vector3(0.44, 0.3, 1.1))
	var head := _pivot(body, Vector3(0, 0.08, -0.72), "head")
	_part(head, sph, grey, Vector3.ZERO, Vector3(0.34, 0.3, 0.36))
	_part(head, sph, grey, Vector3(0, -0.03, -0.17), Vector3(0.2, 0.16, 0.16))
	for side: int in [-1, 1]:
		_part(head, sph, dark, Vector3(0.1 * side, 0.06, -0.14), Vector3(0.06, 0.06, 0.04))
		_part(body, sph, grey, Vector3(0.24 * side, -0.14, -0.3), Vector3(0.1, 0.05, 0.26), Vector3(0, 0.5 * side, 0))
	var tail := _pivot(body, Vector3(0, -0.04, 0.72), "tail")
	for side: int in [-1, 1]:
		_part(tail, sph, grey, Vector3(0.08 * side, 0, 0.14), Vector3(0.12, 0.05, 0.3), Vector3(0, 0.3 * side, 0))
	return root


## 돌고래: 몸 길이 약 2.5 m
static func dolphin() -> Node3D:
	var root := Node3D.new()
	root.scale = Vector3.ONE * VISUAL
	var grey := Color(0.36, 0.41, 0.47)
	var belly := Color(0.78, 0.8, 0.82)
	var sph := _sphere()
	var body := _pivot(root, Vector3.ZERO, "body")
	_part(body, sph, grey, Vector3.ZERO, Vector3(0.5, 0.52, 2.3))
	_part(body, sph, belly, Vector3(0, -0.12, -0.2), Vector3(0.4, 0.3, 1.8))
	_part(body, _cone(), grey, Vector3(0, -0.04, -1.3), Vector3(0.16, 0.4, 0.14), Vector3(-PI * 0.5, 0, 0))
	var fin := PrismMesh.new()
	fin.left_to_right = 1.0
	_part(body, fin, grey, Vector3(0, 0.36, 0.1), Vector3(0.04, 0.34, 0.36))
	var tail := _pivot(body, Vector3(0, 0, 1.1), "tail")
	_part(tail, sph, grey, Vector3(0, 0, 0.2), Vector3(0.9, 0.06, 0.3))
	return root


## 고래(등과 꼬리만 물 위로 보인다): 길이 약 14 m
static func whale() -> Node3D:
	var root := Node3D.new()
	var dark := Color(0.27, 0.29, 0.32)
	var sph := _sphere()
	var body := _pivot(root, Vector3.ZERO, "body")
	_part(body, sph, dark, Vector3.ZERO, Vector3(3.6, 2.6, 14.0))
	var fin := PrismMesh.new()
	fin.left_to_right = 1.0
	_part(body, fin, dark, Vector3(0, 1.2, 3.0), Vector3(0.3, 0.9, 1.4))
	var fluke := _pivot(root, Vector3(0, 0, 7.0), "fluke")
	for side: int in [-1, 1]:
		_part(fluke, sph, dark, Vector3(1.4 * side, 0, 0.6), Vector3(3.0, 0.3, 1.4), Vector3(0, 0.35 * side, 0))
	return root


## 매사냥꾼(응사): 갓을 쓰고 한쪽 팔에 가죽 장갑. 오른팔로 미끼 줄을 돌린다
static func human() -> Node3D:
	var root := Node3D.new()
	var coat := Color(0.36, 0.28, 0.2)
	var skin := Color(0.85, 0.68, 0.52)
	var black := Color(0.08, 0.07, 0.07)
	var glove := Color(0.55, 0.38, 0.2)
	var sph := _sphere()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 1.0
	cyl.radial_segments = 10
	for side: int in [-1, 1]:
		_part(root, cyl, black, Vector3(0.13 * side, 0.45, 0), Vector3(0.16, 0.9, 0.16))
	_part(root, cyl, coat, Vector3(0, 1.25, 0), Vector3(0.52, 0.85, 0.34))
	_part(root, cyl, Color(0.92, 0.9, 0.84), Vector3(0, 1.62, 0), Vector3(0.42, 0.1, 0.3))
	_part(root, sph, skin, Vector3(0, 1.85, 0), Vector3(0.26, 0.3, 0.26))
	# 갓: 넓은 챙 + 높은 모자
	_part(root, cyl, black, Vector3(0, 2.0, 0), Vector3(0.8, 0.02, 0.8))
	_part(root, cyl, black, Vector3(0, 2.12, 0), Vector3(0.24, 0.22, 0.24))
	# 왼팔: 매를 받는 장갑
	_part(root, cyl, coat, Vector3(-0.34, 1.35, -0.12), Vector3(0.12, 0.5, 0.12), Vector3(-0.9, 0, 0.2))
	_part(root, sph, glove, Vector3(-0.38, 1.5, -0.38), Vector3(0.16, 0.16, 0.2))
	# 오른팔: 미끼 줄을 돌리는 팔 (회전 축)
	var arm := _pivot(root, Vector3(0.3, 1.55, 0), "arm")
	_part(arm, cyl, coat, Vector3(0.0, 0.3, 0), Vector3(0.12, 0.6, 0.12))
	return root


## 번식지에 앉은 바닷새 한 마리 (멀티메시용)
static func sitting_bird_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sph := _sphere()
	var arr := sph.get_mesh_arrays()
	var white := Color(0.95, 0.95, 0.93)
	var grey := Color(0.62, 0.66, 0.7)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	# 몸통 (등은 회색) + 머리
	for part: Array in [[Vector3(0, 0.18, 0), Vector3(0.3, 0.26, 0.46)], [Vector3(0, 0.36, -0.14), Vector3(0.16, 0.16, 0.18)]]:
		for i in idx:
			var v: Vector3 = verts[i] * part[1] + part[0]
			st.set_color(grey if (norms[i].y > 0.35 and part[0].y < 0.3) else white)
			st.set_normal(norms[i])
			st.add_vertex(v)
	var m := st.commit()
	var mt := StandardMaterial3D.new()
	mt.vertex_color_use_as_albedo = true
	mt.roughness = 0.9
	m.surface_set_material(0, mt)
	return m
