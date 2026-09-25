extends Control

var menus


func _ready() -> void:
	var v := $Center/Panel/VBox
	v.get_node("Resume").pressed.connect(func(): menus.resume())
	v.get_node("Map").pressed.connect(func(): Sfx.play("ui_click"); menus.open_map())
	v.get_node("Records").pressed.connect(func(): Sfx.play("ui_click"); menus.open_records("pause"))
	v.get_node("Settings").pressed.connect(func(): Sfx.play("ui_click"); menus.open_settings("pause"))
	v.get_node("Controls").pressed.connect(func(): Sfx.play("ui_click"); menus.open_controls("pause"))
	v.get_node("SkipTut").pressed.connect(_skip_tutorial)
	v.get_node("SaveQuit").pressed.connect(_save_quit)
	v.get_node("QuitGame").pressed.connect(func(): GameState.save_game(); get_tree().quit())
	v.get_node("QuitGame").visible = not OS.has_feature("web")


func open() -> void:
	visible = true
	var v := $Center/Panel/VBox
	v.get_node("Title").text = Loc.t("p_title")
	v.get_node("Resume").text = Loc.t("p_resume")
	v.get_node("Map").text = Loc.t("p_map")
	v.get_node("Records").text = Loc.t("t_records")
	v.get_node("Settings").text = Loc.t("t_settings")
	v.get_node("Controls").text = Loc.t("t_controls")
	v.get_node("SkipTut").text = Loc.t("p_skip_tut")
	v.get_node("SkipTut").visible = menus.main.prologue.active
	v.get_node("SaveQuit").text = Loc.t("p_save_quit")
	v.get_node("QuitGame").text = Loc.t("p_quit")
	v.get_node("Resume").grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		menus.resume()


func _skip_tutorial() -> void:
	Sfx.play("ui_confirm")
	menus.resume()
	menus.main.prologue.skip()


func _save_quit() -> void:
	Sfx.play("ui_confirm")
	GameState.save_game()
	menus.main.quit_to_title()
