extends Control
## 조준선(마우스가 가리키는 곳), 비행 경로 표시(실제로 가는 곳), 목표 괄호, 예측 지점(◇), 화면 밖 표식.

const GOLD := Color(1.0, 0.8, 0.25)
const WHITE := Color(1, 1, 1, 0.9)

var main
var target: Node3D = null
var lead := Vector3.ZERO
var has_lead := false
var confusion := 0.0
var markers: Array = []
var eye := 0.0
var _jit := Vector2.ZERO
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _to_screen(cam: Camera3D, p: Vector3) -> Vector2:
	var s := cam.unproject_position(p)
	var vp := get_viewport().get_visible_rect().size
	if vp.x > 0.0:
		s *= size / vp
	return s


func _draw() -> void:
	if main == null or not main.playing:
		return
	var cam: Camera3D = main.camera
	var f: Falcon = main.falcon
	if f.state == Falcon.State.FLYING and cam.mode == ChaseCamera.Mode.FOLLOW:
		var ap := f.global_position + f.aim_dir() * 150.0
		if not cam.is_position_behind(ap):
			var s := _to_screen(cam, ap)
			draw_arc(s, 13.0, 0, TAU, 28, Color(1, 1, 1, 0.65), 2.0, true)
			for k in 4:
				var d := Vector2.RIGHT.rotated(k * PI * 0.5)
				draw_line(s + d * 17.0, s + d * 24.0, Color(1, 1, 1, 0.65), 2.0, true)
		var fp := f.global_position + f.dir * 150.0
		if not cam.is_position_behind(fp):
			var s2 := _to_screen(cam, fp)
			var c2 := Color(0.6, 1.0, 0.75, 0.85)
			draw_arc(s2, 6.0, 0, TAU, 16, c2, 2.0, true)
			draw_line(s2 + Vector2(-18, 0), s2 + Vector2(-7, 0), c2, 2.0, true)
			draw_line(s2 + Vector2(7, 0), s2 + Vector2(18, 0), c2, 2.0, true)
			draw_line(s2 + Vector2(0, -7), s2 + Vector2(0, -14), c2, 2.0, true)
		_draw_target(cam, f)
		if eye > 0.05:
			_draw_eye(cam, f)
	_draw_markers(cam)


