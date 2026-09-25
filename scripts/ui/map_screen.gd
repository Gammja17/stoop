extends Control
## 지도: 높이 격자로 만든 이미지 위에 매·둥지·서식지·상승기류 표시.

var menus
static var _tex: ImageTexture


func _ready() -> void:
	pass


func open() -> void:
	visible = true
	$Center/VBox/Title.text = Loc.t("p_map")
	$Center/VBox/Hint.text = Loc.t("map_hint")
	if _tex == null:
		_tex = ImageTexture.create_from_image(_build_image())
	$Center/VBox/Frame/Image.texture = _tex
	$Center/VBox/Frame/Image/Overlay.main = menus.main


static func _build_image() -> Image:
	var half := WorldShape.HALF
	var res := 280
	var img := Image.create(res, res, false, Image.FORMAT_RGB8)
	for j in res:
		for i in res:
			var x := -half + (i + 0.5) * (half * 2.0 / res)
			var z := -half + (j + 0.5) * (half * 2.0 / res)
			var h := WorldShape.ground(x, z)
			var c: Color
			if h < 0.0:
				var d := clampf(-h / 30.0, 0.0, 1.0)
				c = Color(0.16, 0.42, 0.5).lerp(Color(0.05, 0.16, 0.27), d)
				if h > -0.8:
					c = Color(0.42, 0.37, 0.3)
			else:
				var n := WorldShape.normal(x, z)
				if n.y < 0.72:
					c = Color(0.46, 0.44, 0.42)
				elif h < 4.0:
					c = Color(0.78, 0.72, 0.55)
				else:
					c = Color(0.35, 0.48, 0.27).lerp(Color(0.62, 0.62, 0.5), clampf(h / 260.0, 0.0, 1.0))
				var shade := clampf(0.75 + (n.x - n.z) * 0.9, 0.5, 1.2)
				c = c * shade
			img.set_pixel(i, j, c)
	return img


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("map") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		menus.resume()
