class_name ChaseCamera
extends Camera3D
## 추적 카메라. 속도에 따라 시야각·흔들림·거리가 바뀌고, 타격 순간 펀치/킬캠 연출을 한다.
## 흔들림은 실시간 기준이라 히트스톱(시간 정지) 중에도 화면이 떨린다.

enum Mode { FOLLOW, ORBIT, KILLCAM, CINEMATIC }

var target: Falcon
var mode := Mode.CINEMATIC: set = _set_mode
var first_person := false
var trauma := 0.0
# 모드가 바뀔 때 이전 화면에서 새 화면으로 부드럽게 넘어간다
var _blend_from := Transform3D.IDENTITY
var _blend_fov := 70.0
var _blend_t := 1.0
var _blend_dur := 0.8
var fov_punch := 0.0
var base_fov := 72.0
var _offset := Vector3(0, 1.2, 4.0)
var _look := Vector3.FORWARD
var _noise := FastNoiseLite.new()
var _t := 0.0
var _last_us := 0
var orbit_yaw := 0.0
var orbit_pitch := -0.25
var orbit_dist := 3.4
var _kill_center := Vector3.ZERO
var _kill_t := 0.0
var _kill_dir := Vector3.RIGHT
var cine_center := Vector3.ZERO
var cine_radius := 160.0
var cine_height := 80.0
var cine_angle := 0.0
var cine_facing := Vector3.ZERO   # 0이 아니면 이 방향 쪽에서만 호를 그리며 바라본다
var cine_turn := 0.33
var eye_zoom := 0.0
var _roll := 0.0


func _ready() -> void:
	process_priority = 10
	_noise.frequency = 1.0
	_noise.fractal_octaves = 2
	_last_us = Time.get_ticks_usec()
	far = 6000.0
	near = 0.08


func _set_mode(m: Mode) -> void:
	if m == mode:
		return
	var dur := 0.9
	if m == Mode.KILLCAM:
		dur = 0.25
	elif mode == Mode.KILLCAM:
		dur = 0.5
	var old := mode
	mode = m
	if not is_inside_tree():
		return
	begin_blend(dur)
	# 추적 카메라는 지금 카메라 위치에서 출발하게 해서 튀지 않게 한다
	if m == Mode.FOLLOW and target and old != Mode.KILLCAM:
		_offset = global_position - target.global_position
		_look = -global_basis.z
	_apply_body_visibility()


## 지금 화면에서 다음 화면으로 dur초 동안 섞는다
func begin_blend(dur: float) -> void:
	_blend_from = global_transform
	_blend_fov = fov
	_blend_t = 0.0
	_blend_dur = maxf(dur, 0.01)


func toggle_view() -> void:
	first_person = not first_person
	Settings.first_person = first_person
	Settings.save_settings()
	begin_blend(0.45)
	_apply_body_visibility()


## 1인칭으로 날 때는 몸통을 숨기고 날개만 보이게 한다
func _apply_body_visibility() -> void:
	if target and target.model:
		target.model.set_body_visible(not (first_person and mode == Mode.FOLLOW))


func add_trauma(v: float) -> void:
	trauma = clampf(trauma + v, 0.0, 1.0)


func punch(fov_delta: float) -> void:
	fov_punch += fov_delta


func start_killcam(center: Vector3, dir: Vector3) -> void:
	if not Settings.killcam:
		return
	mode = Mode.KILLCAM
	_kill_center = center
	_kill_t = 0.0
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.1:
		side = Vector3.RIGHT
	# 옆에서 수평으로 바라보는 구도: 내리꽂는 궤적이 화면을 가로지른다
	_kill_dir = (side.normalized() + Vector3.UP * 0.08 + dir.normalized() * 0.25).normalized()


