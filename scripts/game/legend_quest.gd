class_name LegendQuest
extends Node3D
## 전설의 해동청 퀘스트.
## 0) Lv.2가 되면 둥지 앞에 빛나는 흰 깃털 → 1) 섬 세 곳의 깃털 모으기
## → 2) 높은 하늘에서 해동청 찾기 → 3) 술래잡기: 세 번 닿기 → 4) 흰 깃털(해동청 깃털 색) 해금

const ISLAND_IDS := ["seabird", "seals", "bats"]
const XP := 300

var main
var feathers := {}          # id -> Node3D
var white: WhiteFalcon
var _t := 0.0
var _chase_t := 0.0
var _tag_cd := 0.0


func setup(p_main) -> void:
	main = p_main


func q() -> Dictionary:
	if not GameState.data.has("legend"):
		GameState.data["legend"] = {"stage": 0, "got": []}
	return GameState.data["legend"]


func stage() -> int:
	return int(q().get("stage", 0))


## 새 게임·불러오기 뒤: 단계에 맞게 깃털과 해동청을 다시 놓는다
func restore() -> void:
	clear()
	match stage():
		1:
			for id in ISLAND_IDS:
				if not (q().got as Array).has(id):
					_spawn_feather(id)
		2:
			_spawn_white()


func clear() -> void:
	for id in feathers:
		if is_instance_valid(feathers[id]):
			feathers[id].queue_free()
	feathers.clear()
	if white and is_instance_valid(white):
		white.queue_free()
	white = null


func update(delta: float) -> void:
	_t += delta
	_tag_cd -= delta
	var f: Falcon = main.falcon
	for id in feathers:
		var n: Node3D = feathers[id]
		if is_instance_valid(n):
			n.rotation.y += delta * 1.5
			(n.get_child(0) as Node3D).position.y = sin(_t * 2.0) * 0.4
	match stage():
		0:
			if Growth.level() >= 2 and not main.day_night.is_night() and feathers.is_empty():
				_spawn_feather("start")
				GameState.say(Loc.t("lg_start_hint"), "gold")
			_check_pick(f)
		1:
			_check_pick(f)
		2:
			if white == null or not is_instance_valid(white):
				_spawn_white()
			elif f.global_position.distance_to(white.global_position) < 90.0 and f.is_flying():
				q()["stage"] = 3
				white.mode = WhiteFalcon.W.EVADE
				_chase_t = 0.0
				main.hud.popup(Loc.t("lg_meet"), Loc.t("lg_meet_sub"), Color(0.9, 0.95, 1.0), 2.6)
				Sfx.play_at("call", white.global_position, 4.0, 1.3, 800.0)
		3:
			if white == null or not is_instance_valid(white):
				q()["stage"] = 2
				return
			_chase_t += delta
			var d := f.global_position.distance_to(white.global_position)
			if d < 4.0 and f.is_flying() and f.speed > 12.0 and _tag_cd <= 0.0:
				_tag_cd = 1.5
				white.tagged()
				main.camera.add_trauma(0.3)
				Fx.feathers(main.fx_root, white.global_position, f.velocity, Color(1, 1, 1), Color(0.85, 0.88, 0.95), 30, 0.6)
				Sfx.play("hit_med", -4.0, 1.4)
				main.hud.popup(Loc.t("lg_tag"), "%d / 3" % white.tags, Color(0.9, 0.95, 1.0), 1.0)
				if white.tags >= 3:
					_complete()
			elif _chase_t > 120.0 or d > 700.0:
				# 놓쳤다 → 다시 높은 하늘에서 기다린다
				q()["stage"] = 2
				white.mode = WhiteFalcon.W.WAIT
				white.tags = 0
				GameState.say(Loc.t("lg_lost"), "info")


