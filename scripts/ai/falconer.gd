class_name Falconer
extends Node3D
## 매사냥꾼(응사): 들판에서 미끼(깃털 뭉치)를 줄에 매달아 빙빙 돌린다.
## 매가 미끼를 낚아채면 발에 '시치미'(주인 표시 이름표)를 달아 준다.

const LURE_R := 4.5
const LURE_H := 2.6

var model: Node3D
var arm: Node3D
var lure: MeshInstance3D
var line: MeshInstance3D
var caught := false
var _a := 0.0
var _whistle := 1.0


func setup(pos: Vector3) -> Falconer:
	position = pos
	model = CritterModel.human()
	model.scale = Vector3.ONE * 1.2
	add_child(model)
	arm = model.get_node("arm")
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.85, 0.82, 0.75)
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.45
	sm.material = lm
	lure = MeshInstance3D.new()
	lure.mesh = sm
	add_child(lure)
	# 날개깃 두 장
	for side: int in [-1, 1]:
		var w := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.5, 0.05, 0.25)
		pm.material = lm
		w.mesh = pm
		w.position = Vector3(0.3 * side, 0.05, 0)
		lure.add_child(w)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.015
	cm.bottom_radius = 0.015
	cm.height = 1.0
	var km := StandardMaterial3D.new()
	km.albedo_color = Color(0.2, 0.18, 0.15)
	cm.material = km
	line = MeshInstance3D.new()
	line.mesh = cm
	add_child(line)
	return self


func lure_pos() -> Vector3:
	return lure.global_position


func _process(delta: float) -> void:
	_whistle -= delta
	if caught:
		lure.visible = false
		line.visible = false
		arm.rotation.z = lerpf(arm.rotation.z, 0.0, 1.0 - exp(-3.0 * delta))
		return
	_a += delta * 2.4
	var hand := Vector3(0.36, 2.2, 0.0) * 1.2
	var lp := Vector3(cos(_a) * LURE_R, LURE_H + sin(_a * 2.0) * 0.4, sin(_a) * LURE_R)
	lure.position = lp
	lure.rotation.y = -_a
	var mid := (hand + lp) * 0.5
	line.position = mid
	var d := lp - hand
	line.scale = Vector3(1, d.length(), 1)
	line.basis = Basis(Quaternion(Vector3.UP, d.normalized())).scaled(Vector3(1, d.length(), 1))
	arm.rotation = Vector3(0, -_a, -1.2)
	if _whistle <= 0.0:
		_whistle = randf_range(3.0, 5.0)
		Sfx.play_at("chick", global_position + Vector3.UP * 2.0, 2.0, 0.55, 500.0)