func end_killcam() -> void:
	if mode == Mode.KILLCAM:
		mode = Mode.FOLLOW


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.ORBIT and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		orbit_yaw -= event.relative.x * 0.004 * Settings.mouse_sens
		orbit_pitch = clampf(orbit_pitch - event.relative.y * 0.004 * Settings.mouse_sens, -1.2, 0.5)


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_dt := clampf((now - _last_us) / 1000000.0, 0.0, 0.1)
	_last_us = now
	_t += real_dt
	match mode:
		Mode.FOLLOW:
			if first_person:
				_first_person(real_dt)
			else:
				_follow(delta, real_dt)
		Mode.ORBIT:
			_orbit(real_dt)
		Mode.KILLCAM:
			_killcam(real_dt)
		Mode.CINEMATIC:
			_cinematic(real_dt)
	if _blend_t < 1.0:
		_blend_t = minf(_blend_t + real_dt / _blend_dur, 1.0)
		var k := smoothstep(0.0, 1.0, _blend_t)
		var goal := global_transform
		global_transform = Transform3D(_blend_from.basis.slerp(goal.basis.orthonormalized(), k), _blend_from.origin.lerp(goal.origin, k))
		fov = lerpf(_blend_fov, fov, k)
	_apply_shake(real_dt)
	trauma = maxf(trauma - real_dt * 1.1, 0.0)
	fov_punch = lerpf(fov_punch, 0.0, 1.0 - exp(-7.0 * real_dt))


func _follow(delta: float, real_dt: float) -> void:
	if target == null:
		return
	var sp := clampf(target.speed / 110.0, 0.0, 1.0)
	var aim := target.aim_dir()
	var vel_dir := target.dir
	var look := aim.lerp(vel_dir, 0.3).normalized()
	_look = _look.slerp(look, 1.0 - exp(-6.5 * real_dt)).normalized()
	var up := Vector3.UP
	if absf(_look.dot(up)) > 0.97:
		up = (target.aim_dir() * -1.0 + Vector3.BACK * 0.01).normalized()
	var right := _look.cross(up).normalized()
	var cam_up := right.cross(_look).normalized()
	# 가속할 때 카메라가 살짝 뒤처진다
	var lag := clampf(target.accel_smooth * 0.035, -0.6, 1.3)
	var dist := lerpf(3.3, 2.6, sp) + lag + (0.6 if target.carrying else 0.0)
	var height := lerpf(0.75, 0.45, sp)
	var want := -_look * dist + cam_up * height
	_offset = _offset.lerp(want, 1.0 - exp(-7.0 * real_dt))
	# 지면/절벽 속으로 들어가지 않게
	var pos := _clip(target.global_position, target.global_position + _offset)
	var fy := WorldShape.floor_y(pos.x, pos.z) + 0.6
	if pos.y < fy:
		pos.y = fy
	global_position = pos
	var look_at_p := target.global_position + _look * 25.0
	look_at(look_at_p, cam_up)
	_roll = lerpf(_roll, -target.bank * 0.22, 1.0 - exp(-5.0 * real_dt))
	rotate_object_local(Vector3.FORWARD, _roll)
	var fx := Settings.fx_intensity
	var want_fov := base_fov + 38.0 * pow(sp, 1.25) * fx + fov_punch
	want_fov = lerpf(want_fov, 34.0, eye_zoom)
	fov = lerpf(fov, clampf(want_fov, 25.0, 125.0), 1.0 - exp(-5.0 * real_dt))
	# 속도 떨림
	if sp > 0.45:
		trauma = maxf(trauma, (sp - 0.45) * 0.55 * Settings.shake)


## 1인칭: 매의 머리 위에서 바라보는 쪽을 본다. 날개는 화면 양옆에 보인다.
func _first_person(real_dt: float) -> void:
	if target == null:
		return
	var sp := clampf(target.speed / 110.0, 0.0, 1.0)
	var look := target.aim_dir().lerp(target.dir, 0.4).normalized()
	_look = _look.slerp(look, 1.0 - exp(-9.0 * real_dt)).normalized()
	var head := target.global_transform * (Vector3(0, 0.09, -0.24) * BirdModel.VISUAL / 1.5)
	var fy := WorldShape.floor_y(head.x, head.z) + 0.3
	head.y = maxf(head.y, fy)
	global_position = head
	var up := Vector3.UP.slerp(target.global_basis.y, 0.5).normalized()
	if absf(_look.dot(up)) > 0.97:
		up = target.global_basis.y
	look_at(head + _look * 10.0, up)
	var fx := Settings.fx_intensity
	var want_fov := base_fov + 8.0 + 30.0 * pow(sp, 1.25) * fx + fov_punch
	want_fov = lerpf(want_fov, 34.0, eye_zoom)
	fov = lerpf(fov, clampf(want_fov, 25.0, 125.0), 1.0 - exp(-5.0 * real_dt))
	if sp > 0.45:
		trauma = maxf(trauma, (sp - 0.45) * 0.3 * Settings.shake)


