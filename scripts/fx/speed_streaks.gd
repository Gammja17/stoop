class_name SpeedStreaks
extends MultiMeshInstance3D
## 카메라 주변 공기 중의 가느다란 줄. 속도가 빠를수록 길어지고 짙어져 속도감을 만든다.
## 월드에 고정된 점들을 카메라 기준으로 순환시키므로 실제로 스쳐 지나가는 느낌이 난다.

const N := 280
const BOX := 60.0

var cam: Camera3D
var falcon: Falcon
var _offsets := PackedVector3Array()
var _mat: StandardMaterial3D


func _ready() -> void:
	process_priority = 11
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in N:
		_offsets.append(Vector3(rng.randf_range(0, BOX), rng.randf_range(0, BOX), rng.randf_range(0, BOX)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 두 장의 교차 사각형, 길이 방향 -Z, 끝으로 갈수록 투명
	for q in 2:
		var ax := Vector3.RIGHT if q == 0 else Vector3.UP
		var c0 := Color(1, 1, 1, 0.0)
		var c1 := Color(1, 1, 1, 1.0)
		var a := -ax * 0.5
		var b := ax * 0.5
		var f := Vector3(0, 0, -1)
		st.set_color(c1); st.add_vertex(a)
		st.set_color(c1); st.add_vertex(b)
		st.set_color(c0); st.add_vertex(b + f)
		st.set_color(c1); st.add_vertex(a)
		st.set_color(c0); st.add_vertex(b + f)
		st.set_color(c0); st.add_vertex(a + f)
	var mesh := st.commit()
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.vertex_color_use_as_albedo = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.no_depth_test = false
	_mat.disable_fog = true
	_mat.albedo_color = Color(1, 1, 1, 0.0)
	mesh.surface_set_material(0, _mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = N
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))


func _process(_delta: float) -> void:
	if cam == null or falcon == null:
		return
	var sp := clampf((falcon.speed - 24.0) / 70.0, 0.0, 1.0)
	var alpha := sp * 0.28 * Settings.fx_intensity
	visible = alpha > 0.005 and falcon.state == Falcon.State.FLYING
	if not visible:
		return
	_mat.albedo_color = Color(1, 1, 1, alpha)
	var v := falcon.velocity
	var vl := v.length()
	if vl < 1.0:
		return
	var d := v / vl
	var length := clampf(vl * 0.045, 0.3, 4.5)
	var up := Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT
	var x := d.cross(up).normalized()
	var y := x.cross(d).normalized()
	var w := 0.022 + sp * 0.02
	var b := Basis(x * w, y * w, -d * length)
	var cp := cam.global_position
	var half := BOX * 0.5
	for i in N:
		var rel := _offsets[i] - cp
		rel.x = fposmod(rel.x + half, BOX) - half
		rel.y = fposmod(rel.y + half, BOX) - half
		rel.z = fposmod(rel.z + half, BOX) - half
		if rel.length_squared() < 12.0:
			rel += d * 10.0
		multimesh.set_instance_transform(i, Transform3D(b, cp + rel))
