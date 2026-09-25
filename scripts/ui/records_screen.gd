extends Control
## 기록(업적) 목록.

var menus


func _ready() -> void:
	$Center/Panel/VBox/Back.pressed.connect(func(): menus.back())


func open() -> void:
	visible = true
	var v := $Center/Panel/VBox
	v.get_node("Title").text = Loc.t("t_records")
	v.get_node("Back").text = Loc.t("back")
	v.get_node("Count").text = Loc.t("records_count") % [Records.count(), Records.LIST.size()]
	var list: VBoxContainer = v.get_node("Scroll/List")
	for c in list.get_children():
		c.queue_free()
	for e in Records.LIST:
		var id: String = e[0]
		var done := Records.has(id)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		var t := Label.new()
		t.text = ("★ " if done else "☆ ") + Records.title(id)
		t.add_theme_font_size_override("font_size", 24)
		t.add_theme_color_override("font_color", Color(1, 0.85, 0.35) if done else Color(0.6, 0.6, 0.62))
		row.add_child(t)
		var d := Label.new()
		d.text = "    " + Records.desc(id)
		d.add_theme_font_size_override("font_size", 18)
		d.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9) if done else Color(0.5, 0.5, 0.52))
		row.add_child(d)
		list.add_child(row)
	v.get_node("Back").grab_focus()