func _orbit(real_dt: float) -> void:
	if target == null:
		return
	var b := Basis(Vector3.UP, orbit_yaw) * Basis(Vector3.RIGHT, orbit_pitch)
	var pivot := target.global_position + Vector3.UP * 0.3
	var pos := _clip(pivot, target.global_position + b * Vector3(0, 0.3, orbit_dist))
	global_position = global_position.lerp(pos, 1.0 - exp(-8.0 * real_dt))
	look_at(target.global_position + Vector3.UP * 0.25, Vector3.UP)
	fov = lerpf(fov, 60.0, 1.0 - exp(-4.0 * real_dt))


## from→to 사이에서 지형에 막히기 직전 지점
func _clip(from: Vector3, to: Vector3) -> Vector3:
	for i in range(1, 11):
		var t := float(i) / 10.0
		var p := from.lerp(to, t)
		if p.y < WorldShape.floor_y(p.x, p.z) + 0.4 or WorldShape.hits_obstacle(p, 0.3):
			return from.lerp(to, maxf(float(i - 1) / 10.0, 0.18))
	return to


## 앉은 새를 바다 쪽이 보이게 비스듬히 뒤에서 본다
func orbit_behind(facing: Vector3) -> void:
	var f := Vector3(facing.x, 0, facing.z).normalized()
	if f.length() < 0.1:
		f = Vector3.RIGHT
	var side := f.cross(Vector3.UP)
	var fwd := (f + side * 0.7).normalized()
	orbit_yaw = atan2(-fwd.x, -fwd.z)
	orbit_pitch = -0.35


func _killcam(real_dt: float) -> void:
	_kill_t += real_dt
	if target:
		_kill_center = _kill_center.lerp(target.global_position, 1.0 - exp(-4.0 * real_dt))
	var ang := _kill_t * 0.6
	var d := _kill_dir.rotated(Vector3.UP, ang)
	var pos := _kill_center + d * 4.2
	pos.y = maxf(pos.y, WorldShape.floor_y(pos.x, pos.z) + 0.5)
	global_position = pos
	look_at(_kill_center, Vector3.UP)
	fov = lerpf(fov, 48.0, 1.0 - exp(-10.0 * real_dt))


func _cinematic(real_dt: float) -> void:
	cine_angle += real_dt * 0.04
	if cine_facing != Vector3.ZERO:
		var side := cine_facing.cross(Vector3.UP).normalized()
		var sway := sin(cine_angle * 2.0)
		var p := cine_center - side * (4.2 + sway * 0.5) + cine_facing * (2.2 + sway * 0.4) + Vector3.UP * (0.9 + sin(cine_angle * 1.3) * 0.2)
		global_position = p
		# 매가 화면 오른쪽(메뉴 반대편)에 오도록 시선을 살짝 왼쪽으로 돌린다
		var d := (cine_center + Vector3.UP * 0.4 - p).normalized()
		look_at(p + d.rotated(Vector3.UP, cine_turn) * 10.0, Vector3.UP)
		fov = 50.0
		return
	var pos := cine_center + Vector3(cos(cine_angle) * cine_radius, cine_height, sin(cine_angle) * cine_radius)
	pos.y = maxf(pos.y, WorldShape.floor_y(pos.x, pos.z) + 20.0)
	global_position = pos
	look_at(cine_center + Vector3(0, 20, 0), Vector3.UP)
	fov = 60.0


func _apply_shake(real_dt: float) -> void:
	var s := trauma * trauma * Settings.shake
	if s <= 0.0001:
		return
	var k := _t * 28.0
	var yaw := _noise.get_noise_2d(k, 0.0) * 0.045 * s
	var pitch := _noise.get_noise_2d(0.0, k) * 0.045 * s
	var roll := _noise.get_noise_2d(k, k) * 0.06 * s
	rotate_object_local(Vector3.UP, yaw)
	rotate_object_local(Vector3.RIGHT, pitch)
	rotate_object_local(Vector3.FORWARD, roll)
	global_position += global_transform.basis * Vector3(_noise.get_noise_2d(k, 7.0), _noise.get_noise_2d(7.0, k), 0) * 0.12 * s
