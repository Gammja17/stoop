extends Control
## 죽음과 혈통. 살아 있는 자식이 있으면 그 자식으로 삶을 이어간다.

var menus


func _ready() -> void:
	$Center/Panel/VBox/ToTitle.pressed.connect(_to_title)


func open(cause: String) -> void:
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.8)
	var v := $Center/Panel/VBox
	var lineage: Array = GameState.data.get("lineage", [])
	var last: Dictionary = lineage[-1] if lineage.size() > 0 else {}
	v.get_node("Title").text = Loc.t("d_title") % str(last.get("name", GameState.falcon().get("name", "")))
	v.get_node("Cause").text = Loc.t("cause_" + cause) if cause != "" else ""
	var lv: VBoxContainer = v.get_node("Lineage")
	for c in lv.get_children():
		c.queue_free()
	var head := Label.new()
	head.text = Loc.t("d_lineage")
	head.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	lv.add_child(head)
	for e in lineage:
		var l := Label.new()
		l.text = Loc.t("d_line") % [int(e.get("gen", 1)), str(e.get("name", "")), int(e.get("age", 1)), int(e.get("prey", 0)), int(e.get("fledged", 0))]
		lv.add_child(l)
	var ch: VBoxContainer = v.get_node("Choices")
	for c in ch.get_children():
		c.queue_free()
	var kids := GameState.living_offspring()
	if kids.is_empty():
		v.get_node("ChooseLabel").text = Loc.t("d_end")
		v.get_node("ToTitle").text = Loc.t("d_title_btn")
	else:
		v.get_node("ChooseLabel").text = Loc.t("d_choose")
		v.get_node("ToTitle").text = Loc.t("d_later")
		for k in kids.slice(0, 6):
			var b := Button.new()
			b.text = Loc.t("d_kid") % [str(k.get("name", "")), Loc.t("ng_male") if k.get("sex", "m") == "m" else Loc.t("ng_female"), int(k.get("skill", 0)), int(k.get("year", 1))]
			b.pressed.connect(_choose.bind(k))
			ch.add_child(b)
		(ch.get_child(0) as Button).call_deferred("grab_focus")
	Sfx.music("title", 3.0)


func _choose(k: Dictionary) -> void:
	Sfx.play("ui_confirm")
	menus.main.continue_lineage(k)


func _to_title() -> void:
	Sfx.play("ui_back")
	if GameState.living_offspring().is_empty():
		GameState.delete_save()
	menus.main.quit_to_title()
