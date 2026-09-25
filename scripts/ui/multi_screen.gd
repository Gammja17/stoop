extends Control
## 함께 날기(멀티, 베타): 방 만들기 / 코드로 참가 / 링크 복사 / 나가기.

var menus


func _ready() -> void:
	var v := $Center/Panel/VBox
	v.get_node("Row/Host").pressed.connect(func(): Sfx.play("ui_click"); Net.host())
	v.get_node("Row/Join").pressed.connect(func(): Sfx.play("ui_click"); Net.join(v.get_node("Row/Code").text))
	v.get_node("Copy").pressed.connect(_copy)
	v.get_node("Leave").pressed.connect(func(): Sfx.play("ui_back"); Net.leave())
	v.get_node("Back").pressed.connect(func(): menus.back())
	Net.changed.connect(_refresh)


func open() -> void:
	visible = true
	_refresh()
	$Center/Panel/VBox/Back.grab_focus()


func _copy() -> void:
	DisplayServer.clipboard_set(Net.share_link())
	Sfx.play("ui_good", -4.0)
	$Center/Panel/VBox/Copy.text = Loc.t("mp_copied")


func _refresh() -> void:
	if not visible:
		return
	var v := $Center/Panel/VBox
	var ok := Net.supported()
	v.get_node("Title").text = Loc.t("t_multi")
	v.get_node("Note").text = Loc.t("mp_note") if ok else Loc.t("mp_web_only")
	v.get_node("Row/Host").text = Loc.t("mp_host")
	v.get_node("Row/Join").text = Loc.t("mp_join")
	(v.get_node("Row/Code") as LineEdit).placeholder_text = Loc.t("mp_code")
	for n in ["Row/Host", "Row/Join"]:
		(v.get_node(n) as Button).disabled = not ok or Net.active
	(v.get_node("Row/Code") as LineEdit).editable = ok and not Net.active
	v.get_node("Status").text = Net.status_text()
	var names := []
	for pid in Net.remotes:
		var r = Net.remotes[pid]
		if is_instance_valid(r):
			names.append(r.label.text)
	v.get_node("Players").text = (Loc.t("mp_players") % ", ".join(names)) if not names.is_empty() else ""
	v.get_node("Link").text = Net.share_link() if Net.active and Net.room != "" else ""
	v.get_node("Copy").visible = Net.active and Net.room != ""
	v.get_node("Copy").text = Loc.t("mp_copy")
	v.get_node("Leave").visible = Net.active
	v.get_node("Leave").text = Loc.t("mp_leave")
	v.get_node("Back").text = Loc.t("back")


func _process(_d: float) -> void:
	if visible and Engine.get_process_frames() % 30 == 0:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		menus.back()
