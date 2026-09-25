class_name RemoteFalcon
extends Node3D
## 다른 플레이어의 매. 받은 위치로 부드럽게 따라가고, 날갯짓·날개 접기를 흉내 낸다.

var pid := 0
var model: BirdModel
var label: Label3D
var spec := ""
var _target_pos := Vector3.ZERO
var _target_rot := Quaternion.IDENTITY
var _vel := Vector3.ZERO
var _flap := 0.0
var _flap_amp := 0.0
var _tuck := 0.0
var _perched := false
var _first := true
var last_seen := 0.0


func setup(p_pid: int) -> RemoteFalcon:
	pid = p_pid
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0012
	label.font_size = 28
	label.outline_size = 8
	label.modulate = Color(0.75, 0.9, 1.0)
	label.position = Vector3(0, 1.2, 0)
	add_child(label)
	return self


func _set_model(p_spec: String) -> void:
	if p_spec == spec and model:
		return
	spec = p_spec
	if model:
		model.queue_free()
	model = BirdModel.new()
	add_child(model)
	model.setup(spec if BirdModel.SPECS.has(spec) else "falcon")


func apply_state(pos: Vector3, rot: Quaternion, vel: Vector3, tuck: float, flap_amp: float, perched: bool, p_name: String, p_spec: String) -> void:
	_set_model(p_spec)
	label.text = p_name
	_target_pos = pos
	_target_rot = rot
	_vel = vel
	_tuck = tuck
	_flap_amp = flap_amp
	_perched = perched
	last_seen = Time.get_ticks_msec() / 1000.0
	if _first:
		_first = false
		global_position = pos
		quaternion = rot


func _process(delta: float) -> void:
	if model == null:
		return
	# 받은 위치를 앞질러 예측하고 부드럽게 따라간다 (소식이 끊기면 예측을 멈춘다)
	if Time.get_ticks_msec() / 1000.0 - last_seen < 0.4:
		_target_pos += _vel * delta
	global_position = global_position.lerp(_target_pos, 1.0 - exp(-10.0 * delta))
	quaternion = quaternion.slerp(_target_rot, 1.0 - exp(-10.0 * delta))
	_flap += delta * (11.0 if _flap_amp > 0.3 else 1.5)
	model.flap_phase = _flap
	model.flap_amp = lerpf(model.flap_amp, _flap_amp, 1.0 - exp(-8.0 * delta))
	model.fold = lerpf(model.fold, _tuck, 1.0 - exp(-10.0 * delta))
	model.perched = move_toward(model.perched, 1.0 if _perched else 0.0, delta * 3.0)
	model.pose(delta)
