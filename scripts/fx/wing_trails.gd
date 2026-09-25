class_name WingTrails
extends Node3D
## 빠르게 날 때 날개 끝에서 흘러나오는 가는 공기 흔적. 속도감을 더한다.

const N := 28
const MAX_LEN := 1.6

var falcon: Falcon
var _mesh := ImmediateMesh.new()
var _mat := StandardMaterial3D.new()
var _hist := [[], []]
var _mi: MeshInstance3D


func _ready() -> void:
	falcon = get_parent() as Falcon
	_mi = MeshInstance3D.new()
	_mi.mesh = _mesh
	_mi.top_level = true
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.extra_cull_margin = 16384.0
	add_child(_mi)
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.vertex_color_use_as_albedo = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.disable_fog = true
	process_priority = 12


func _tip(side: int) -> Vector3:
	var fold := falcon.model.fold if falcon.model else 0.0
	var span := 0.55 * BirdModel.VISUAL * (1.0 - 0.75 * fold)
	return falcon.global_transform * Vector3(span * side, 0.02, 0.05 + 0.3 * fold)


func _process(_delta: float) -> void:
	_mesh.clear_surfaces()
	if falcon == null or falcon.state != Falcon.State.FLYING:
		_hist = [[], []]
		return
	var k := clampf((falcon.speed - 35.0) / 50.0, 0.0, 1.0) * Settings.fx_intensity
	for s in 2:
		var h: Array = _hist[s]
		h.push_front(_tip(-1 if s == 0 else 1))
		if h.size() > N:
			h.pop_back()
	if k <= 0.01:
		return
	var up := falcon.global_basis.y
	for s in 2:
		var h: Array = _hist[s]
		if h.size() < 3:
			continue
		# 길이는 최대 MAX_LEN 미터까지만 (카메라 쪽으로 길게 뻗지 않게)
		var pts := [h[0]]
		var acc := 0.0
		for i in range(1, h.size()):
			acc += (h[i] as Vector3).distance_to(h[i - 1])
			if acc > MAX_LEN:
				break
			pts.append(h[i])
		if pts.size() < 3:
			continue
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
		for i in pts.size():
			var t := float(i) / float(pts.size() - 1)
			var w := 0.012 * (1.0 - t)
			var a := (1.0 - t) * 0.3 * k
			_mesh.surface_set_color(Color(1, 1, 1, a))
			_mesh.surface_add_vertex(pts[i] + up * w)
			_mesh.surface_set_color(Color(1, 1, 1, a))
			_mesh.surface_add_vertex(pts[i] - up * w)
		_mesh.surface_end()