func _draw_target(cam: Camera3D, f: Falcon) -> void:
	if target == null or not is_instance_valid(target):
		return
	var tp: Vector3 = target.global_position
	if cam.is_position_behind(tp):
		return
	if confusion > 0.05:
		if randf() < 0.3:
			_jit = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 26.0 * confusion
	else:
		_jit = Vector2.ZERO
	var s := _to_screen(cam, tp) + _jit
	var dist := tp.distance_to(f.global_position)
	var sz := clampf(900.0 / maxf(dist, 1.0), 14.0, 60.0)
	var close := dist < 120.0
	var col := GOLD if close else WHITE
	var l := sz * 0.45
	for sx: int in [-1, 1]:
		for sy: int in [-1, 1]:
			var c := s + Vector2(sx * sz, sy * sz)
			draw_line(c, c - Vector2(sx * l, 0), col, 2.5, true)
			draw_line(c, c - Vector2(0, sy * l), col, 2.5, true)
	var font := get_theme_default_font()
	draw_string(font, s + Vector2(sz + 8, -sz + 16), "%d m" % int(dist), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
	if target.get("kind"):
		var label_txt := Loc.t("prey_" + str(target.get("kind")))
		var weak_col := Color(1, 1, 1, 0.7)
		if target.get("weak"):
			label_txt += " · " + Loc.t("weak")
			weak_col = Color(1.0, 0.5, 0.4, 0.95)
		draw_string(font, s + Vector2(sz + 8, -sz + 36), label_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, weak_col)
	if has_lead and not cam.is_position_behind(lead):
		var ls := _to_screen(cam, lead) + _jit * 1.5
		var d := 11.0 + (6.0 if close else 0.0) * (0.5 + 0.5 * sin(_t * 12.0))
		var pts := PackedVector2Array([ls + Vector2(0, -d), ls + Vector2(d, 0), ls + Vector2(0, d), ls + Vector2(-d, 0), ls + Vector2(0, -d)])
		draw_polyline(pts, GOLD, 2.5, true)
		draw_dashed_line(s, ls, Color(1, 0.8, 0.25, 0.45), 1.5, 6.0, true)


func _draw_eye(cam: Camera3D, f: Falcon) -> void:
	var font := get_theme_default_font()
	for p in main.prey_mgr.prey:
		if not is_instance_valid(p):
			continue
		if not (p.state == Prey.S.FLY or p.state == Prey.S.FLEE or p.state == Prey.S.SWIM or p.state == Prey.S.GROUND or p.state == Prey.S.WATER):
			continue
		var pp: Vector3 = p.global_position
		var d := pp.distance_to(f.global_position)
		if d > 1500.0 or cam.is_position_behind(pp):
			continue
		var s := _to_screen(cam, pp)
		var col := Color(1, 0.9, 0.4, eye * 0.9)
		if p.state == Prey.S.SWIM:
			col = Color(0.6, 0.8, 1.0, eye * 0.7)
		elif p.state == Prey.S.GROUND or p.state == Prey.S.WATER:
			col = Color(1.0, 0.5, 0.4, eye)
		draw_circle(s, 3.0, col)
		if p.weak and (p.state == Prey.S.FLY or p.state == Prey.S.FLEE):
			draw_arc(s, 8.0 + 2.0 * sin(_t * 6.0), 0, TAU, 16, Color(1.0, 0.35, 0.3, eye), 2.0, true)
	for t in WorldShape.thermals:
		var top: Vector3 = (t.pos as Vector3) + Vector3(0, 120, 0)
		if cam.is_position_behind(top):
			continue
		var s2 := _to_screen(cam, top)
		draw_string(font, s2 - Vector2(40, 0), "↑ " + Loc.t("hud_thermal"), HORIZONTAL_ALIGNMENT_CENTER, 80, 16, Color(1, 0.9, 0.6, eye * 0.8))


func _draw_markers(cam: Camera3D) -> void:
	var font := get_theme_default_font()
	var center := size * 0.5
	for m in markers:
		var pos: Vector3 = m.pos
		var col: Color = m.get("color", Color.WHITE)
		var label: String = m.get("label", "")
		var behind := cam.is_position_behind(pos)
		var s := _to_screen(cam, pos)
		var margin := 48.0
		var on := not behind and s.x > margin and s.x < size.x - margin and s.y > margin and s.y < size.y - margin
		var dist := cam.global_position.distance_to(pos)
		if on:
			draw_circle(s, 6.0, col)
			draw_arc(s, 10.0, 0, TAU, 20, Color(col, 0.6), 1.5, true)
			draw_string(font, s + Vector2(-100, -16), "%s  %dm" % [label, int(dist)], HORIZONTAL_ALIGNMENT_CENTER, 200, 17, col)
		else:
			var dir := (s - center)
			if behind:
				dir = -dir
			if dir.length() < 1.0:
				dir = Vector2.DOWN
			dir = dir.normalized()
			var edge := center + dir * minf((size.x * 0.5 - margin) / maxf(absf(dir.x), 0.001), (size.y * 0.5 - margin) / maxf(absf(dir.y), 0.001))
			# 아래쪽 모서리의 체력바·속도계와 겹치지 않게 위로 올린다
			if edge.y > size.y - 210.0 and (edge.x < 460.0 or edge.x > size.x - 360.0):
				edge.y = size.y - 210.0
			var tip := edge + dir * 12.0
			var side := dir.orthogonal() * 8.0
			draw_colored_polygon(PackedVector2Array([tip, edge - dir * 4.0 + side, edge - dir * 4.0 - side]), col)
			draw_string(font, edge - dir * 26.0 + Vector2(-90, 6), label, HORIZONTAL_ALIGNMENT_CENTER, 180, 16, col)
