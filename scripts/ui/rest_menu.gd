extends Control
## 둥지 메뉴: 아침까지 자기(저장), 한 시간 쉬기, 저장, 날아오르기.

var menus


func _ready() -> void:
	var v := $Center/Panel/VBox
	v.get_node("Sleep").pressed.connect(func(): Sfx.play("ui_confirm"); menus.main.sleep_until_morning())
	v.get_node("Nap").pressed.connect(func(): Sfx.play("ui_confirm"); menus.main.nap())
	v.get_node("Save").pressed.connect(_save)
	v.get_node("Fly").pressed.connect(func(): menus.close_all(); menus.main.falcon.take_off())
	v.get_node("Back").pressed.connect(func(): menus.resume())


func open() -> void:
	visible = true
	var v := $Center/Panel/VBox
	var life = menus.main.life
	v.get_node("Title").text = Loc.t("r_title")
	v.get_node("Sleep").text = Loc.t("r_sleep")
	v.get_node("Sleep").disabled = not life.can_sleep()
	v.get_node("Nap").text = Loc.t("r_nap")
	v.get_node("Save").text = Loc.t("r_save")
	v.get_node("Fly").text = Loc.t("r_fly")
	v.get_node("Back").text = Loc.t("back")
	var fd := GameState.falcon()
	var lines := []
	lines.append(Loc.t("r_status") % [str(fd.get("name", "")), int(fd.get("age", 1)), int(fd.get("health", 0)), int(fd.get("energy", 0))])
	var l := GameState.life()
	if l.mate.get("has", false):
		lines.append(Loc.t("r_mate") % str(l.mate.get("name", "")))
	if int(l.get("eggs", 0)) > 0:
		lines.append(Loc.t("r_eggs") % int(l.eggs))
	var chicks: Array = life.alive_chicks()
	for c in chicks:
		lines.append(Loc.t("r_chick") % [str(c.name), int(c.get("food", 0))])
	for fl in l.get("fledglings", []):
		lines.append(Loc.t("r_fledgling") % [str(fl.name), int(fl.get("skill", 0)), int(fl.get("food", 0))])
	if not life.can_sleep():
		lines.append(Loc.t("r_sleep_later"))
	v.get_node("Status").text = "\n".join(lines)
	v.get_node("Back").grab_focus()


func _save() -> void:
	GameState.save_game()
	Sfx.play("ui_good")
	GameState.say(Loc.t("saved"), "good")
	menus.resume()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("interact")):
		get_viewport().set_input_as_handled()
		menus.resume()
