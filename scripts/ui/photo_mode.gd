class_name PhotoMode
extends Control
## 포토 모드 (O): 시간을 멈추고 자유 카메라로 찍는다.
## 마우스 둘러보기 · WASD 이동 · Q/E 아래/위 · Shift 빠르게 · 휠 화각 · H 안내 숨기기 · F12 촬영 · O/Esc 나가기

var main
var active := false
var _yaw := 0.0
var _pitch := 0.0
var _fov := 70.0
var _saved_mode := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func toggle() -> void:
	if active:
		exit()
	else:
		enter()


func enter() -> void:
	if active or main.menus.any_open():
		return
	active = true
	visible = true
	$Hint.visible = true
	$Hint.text = Loc.t("photo_hint")
	var cam: ChaseCamera = main.camera
	_saved_mode = cam.mode
	cam.photo = true
	var fwd := -cam.global_basis.z
	_yaw = atan2(-fwd.x, -fwd.z)
	_pitch = asin(clampf(fwd.y, -1.0, 1.0))
	_fov = cam.fov
	get_tree().paused = true
	main.get_node("UILayer").visible = false
	main.get_node("ScreenLayer").visible = false
	if not Settings.touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.play("ui_open", -6.0)


func exit() -> void:
	if not active:
		return
	active = false
	visible = false
	main.camera.photo = false
	main.camera.begin_blend(0.4)
	get_tree().paused = false
	main.get_node("UILayer").visible = true
	main.get_node("ScreenLayer").visible = true
	Sfx.play("ui_close", -6.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("photo") or (active and event.is_action_pressed("pause")):
		if active or (main.playing and not main.prologue.active):
			get_viewport().set_input_as_handled()
			toggle()
		return
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.003 * Settings.mouse_sens
		_pitch = clampf(_pitch - event.relative.y * 0.003 * Settings.mouse_sens, -1.5, 1.5)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_fov = clampf(_fov - 4.0, 15.0, 110.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_fov = clampf(_fov + 4.0, 15.0, 110.0)
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		$Hint.visible = not $Hint.visible


func _process(delta: float) -> void:
	if not active:
		return
	var cam: ChaseCamera = main.camera
	# 패드·터치 스틱으로도 둘러본다
	var look := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if look.length() > 0.2:
		_yaw -= look.x * 1.8 * delta
		_pitch = clampf(_pitch - look.y * 1.2 * delta, -1.5, 1.5)
	var b := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)
	var mv := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		mv.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		mv.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		mv.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		mv.x += 1.0
	if Input.is_physical_key_pressed(KEY_E):
		mv.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q):
		mv.y -= 1.0
	var st := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)) + Falcon.touch_stick
	if st.length() > 0.2:
		mv += Vector3(st.x, 0, st.y)
	var spd := 40.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 10.0
	var p := cam.global_position + b * mv * spd * delta
	p.y = maxf(p.y, WorldShape.floor_y(p.x, p.z) + 0.4)
	cam.global_transform = Transform3D(b, p)
	cam.fov = lerpf(cam.fov, _fov, 1.0 - exp(-10.0 * delta))
