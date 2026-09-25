extends Control
## 한 해가 끝났을 때의 결산.

var menus


func _ready() -> void:
	$Center/Panel/VBox/Next.pressed.connect(_on_next)


func open(fledged: int) -> void:
	visible = true
	var v := $Center/Panel/VBox
	var d := GameState.data
	var st := GameState.stats()
	var fd := GameState.falcon()
	v.get_node("Title").text = Loc.t("sum_title") % int(d.get("year", 1))
	var g: GridContainer = v.get_node("Stats")
	for c in g.get_children():
		c.queue_free()
	var rows := [
		[Loc.t("sum_name"), "%s (%s)" % [str(fd.get("name", "")), Loc.t("ng_male") if fd.get("sex", "m") == "m" else Loc.t("ng_female")]],
		[Loc.t("sum_age"), str(int(fd.get("age", 1)))],
		[Loc.t("sum_prey_year"), str(int(st.get("year_prey", 0)))],
		[Loc.t("sum_prey_total"), str(int(st.get("prey_total", 0)))],
		[Loc.t("sum_top_speed"), "%d km/h" % int(st.get("top_speed", 0.0))],
		[Loc.t("sum_perfect"), str(int(st.get("perfect", 0)))],
		[Loc.t("sum_fledged"), str(fledged)],
		[Loc.t("sum_generation"), str(int(d.get("generation", 1)))],
	]
	for r in rows:
		var a := Label.new()
		a.text = r[0]
		a.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		g.add_child(a)
		var b := Label.new()
		b.text = r[1]
		g.add_child(b)
	var age := int(fd.get("age", 1))
	var span := int(fd.get("lifespan", 6))
	v.get_node("Note").text = Loc.t("sum_note_old") if age + 1 >= span else Loc.t("sum_note")
	v.get_node("Next").text = Loc.t("sum_next")
	v.get_node("Next").grab_focus()


func _on_next() -> void:
	Sfx.play("ui_confirm")
	menus.close_all()
	menus.main.life.start_new_year()