func _check_pick(f: Falcon) -> void:
	for id in feathers.keys():
		var n: Node3D = feathers[id]
		if is_instance_valid(n) and f.global_position.distance_to(n.global_position) < 6.0:
			n.queue_free()
			feathers.erase(id)
			Sfx.play("chime", 0.0, 1.4)
			Fx.feathers(main.fx_root, f.global_position, Vector3.UP, Color(1, 1, 1), Color(0.9, 0.95, 1.0), 20, 0.4)
			if id == "start":
				q()["stage"] = 1
				main.hud.popup(Loc.t("lg_title"), Loc.t("lg_start"), Color(0.9, 0.95, 1.0), 3.0)
				GameState.say(Loc.t("lg_start_sub"), "gold")
				for iid in ISLAND_IDS:
					_spawn_feather(iid)
			else:
				(q().got as Array).append(id)
				var n_got: int = (q().got as Array).size()
				main.hud.popup(Loc.t("lg_feather"), "%d / 3" % n_got, Color(0.9, 0.95, 1.0), 1.6)
				main.gain_xp(40)
				if n_got >= 3:
					q()["stage"] = 2
					GameState.say(Loc.t("lg_all_feathers"), "gold")
					_spawn_white()
			GameState.save_game()
			return


func _complete() -> void:
	q()["stage"] = 4
	white.mode = WhiteFalcon.W.LEAVE
	get_tree().create_timer(15.0, false).timeout.connect(func():
		if is_instance_valid(white):
			white.queue_free())
	main.hud.popup(Loc.t("lg_done"), Loc.t("lg_done_sub"), Color(1.0, 0.95, 0.8), 3.5)
	Sfx.play("chime_big", 2.0)
	Records.unlock_plumage("white")
	Records.unlock("legend")
	main.gain_xp(XP)
	GameState.save_game()


func _feather_pos(id: String) -> Vector3:
	match id:
		"start":
			return WorldShape.eyrie + WorldShape.eyrie_facing * 14.0 + Vector3(0, 5, 0)
		"seabird":
			var isl := WorldShape.island_by_id("seabird")
			var c: Vector3 = isl.info.colony
			var out := c - isl.center
			out.y = 0.0
			return c + out.normalized() * 10.0 + Vector3(0, 6, 0)
		"seals":
			var isl2 := WorldShape.island_by_id("seals")
			return (isl2.info.knoll as Vector3) + Vector3(0, 5, 0)
		"bats":
			var isl3 := WorldShape.island_by_id("bats")
			var cave: Vector3 = isl3.info.cave
			var out3 := cave - isl3.center
			out3.y = 0.0
			return cave + out3.normalized() * 10.0 + Vector3(0, 4, 0)
	return WorldShape.eyrie


func _spawn_feather(id: String) -> void:
	var root := Node3D.new()
	root.name = "LegendFeather_" + id
	add_child(root)
	root.global_position = _feather_pos(id)
	var holder := Node3D.new()
	root.add_child(holder)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1)
	m.emission_enabled = true
	m.emission = Color(0.85, 0.92, 1.0)
	m.emission_energy_multiplier = 2.5
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.material = m
	var feather := MeshInstance3D.new()
	feather.mesh = sm
	feather.scale = Vector3(0.35, 0.12, 1.6)
	feather.rotation.x = 0.4
	holder.add_child(feather)
	# 멀리서도 보이는 빛기둥
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.albedo_color = Color(0.6, 0.75, 1.0, 0.35)
	bm.disable_fog = true
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.9
	cm.height = 140.0
	cm.radial_segments = 8
	cm.cap_top = false
	cm.cap_bottom = false
	cm.material = bm
	var beam := MeshInstance3D.new()
	beam.mesh = cm
	beam.position.y = 70.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)
	feathers[id] = root


func _spawn_white() -> void:
	if white and is_instance_valid(white):
		return
	var t: Dictionary = WorldShape.thermals[0]
	var home: Vector3 = (t.pos as Vector3) + Vector3(0, 470, 0)
	white = WhiteFalcon.new().setup(home)
	main.add_child(white)


func objective() -> Dictionary:
	match stage():
		1:
			return {"text": Loc.t("lg_obj_feathers") % (q().got as Array).size()}
		2:
			return {"text": Loc.t("lg_obj_find")}
		3:
			return {"text": Loc.t("lg_obj_tag") % (white.tags if white and is_instance_valid(white) else 0)}
	return {}


func markers() -> Array:
	var out := []
	var col := Color(0.85, 0.92, 1.0)
	for id in feathers:
		if is_instance_valid(feathers[id]):
			out.append({"pos": (feathers[id] as Node3D).global_position, "color": col, "label": Loc.t("mk_feather")})
	if white and is_instance_valid(white) and stage() >= 2 and stage() < 4:
		out.append({"pos": white.global_position, "color": col, "label": Loc.t("mk_white")})
	return out
