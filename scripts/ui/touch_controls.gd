class_name TouchControls
extends Control
## 모바일(터치) 조작: 왼쪽 가상 스틱 + 오른쪽 버튼들.
## 버튼은 TouchScreenButton(여러 손가락 동시 입력)이라 스틱을 잡은 채로 누를 수 있다.

const STICK_R := 120.0

var main
var _stick_idx := -1
var _stick_origin := Vector2.ZERO
var _stick_now := Vector2.ZERO
var _tex_cache := {}


static func wanted() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for b in $Buttons.get_children():
		if b is TouchScreenButton:
			var r: float = b.get_meta("r", 70.0)
			b.texture_normal = _circle(r, Color(1, 1, 1, 0.16))
			b.texture_pressed = _circle(r, Color(1, 0.85, 0.35, 0.45))
			var sh := CircleShape2D.new()
			sh.radius = r
			b.shape = sh
			b.shape_centered = true
			var l: Label = b.get_node("Label")
			l.position = Vector2(0, r - 18.0)
			l.size = Vector2(r * 2.0, 36)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _circle(r: float, col: Color) -> Texture2D:
	var key := "%d_%s" % [int(r), col.to_html()]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var n := int(r * 2.0)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - r, y - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			var edge := clampf(1.0 - absf(d - (r - 3.0)) / 2.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * a + 0.35 * edge * a))
	var t := ImageTexture.create_from_image(img)
	_tex_cache[key] = t
	return t


## 화면 크기에 맞춰 버튼을 오른쪽 아래에 배치
func _layout() -> void:
	var sz := get_viewport().get_visible_rect().size
	var base := Vector2(sz.x - 170.0, sz.y - 300.0)   # 오른쪽 아래 속도계 위
	var spots := {
		"Tuck": base,
		"Flap": base + Vector2(-190, 40),
		"Interact": base + Vector2(-60, -190),
		"Eye": base + Vector2(-250, -130),
		"Eat": base + Vector2(-400, 40),
		"Drop": base + Vector2(-400, -110),
		"Pause": Vector2(sz.x - 90.0, 150.0),
		"Map": Vector2(sz.x - 230.0, 150.0),
	}
	for n in spots:
		var b := $Buttons.get_node_or_null(n) as Node2D
		if b:
			var r: float = b.get_meta("r", 70.0)
			b.position = (spots[n] as Vector2) - Vector2(r, r)   # 텍스처 왼쪽 위가 원점


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var sz := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _stick_idx < 0 and t.position.x < sz.x * 0.4 and t.position.y > sz.y * 0.35:
			_stick_idx = t.index
			_stick_origin = t.position
			_stick_now = t.position
			queue_redraw()
		elif not t.pressed and t.index == _stick_idx:
			_stick_idx = -1
			Falcon.touch_stick = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_idx:
			_stick_now = d.position
			var v := (_stick_now - _stick_origin) / STICK_R
			if v.length() > 1.0:
				v = v.normalized()
			Falcon.touch_stick = v
			queue_redraw()


func _draw() -> void:
	if _stick_idx < 0:
		var sz := get_viewport().get_visible_rect().size
		var hint := Vector2(240.0, sz.y - 380.0)   # 왼쪽 아래 막대들 위
		draw_arc(hint, STICK_R, 0.0, TAU, 48, Color(1, 1, 1, 0.18), 3.0)
		return
	draw_circle(_stick_origin, STICK_R, Color(1, 1, 1, 0.1))
	draw_arc(_stick_origin, STICK_R, 0.0, TAU, 48, Color(1, 1, 1, 0.3), 3.0)
	var knob := _stick_origin + (_stick_now - _stick_origin).limit_length(STICK_R)
	draw_circle(knob, 46.0, Color(1, 0.9, 0.6, 0.45))


func _process(_delta: float) -> void:
	if main == null:
		return
	var show: bool = main.playing and not main.menus.any_open()
	if visible != show:
		visible = show
		if not show:
			_stick_idx = -1
			Falcon.touch_stick = Vector2.ZERO
	if visible:
		var lang := Loc.lang
		if get_meta("lang", "") != lang:
			set_meta("lang", lang)
			for b in $Buttons.get_children():
				(b.get_node("Label") as Label).text = Loc.t("tc_" + str(b.name).to_lower())
