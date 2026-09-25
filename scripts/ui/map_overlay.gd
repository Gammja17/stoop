extends Control
## 지도 위 표식 그리기.

var main


func _process(_d: float) -> void:
	if visible:
		queue_redraw()


func _w2m(p: Vector3) -> Vector2:
	var half := WorldShape.HALF
	return Vector2((p.x - WorldShape.X_MIN) / (WorldShape.X_MAX - WorldShape.X_MIN) * size.x, (p.z + half) / (half * 2.0) * size.y)


func _draw() -> void:
	if main == null:
		return
	var font := get_theme_default_font()
	var places := [
		[WorldShape.village, Loc.t("map_village"), Color(1, 0.95, 0.85)],
		[WorldShape.bay, Loc.t("map_bay"), Color(1, 0.95, 0.85)],
		[WorldShape.fields, Loc.t("map_fields"), Color(1, 0.95, 0.85)],
		[WorldShape.cliffs_center + Vector3(-80, 0, 0), Loc.t("map_cliffs"), Color(1, 0.95, 0.85)],
		[WorldShape.lighthouse, Loc.t("map_lighthouse"), Color(1, 0.95, 0.85)],
	]
	for isl: WorldShape.Island in WorldShape.islands:
		places.append([isl.center + Vector3(0, 0, isl.ra + 90.0), Loc.t("map_isl_" + isl.id), Color(0.85, 0.95, 1.0)])
	for p in places:
		var s := _w2m(p[0])
		draw_string(font, s + Vector2(-80, 0), p[1], HORIZONTAL_ALIGNMENT_CENTER, 160, 18, p[2])
	for t in WorldShape.thermals:
		var s2 := _w2m(t.pos)
		draw_arc(s2, 10.0, 0, TAU, 20, Color(1, 0.9, 0.5, 0.8), 2.0)
		draw_string(font, s2 + Vector2(-8, 6), "↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.9, 0.5))
	var e := _w2m(WorldShape.eyrie)
	draw_circle(e, 7.0, Color(1, 0.8, 0.25))
	draw_string(font, e + Vector2(10, 6), Loc.t("mk_eyrie"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.8, 0.25))
	for m in main.life.markers() + main.prey_mgr.markers() + main.events.markers() + main.legend.markers():
		if m.label == Loc.t("mk_eyrie"):
			continue
		var s3 := _w2m(m.pos)
		draw_circle(s3, 5.0, m.color)
	var f: Falcon = main.falcon
	var fp := _w2m(f.global_position)
	var d := Vector2(f.dir.x, f.dir.z)
	if d.length() < 0.1:
		d = Vector2(1, 0)
	d = d.normalized()
	var side := d.orthogonal()
	draw_colored_polygon(PackedVector2Array([fp + d * 14.0, fp - d * 8.0 + side * 8.0, fp - d * 4.0, fp - d * 8.0 - side * 8.0]), Color(1, 1, 1))
