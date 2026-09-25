extends Node
## 사용자 설정(감도, 볼륨, 화면 효과 등)과 입력 맵을 관리한다.

signal changed

const PATH := "user://settings.cfg"

var mouse_sens := 1.0
var invert_y := false
var vol_master := 0.9
var vol_music := 0.6
var vol_sfx := 0.9
var vol_amb := 0.8
var fullscreen := false
var vsync := true
var fx_intensity := 1.0      # 속도감 화면 효과 강도 (멀미 대비)
var shake := 1.0             # 카메라 흔들림 강도
var killcam := true          # 명중 연출 카메라
var hints := true            # 튜토리얼 힌트
var day_minutes := 8.0       # 낮 길이(실시간 분)
var quality := 2             # 0 낮음, 1 보통, 2 높음
var first_person := false    # 비행 시점 (V로 전환)
var show_fps := false         # F3
var touch_mode := false       # 터치 조작 중 (마우스를 잡지 않는다)
var lang := "ko"

# 각 항목: [종류, 코드]  k=키보드, m=마우스 버튼, j=패드 버튼, a=패드 축(트리거)
const ACTIONS := {
	"flap": [["k", KEY_W], ["m", MOUSE_BUTTON_RIGHT], ["j", JOY_BUTTON_A]],
	"tuck": [["k", KEY_SPACE], ["m", MOUSE_BUTTON_LEFT], ["a", JOY_AXIS_TRIGGER_RIGHT]],
	"brake": [["k", KEY_S], ["j", JOY_BUTTON_LEFT_SHOULDER]],
	"roll_left": [["k", KEY_A], ["j", JOY_BUTTON_DPAD_LEFT]],
	"roll_right": [["k", KEY_D], ["j", JOY_BUTTON_DPAD_RIGHT]],
	"interact": [["k", KEY_E], ["j", JOY_BUTTON_B]],
	"eat": [["k", KEY_Q], ["j", JOY_BUTTON_X]],
	"drop": [["k", KEY_F], ["j", JOY_BUTTON_Y]],
	"call": [["k", KEY_R], ["j", JOY_BUTTON_RIGHT_SHOULDER]],
	"falcon_eye": [["k", KEY_C], ["k", KEY_SHIFT], ["a", JOY_AXIS_TRIGGER_LEFT]],
	"map": [["k", KEY_M], ["k", KEY_TAB], ["j", JOY_BUTTON_BACK]],
	"view": [["k", KEY_V], ["j", JOY_BUTTON_RIGHT_STICK]],
	"growth": [["k", KEY_P], ["j", JOY_BUTTON_DPAD_UP]],
	"pause": [["k", KEY_ESCAPE], ["j", JOY_BUTTON_START]],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_setup_input()
	load_settings()
	apply()


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _setup_input() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for entry in ACTIONS[action]:
			var ev: InputEvent
			match entry[0]:
				"k":
					var k := InputEventKey.new()
					k.physical_keycode = entry[1]
					ev = k
				"m":
					var mb := InputEventMouseButton.new()
					mb.button_index = entry[1]
					ev = mb
				"j":
					var jb := InputEventJoypadButton.new()
					jb.button_index = entry[1]
					ev = jb
				"a":
					var jm := InputEventJoypadMotion.new()
					jm.axis = entry[1]
					jm.axis_value = 1.0
					ev = jm
			InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_F3:
			show_fps = not show_fps
		KEY_F11:
			fullscreen = not fullscreen
			apply()
			save_settings()
		KEY_F12:
			var dir := "user://screenshots"
			DirAccess.make_dir_recursive_absolute(dir)
			var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
			var path := "%s/stoop_%s.png" % [dir, stamp]
			get_viewport().get_texture().get_image().save_png(path)
			GameState.say(Loc.t("screenshot_saved") % ProjectSettings.globalize_path(path), "good")


func load_settings() -> void:
	var cf := ConfigFile.new()
	if OS.has_feature("web"):
		quality = 1   # 웹은 보통이 기본 (브라우저는 느리다)
	if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile"):
		quality = 0   # 폰은 낮음
	if cf.load(PATH) != OK:
		return
	mouse_sens = cf.get_value("input", "mouse_sens", mouse_sens)
	invert_y = cf.get_value("input", "invert_y", invert_y)
	vol_master = cf.get_value("audio", "master", vol_master)
	vol_music = cf.get_value("audio", "music", vol_music)
	vol_sfx = cf.get_value("audio", "sfx", vol_sfx)
	vol_amb = cf.get_value("audio", "amb", vol_amb)
	fullscreen = cf.get_value("video", "fullscreen", fullscreen)
	vsync = cf.get_value("video", "vsync", vsync)
	fx_intensity = cf.get_value("video", "fx_intensity", fx_intensity)
	shake = cf.get_value("video", "shake", shake)
	killcam = cf.get_value("video", "killcam", killcam)
	hints = cf.get_value("game", "hints", hints)
	day_minutes = cf.get_value("game", "day_minutes", day_minutes)
	quality = cf.get_value("video", "quality", quality)
	# 최적화 이전에 저장된 웹 설정은 한 번 보통으로 낮춘다
	if OS.has_feature("web") and int(cf.get_value("video", "perf_rev", 0)) < 1:
		quality = mini(quality, 1)
	first_person = cf.get_value("video", "first_person", first_person)
	lang = cf.get_value("game", "lang", lang)


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("video", "perf_rev", 1)
	cf.set_value("input", "mouse_sens", mouse_sens)
	cf.set_value("input", "invert_y", invert_y)
	cf.set_value("audio", "master", vol_master)
	cf.set_value("audio", "music", vol_music)
	cf.set_value("audio", "sfx", vol_sfx)
	cf.set_value("audio", "amb", vol_amb)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.set_value("video", "vsync", vsync)
	cf.set_value("video", "fx_intensity", fx_intensity)
	cf.set_value("video", "shake", shake)
	cf.set_value("video", "killcam", killcam)
	cf.set_value("game", "hints", hints)
	cf.set_value("game", "day_minutes", day_minutes)
	cf.set_value("video", "quality", quality)
	cf.set_value("video", "first_person", first_person)
	cf.set_value("game", "lang", lang)
	cf.save(PATH)


func apply() -> void:
	_set_bus("Master", vol_master)
	_set_bus("Music", vol_music)
	_set_bus("SFX", vol_sfx)
	_set_bus("Ambience", vol_amb)
	if not Engine.is_editor_hint() and DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		_apply_quality()
	Loc.lang = lang
	changed.emit()


## 그래픽 품질: 안티에일리어싱, 그림자 해상도, 렌더 배율
func _apply_quality() -> void:
	var vp := get_viewport()
	var web := OS.has_feature("web")
	match quality:
		0:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.scaling_3d_scale = 0.7 if web else 0.75
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
		1:
			vp.msaa_3d = Viewport.MSAA_DISABLED if web else Viewport.MSAA_2X
			vp.scaling_3d_scale = 0.85 if web else 0.9
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
		_:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.scaling_3d_scale = 1.0
			RenderingServer.directional_shadow_atlas_set_size(4096, true)


func _set_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(idx, v <= 0.001)
