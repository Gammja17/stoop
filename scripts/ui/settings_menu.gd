extends Control
## 설정: 감도, 볼륨, 화면 효과(멀미 대비), 흔들림, 킬캠, 힌트, 하루 길이, 언어.

var menus
var _built := false


func _ready() -> void:
	$Center/Panel/VBox/Back.pressed.connect(_on_back)


func open() -> void:
	visible = true
	$Center/Panel/VBox/Title.text = Loc.t("t_settings")
	$Center/Panel/VBox/Back.text = Loc.t("back")
	_build()
	$Center/Panel/VBox/Back.grab_focus()


func _build() -> void:
	var g: GridContainer = $Center/Panel/VBox/Scroll/Grid
	for c in g.get_children():
		c.queue_free()
	_slider(g, "s_mouse", Settings.mouse_sens, 0.2, 3.0, func(v): Settings.mouse_sens = v)
	_check(g, "s_invert", Settings.invert_y, func(v): Settings.invert_y = v)
	_slider(g, "s_master", Settings.vol_master, 0.0, 1.0, func(v): Settings.vol_master = v; Settings.apply())
	_slider(g, "s_music", Settings.vol_music, 0.0, 1.0, func(v): Settings.vol_music = v; Settings.apply())
	_slider(g, "s_sfx", Settings.vol_sfx, 0.0, 1.0, func(v): Settings.vol_sfx = v; Settings.apply())
	_slider(g, "s_amb", Settings.vol_amb, 0.0, 1.0, func(v): Settings.vol_amb = v; Settings.apply())
	_slider(g, "s_fx", Settings.fx_intensity, 0.0, 1.5, func(v): Settings.fx_intensity = v)
	_slider(g, "s_shake", Settings.shake, 0.0, 1.5, func(v): Settings.shake = v)
	_check(g, "s_killcam", Settings.killcam, func(v): Settings.killcam = v)
	_check(g, "s_hints", Settings.hints, func(v): Settings.hints = v)
	_option(g, "s_quality", [Loc.t("s_q_low"), Loc.t("s_q_mid"), Loc.t("s_q_high")], Settings.quality, func(i): Settings.quality = i; Settings.apply())
	_check(g, "s_fullscreen", Settings.fullscreen, func(v): Settings.fullscreen = v; Settings.apply())
	_check(g, "s_vsync", Settings.vsync, func(v): Settings.vsync = v; Settings.apply())
	var days := [6.0, 8.0, 12.0]
	var idx := maxi(days.find(Settings.day_minutes), 0)
	_option(g, "s_day", [Loc.t("s_day_short"), Loc.t("s_day_normal"), Loc.t("s_day_long")], idx, func(i): Settings.day_minutes = days[i])
	_option(g, "s_lang", ["한국어", "English"], 0 if Settings.lang == "ko" else 1, func(i): Settings.lang = "ko" if i == 0 else "en"; Settings.apply(); open())


func _label(g: GridContainer, key: String) -> void:
	var l := Label.new()
	l.text = Loc.t(key)
	l.custom_minimum_size = Vector2(320, 0)
	g.add_child(l)


func _slider(g: GridContainer, key: String, value: float, lo: float, hi: float, cb: Callable) -> void:
	_label(g, key)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(420, 32)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v): cb.call(v); Sfx.play("ui_hover", -16.0))
	g.add_child(s)


func _check(g: GridContainer, key: String, value: bool, cb: Callable) -> void:
	_label(g, key)
	var c := CheckButton.new()
	c.button_pressed = value
	c.toggled.connect(func(v): cb.call(v); Sfx.play("ui_select", -10.0))
	g.add_child(c)


func _option(g: GridContainer, key: String, items: Array, idx: int, cb: Callable) -> void:
	_label(g, key)
	var o := OptionButton.new()
	for it in items:
		o.add_item(it)
	o.selected = idx
	o.item_selected.connect(func(i): cb.call(i); Sfx.play("ui_select", -10.0))
	g.add_child(o)


func _on_back() -> void:
	Settings.save_settings()
	Settings.apply()
	menus.back()
