extends Control
## 비행 HUD: 시계, 목표, 체력/포만감/스태미나, 속도계, 알림, 팝업, 힌트.

@onready var clock: Label = $TopLeft/Clock
@onready var objectives: VBoxContainer = $TopLeft/Objectives
@onready var hp: ProgressBar = $Bars/Hp
@onready var food: ProgressBar = $Bars/Food
@onready var stam: ProgressBar = $Bars/Stam
@onready var carry_label: Label = $Bars/CarryLabel
@onready var carry: Label = $Bars/Carry
@onready var speed_l: Label = $Speedo/Speed
@onready var alt_l: Label = $Speedo/Alt
@onready var vsi_l: Label = $Speedo/Vsi
@onready var prompt: Label = $Prompt
@onready var popup_main: Label = $Popup/Main
@onready var popup_sub: Label = $Popup/Sub
@onready var popup_box: VBoxContainer = $Popup
@onready var feed: VBoxContainer = $Feed
@onready var hint_panel: PanelContainer = $Hint
@onready var hint_text: Label = $Hint/Text
@onready var fade: ColorRect = $Fade
@onready var reticle: Control = $Reticle
@onready var compass: Control = $Compass

var _popup_tw: Tween
var _pulse := 0.0
var _lang := ""


func _ready() -> void:
	$Bars/HpLabel.text = Loc.t("hud_hp")
	$Bars/FoodLabel.text = Loc.t("hud_food")
	$Bars/StamLabel.text = Loc.t("hud_stam")
	popup_main.text = ""
	popup_sub.text = ""
	prompt.text = ""
	GameState.notify.connect(notify)


func bind(main) -> void:
	reticle.main = main
	compass.main = main


func update_hud(main, delta: float) -> void:
	if _lang != Loc.lang:
		_lang = Loc.lang
		$Bars/HpLabel.text = Loc.t("hud_hp")
		$Bars/FoodLabel.text = Loc.t("hud_food")
		$Bars/StamLabel.text = Loc.t("hud_stam")
	var f: Falcon = main.falcon
	var fd := GameState.falcon()
	var h := float(GameState.data.get("time", 12.0))
	var hh := int(h)
	var mm := int((h - hh) * 60.0)
	clock.text = "%s %s · %s · %02d:%02d · %s" % [
		Loc.t("year_n") % int(GameState.data.get("year", 1)),
		Loc.t("season_" + GameState.season_id()),
		Loc.t("day_n") % int(GameState.data.get("day", 1)),
		hh, mm, Loc.t("weather_" + str(GameState.data.get("weather", "clear")))]
	hp.value = float(fd.get("health", 100.0))
	food.value = float(fd.get("energy", 50.0))
	stam.value = f.stamina / maxf(f.max_stamina, 1.0) * 100.0
	$Fps.visible = Settings.show_fps
	if Settings.show_fps:
		$Fps.text = "%d FPS" % Engine.get_frames_per_second()
	var gd := Growth.g()
	$Bars/XpLabel.text = "Lv.%d" % int(gd.level) + ("  +%d" % int(gd.points) if int(gd.points) > 0 else "")
	$Bars/Xp.value = float(gd.xp) / float(Growth.xp_needed(int(gd.level))) * 100.0
	_pulse += delta * 6.0
	var low := float(fd.get("energy", 50.0)) < 20.0
	food.modulate = Color(1, 1, 1, 0.55 + 0.45 * absf(sin(_pulse))) if low else Color.WHITE
	hp.modulate = Color(1, 1, 1, 0.55 + 0.45 * absf(sin(_pulse))) if float(fd.get("health", 100.0)) < 30.0 else Color.WHITE
	if f.carrying and is_instance_valid(f.carrying):
		carry_label.text = Loc.t("hud_carry")
		carry.text = Loc.t("prey_" + str(f.carrying.get("kind")))
	else:
		carry_label.text = ""
		carry.text = ""
	var kmh := f.kmh()
	speed_l.text = str(int(round(kmh)))
	var sc := clampf((kmh - 120.0) / 230.0, 0.0, 1.0)
	speed_l.modulate = Color(1, 1, 1).lerp(Color(1.0, 0.8, 0.25), sc)
	if kmh > 300.0:
		speed_l.modulate = Color(1.0, 0.45, 0.25)
	var p := f.global_position
	var above := p.y - WorldShape.floor_y(p.x, p.z)
	alt_l.text = Loc.t("hud_alt") % int(maxf(above, 0.0))
	var vy := f.velocity.y
	if f.state == Falcon.State.FLYING and absf(vy) > 1.5:
		vsi_l.text = ("▲ %d m/s" if vy > 0 else "▼ %d m/s") % int(absf(vy))
		vsi_l.modulate = Color(0.6, 1.0, 0.7) if vy > 0 else Color(1, 1, 1, 0.85)
	else:
		vsi_l.text = ""
	if f.in_thermal and f.state == Falcon.State.FLYING:
		vsi_l.text += "  " + Loc.t("hud_thermal")


func set_objectives(items: Array) -> void:
	for c in objectives.get_children():
		c.queue_free()
	for it in items:
		var l := Label.new()
		var done: bool = it.get("done", false)
		l.text = ("✓ " if done else "◆ ") + str(it.text)
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color(0.6, 0.95, 0.6) if done else Color(1, 0.95, 0.85))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		l.add_theme_constant_override("outline_size", 4)
		objectives.add_child(l)


func popup(text: String, sub: String = "", col: Color = Color(1, 0.84, 0.3), dur: float = 1.3) -> void:
	popup_main.text = text
	popup_sub.text = sub
	popup_main.label_settings.font_color = col
	popup_box.pivot_offset = popup_box.size * 0.5
	popup_box.modulate = Color(1, 1, 1, 1)
	popup_box.scale = Vector2.ONE * 1.6
	if _popup_tw:
		_popup_tw.kill()
	_popup_tw = create_tween().set_ignore_time_scale(true)
	_popup_tw.tween_property(popup_box, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_popup_tw.tween_interval(dur)
	_popup_tw.tween_property(popup_box, "modulate:a", 0.0, 0.5)


func notify(text: String, kind: String = "info") -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 21)
	var col := Color(1, 1, 1)
	match kind:
		"warn":
			col = Color(1.0, 0.55, 0.4)
		"good":
			col = Color(0.65, 1.0, 0.6)
		"gold":
			col = Color(1.0, 0.85, 0.35)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 5)
	feed.add_child(l)
	if feed.get_child_count() > 5:
		feed.get_child(0).queue_free()
	var tw := l.create_tween().set_ignore_time_scale(true)
	tw.tween_interval(5.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)
	if kind == "warn":
		Sfx.play("ui_error", -10.0)
	elif kind == "good" or kind == "gold":
		Sfx.play("notify", -8.0)


func set_prompt(text: String) -> void:
	if prompt.text != text:
		prompt.text = text


func show_hint(text: String) -> void:
	hint_text.text = text
	if not hint_panel.visible:
		hint_panel.visible = true
		hint_panel.modulate.a = 0.0
		create_tween().set_ignore_time_scale(true).tween_property(hint_panel, "modulate:a", 1.0, 0.3)
		Sfx.play("ui_open", -12.0)


func hide_hint() -> void:
	hint_panel.visible = false


func fade_to(a: float, dur: float) -> Tween:
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(fade, "color:a", a, dur)
	return tw


func set_flight_widgets_visible(v: bool) -> void:
	$Bars.visible = v
	$Speedo.visible = v
	$Compass.visible = v
	$TopLeft.visible = v
	reticle.visible = v
