extends Control
## 상단 나침반 띠. 북=-Z, 동=+X(바다).

const PX_PER_DEG := 3.8

var main


func _process(_d: float) -> void:
	queue_redraw()


static func bearing(v: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(v.x, -v.z)), 360.0)


func _draw() -> void:
	if main == null or not main.playing:
		return
	var cam: Camera3D = main.camera
	var fwd := -cam.global_basis.z
	var h := bearing(fwd)
	var w := size.x
	var cx := w * 0.5
	var y := size.y * 0.5
	draw_rect(Rect2(0, y - 1, w, 2), Color(1, 1, 1, 0.25))
	var font := get_theme_default_font()
	var names := {0: Loc.t("dir_n"), 90: Loc.t("dir_e"), 180: Loc.t("dir_s"), 270: Loc.t("dir_w")}
	for deg in range(0, 360, 15):
		var d := wrapf(deg - h, -180.0, 180.0)
		var x := cx + d * PX_PER_DEG
		if x < 0 or x > w:
			continue
		var fade := 1.0 - absf(d) / (w * 0.5 / PX_PER_DEG)
		if names.has(deg):
			draw_string(font, Vector2(x - 20, y + 7), names[deg], HORIZONTAL_ALIGNMENT_CENTER, 40, 22, Color(1, 0.9, 0.6, fade))
		else:
			draw_line(Vector2(x, y - 5), Vector2(x, y + 5), Color(1, 1, 1, 0.5 * fade), 1.5)
	# 표식
	var reticle = main.hud.reticle
	for m in reticle.markers:
		var to: Vector3 = (m.pos as Vector3) - cam.global_position
		var b := bearing(to)
		var d := wrapf(b - h, -180.0, 180.0)
		var x := clampf(cx + d * PX_PER_DEG, 6.0, w - 6.0)
		var col: Color = m.get("color", Color.WHITE)
		draw_colored_polygon(PackedVector2Array([Vector2(x, y + 9), Vector2(x - 6, y + 19), Vector2(x + 6, y + 19)]), col)
	draw_line(Vector2(cx, y - 12), Vector2(cx, y - 4), Color(1, 0.8, 0.25), 2.0)
