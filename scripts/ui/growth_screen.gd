extends Control
## 성장 화면: 성장 포인트로 능력 강화, 깃털 색 고르기.

var menus


func _ready() -> void:
	var v := $Center/Panel/VBox
	v.get_node("Back").pressed.connect(func(): menus.back())
	for id in Growth.SKILLS:
		v.get_node("Skills/Up_" + id).pressed.connect(_up.bind(id))
	for pl in Growth.PLUMAGES:
		v.get_node("Plumage/Pl_" + pl).pressed.connect(_pick.bind(pl))


func open() -> void:
	visible = true
	_refresh()
	$Center/Panel/VBox/Back.grab_focus()


func _refresh() -> void:
	var v := $Center/Panel/VBox
	var d := Growth.g()
	v.get_node("Title").text = Loc.t("t_growth")
	v.get_node("Level").text = Loc.t("growth_level") % [int(d.level), int(d.xp), Growth.xp_needed(int(d.level)), int(d.points)]
	for id in Growth.SKILLS:
		v.get_node("Skills/Name_" + id).text = Loc.t("sk_" + id) + "   —   " + Loc.t("sk_" + id + "_d")
		var r := Growth.rank(id)
		v.get_node("Skills/Pips_" + id).text = "■".repeat(r) + "□".repeat(Growth.MAX_RANK - r)
		(v.get_node("Skills/Up_" + id) as Button).disabled = not Growth.can_spend(id)
	v.get_node("PlumageLabel").text = Loc.t("plumage")
	for pl in Growth.PLUMAGES:
		var b: Button = v.get_node("Plumage/Pl_" + pl)
		var open_pl := Records.has_plumage(pl)
		if open_pl:
			b.text = Loc.t("pl_" + pl)
		elif Growth.PLUMAGE_LEVEL.has(pl):
			b.text = Loc.t("pl_lock_lv") % int(Growth.PLUMAGE_LEVEL[pl])
		else:
			b.text = Loc.t("pl_lock_quest")
		b.disabled = not open_pl
		b.set_pressed_no_signal(str(d.get("plumage", "default")) == pl)
	v.get_node("Back").text = Loc.t("back")


func _up(id: String) -> void:
	if Growth.spend(id):
		Sfx.play("ui_good", -4.0)
		menus.main.falcon.apply_stats()
	_refresh()


func _pick(pl: String) -> void:
	Growth.g()["plumage"] = pl
	menus.main.refresh_plumage()
	Sfx.play("ui_click")
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("growth")):
		get_viewport().set_input_as_handled()
		menus.back()
