extends Control
## 새로운 삶: 이름, 성별(수컷=민첩, 암컷=힘), 난이도.

var menus
var sex := "m"
var diff := "normal"
var tutorial := true


func _ready() -> void:
	var v := $Center/Panel/VBox
	v.get_node("Sex/Male").pressed.connect(func(): _set_sex("m"))
	v.get_node("Sex/Female").pressed.connect(func(): _set_sex("f"))
	v.get_node("Diff/Normal").pressed.connect(func(): _set_diff("normal"))
	v.get_node("Diff/Wild").pressed.connect(func(): _set_diff("wild"))
	v.get_node("Tut/TutOn").pressed.connect(func(): _set_tut(true))
	v.get_node("Tut/TutOff").pressed.connect(func(): _set_tut(false))
	v.get_node("Row/Back").pressed.connect(func(): Sfx.play("ui_back"); menus.open_title())
	v.get_node("Row/Start").pressed.connect(_on_start)


func open() -> void:
	visible = true
	var v := $Center/Panel/VBox
	v.get_node("Title").text = Loc.t("ng_title")
	v.get_node("NameLabel").text = Loc.t("ng_name")
	v.get_node("SexLabel").text = Loc.t("ng_sex")
	v.get_node("DiffLabel").text = Loc.t("ng_diff")
	v.get_node("Sex/Male").text = Loc.t("ng_male")
	v.get_node("Sex/Female").text = Loc.t("ng_female")
	v.get_node("Diff/Normal").text = Loc.t("ng_normal")
	v.get_node("Diff/Wild").text = Loc.t("ng_wild")
	v.get_node("TutLabel").text = Loc.t("ng_tutorial")
	v.get_node("Tut/TutOn").text = Loc.t("ng_tut_on")
	v.get_node("Tut/TutOff").text = Loc.t("ng_tut_off")
	_set_tut(tutorial)
	v.get_node("Row/Back").text = Loc.t("back")
	v.get_node("Row/Start").text = Loc.t("ng_start_over") if GameState.has_save() else Loc.t("ng_start")
	var names := LifeDirector.NAMES_M if sex == "m" else LifeDirector.NAMES_F
	v.get_node("Name").text = names[randi() % names.size()]
	_set_sex(sex)
	_set_diff(diff)
	v.get_node("Row/Start").grab_focus()


func _set_sex(s: String) -> void:
	sex = s
	var v := $Center/Panel/VBox
	v.get_node("Sex/Male").button_pressed = s == "m"
	v.get_node("Sex/Female").button_pressed = s == "f"
	v.get_node("SexDesc").text = Loc.t("ng_male_desc") if s == "m" else Loc.t("ng_female_desc")
	Sfx.play("ui_select", -10.0)


func _set_diff(d: String) -> void:
	diff = d
	var v := $Center/Panel/VBox
	v.get_node("Diff/Normal").button_pressed = d == "normal"
	v.get_node("Diff/Wild").button_pressed = d == "wild"
	v.get_node("DiffDesc").text = Loc.t("ng_normal_desc") if d == "normal" else Loc.t("ng_wild_desc")


func _set_tut(on: bool) -> void:
	tutorial = on
	var v := $Center/Panel/VBox
	v.get_node("Tut/TutOn").button_pressed = on
	v.get_node("Tut/TutOff").button_pressed = not on


func _on_start() -> void:
	Sfx.play("ui_confirm")
	var nm: String = $Center/Panel/VBox/Name.text.strip_edges()
	if nm == "":
		nm = "매"
	GameState.delete_save()
	menus.main.start_new_game(nm, sex, diff, tutorial)
