class_name Nest
extends Node3D
## 절벽 선반 위의 알과 새끼. 배고픈 새끼는 머리를 들고 삐약거린다.

var _eggs: Array = []
var _chicks: Array = []
var _t := 0.0
var _peep_t := 0.0
var _egg_mat: StandardMaterial3D
var _down_mat: StandardMaterial3D
var _dark_mat: StandardMaterial3D
var _player_egg: MeshInstance3D
var _player_chick: Dictionary = {}
var _egg_shake := 0.0


func setup() -> void:
	global_position = WorldShape.eyrie + Vector3(0, -0.02, 0)
	global_basis = Basis.looking_at(-WorldShape.eyrie_facing, Vector3.UP)
	_egg_mat = StandardMaterial3D.new()
	_egg_mat.albedo_color = Color(0.72, 0.42, 0.3)
	_egg_mat.roughness = 0.6
	_down_mat = StandardMaterial3D.new()
	_down_mat.albedo_color = Color(0.95, 0.94, 0.9)
	_down_mat.roughness = 1.0
	_dark_mat = StandardMaterial3D.new()
	_dark_mat.albedo_color = Color(0.08, 0.08, 0.1)
	refresh()


func refresh() -> void:
	for e in _eggs:
		e.queue_free()
	for c in _chicks:
		c.node.queue_free()
	_eggs.clear()
	_chicks.clear()
	var life := GameState.life()
	var n_eggs := int(life.get("eggs", 0))
	var chicks: Array = life.get("chicks", [])
	if chicks.is_empty():
		for i in n_eggs:
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.05
			sm.height = 0.12
			sm.radial_segments = 10
			sm.rings = 6
			mi.mesh = sm
			mi.material_override = _egg_mat
			var a := TAU * i / maxf(n_eggs, 1) + 0.3
			mi.position = Vector3(cos(a) * 0.07, 0.03, sin(a) * 0.07 + 0.3)
			mi.rotation = Vector3(PI * 0.5, a, 0)
			add_child(mi)
			_eggs.append(mi)
	var k := 0
	for c in chicks:
		if not c.get("alive", true):
			continue
		var a := TAU * k / maxf(chicks.size(), 1)
		var g := (0.6 + 0.8 * float(c.get("growth", 0.0))) * 1.8
		var ch := _make_chick(g, Vector3(cos(a) * 0.14, 0.0, sin(a) * 0.14 + 0.3), a + PI)
		ch["data"] = c
		_chicks.append(ch)
		k += 1


## 솜털 새끼 모델 하나 (몸통 + 머리 + 부리)
func _make_chick(g: float, pos: Vector3, rot_y: float) -> Dictionary:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	add_child(root)
	var body := MeshInstance3D.new()
	var sm2 := SphereMesh.new()
	sm2.radius = 0.07 * g
	sm2.height = 0.13 * g
	sm2.radial_segments = 8
	sm2.rings = 5
	body.mesh = sm2
	body.material_override = _down_mat
	body.position.y = 0.06 * g
	root.add_child(body)
	var head := Node3D.new()
	head.position = Vector3(0, 0.14 * g, -0.02)
	root.add_child(head)
	var hm := MeshInstance3D.new()
	var sm3 := SphereMesh.new()
	sm3.radius = 0.045 * g
	sm3.height = 0.09 * g
	sm3.radial_segments = 8
	sm3.rings = 5
	hm.mesh = sm3
	hm.material_override = _down_mat
	head.add_child(hm)
	var beak := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.02, 0.03, 0.02) * g
	beak.mesh = pm
	beak.material_override = _dark_mat
	beak.position = Vector3(0, -0.005, -0.045 * g)
	beak.rotation.x = -PI * 0.5
	head.add_child(beak)
	return {"node": root, "head": head, "data": {}, "phase": randf() * TAU}


# ---------- 프롤로그: 플레이어의 알과 새끼 ----------

func show_player_egg(show: bool) -> void:
	if show and _player_egg == null:
		_player_egg = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.085
		sm.height = 0.24
		sm.radial_segments = 16
		sm.rings = 10
		_player_egg.mesh = sm
		_player_egg.material_override = _egg_mat.duplicate()
		_player_egg.position = Vector3(0, 0.1, 0.3)
		_player_egg.rotation = Vector3(0, 0.9, PI * 0.5)
		add_child(_player_egg)
	if _player_egg:
		_player_egg.visible = show


## 금이 갈수록(0..1) 흔들리고 밝아진다
func crack_egg(k: float) -> void:
	_egg_shake = 1.0
	if _player_egg:
		var m := _player_egg.material_override as StandardMaterial3D
		m.albedo_color = Color(0.8, 0.55, 0.42).lerp(Color(0.97, 0.9, 0.8), k)
		_player_egg.scale = Vector3(1.0 + 0.05 * k, 1.0 - 0.04 * k, 1.0 + 0.05 * k)


func egg_position() -> Vector3:
	return _player_egg.global_position if _player_egg else global_position


func show_player_chick(show: bool) -> void:
	if show and _player_chick.is_empty():
		_player_chick = _make_chick(1.4, Vector3(0, 0.0, 0.3), PI)
	if not _player_chick.is_empty():
		(_player_chick.node as Node3D).visible = show


func _process(delta: float) -> void:
	_t += delta
	if _player_egg and _player_egg.visible:
		_egg_shake = move_toward(_egg_shake, 0.0, delta * 3.0)
		_player_egg.rotation = Vector3(sin(_t * 45.0) * 0.25 * _egg_shake, 0.9, PI * 0.5 + cos(_t * 38.0) * 0.2 * _egg_shake)
	if not _player_chick.is_empty() and (_player_chick.node as Node3D).visible:
		var h: Node3D = _player_chick.head
		h.rotation.x = -0.5 + sin(_t * 7.0) * 0.25
	var any_hungry := false
	for c in _chicks:
		var hunger := 100.0 - float(c.data.get("food", 60.0))
		var beg := clampf((hunger - 40.0) / 50.0, 0.0, 1.0)
		if beg > 0.3:
			any_hungry = true
		var h: Node3D = c.head
		h.rotation.x = -0.6 * beg + sin(_t * (3.0 + 6.0 * beg) + c.phase) * (0.1 + 0.25 * beg)
		(c.node as Node3D).position.y = absf(sin(_t * 5.0 + c.phase)) * 0.01 * beg
	if any_hungry:
		_peep_t -= delta
		if _peep_t <= 0.0:
			_peep_t = randf_range(1.5, 3.5)
			var m = get_tree().get_first_node_in_group("main")
			if m and m.falcon.global_position.distance_to(global_position) < 120.0:
				Sfx.play_at("chick", global_position, 0.0, randf_range(0.95, 1.1), 150.0)
