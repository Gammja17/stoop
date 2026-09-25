extends Control
## 타이틀 화면. 뒤로는 둥지에 앉은 매를 도는 카메라가 보인다.

var menus

@onready var btn_continue: Button = $Left/Continue
@onready var btn_new: Button = $Left/NewGame


func _ready() -> void:
	btn_continue.pressed.connect(_on_continue)
	btn_new.pressed.connect(func(): Sfx.play("ui_click"); menus.open_new_game())
	$Left/Records.pressed.connect(func(): Sfx.play("ui_click"); menus.open_records("title"))
	$Left/Settings.pressed.connect(func(): Sfx.play("ui_click"); menus.open_settings("title"))
	$Left/Controls.pressed.connect(func(): Sfx.play("ui_click"); menus.open_controls("title"))
	$Left/Credits.pressed.connect(func(): Sfx.play("ui_click"); menus.open_credits())
	$Left/Quit.pressed.connect(func(): get_tree().quit())
	$Left/Quit.visible = not OS.has_feature("web")
	for b in $Left.get_children():
		if b is Button:
			b.mouse_entered.connect(func(): Sfx.play("ui_hover", -14.0))


func open() -> void:
	visible = true
	$Left/Tag.text = Loc.t("tagline")
	btn_continue.text = Loc.t("t_continue")
	btn_new.text = Loc.t("t_new")
	$Left/Records.text = "%s  (%d/%d)" % [Loc.t("t_records"), Records.count(), Records.LIST.size()]
	$Left/Settings.text = Loc.t("t_settings")
	$Left/Controls.text = Loc.t("t_controls")
	$Left/Credits.text = Loc.t("t_credits")
	$Left/Quit.text = Loc.t("t_quit")
	$Footer.text = "v%s · %s" % [ProjectSettings.get_setting("application/config/version", "1.0"), Loc.t("footer")]
	btn_continue.visible = GameState.has_save()
	if btn_continue.visible:
		btn_continue.grab_focus()
	else:
		btn_new.grab_focus()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


func _on_continue() -> void:
	Sfx.play("ui_confirm")
	if not GameState.load_game():
		return
	if GameState.data.has("dead"):
		menus.open_death(str(GameState.data.get("dead", "")))
		return
	menus.main.continue_game()
