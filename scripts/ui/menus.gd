extends Control
## 모든 메뉴 화면을 열고 닫는다. 게임이 멈춘 상태에서도 동작한다.

var main
var _return_to := ""

@onready var loading = $Loading
@onready var title = $Title
@onready var new_game = $NewGame
@onready var pause = $Pause
@onready var settings = $Settings
@onready var controls = $Controls
@onready var credits = $Credits
@onready var rest = $Rest
@onready var summary = $Summary
@onready var death = $Death
@onready var map = $Map
@onready var records = $Records
@onready var growth = $Growth
@onready var multi = $Multi


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for c in get_children():
		c.visible = false
		c.set("menus", self)


func _hide_all() -> void:
	for c in get_children():
		if c != loading:
			c.visible = false


func show_loading(v: bool) -> void:
	loading.visible = v
	if v:
		loading.open()


func close_all() -> void:
	_hide_all()
	if main and main.playing:
		get_tree().paused = false
		if not Settings.touch_mode:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func any_open() -> bool:
	for c in get_children():
		if c.visible and c != loading:
			return true
	return false


func _pause_game() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func open_title() -> void:
	_hide_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	title.open()


func open_new_game() -> void:
	_hide_all()
	new_game.open()


func open_pause() -> void:
	_pause_game()
	_hide_all()
	pause.open()
	Sfx.play("ui_open", -6.0)


func resume() -> void:
	Sfx.play("ui_close", -6.0)
	close_all()


func open_settings(from: String) -> void:
	_return_to = from
	_hide_all()
	settings.open()


func open_controls(from: String) -> void:
	_return_to = from
	_hide_all()
	controls.open()


func open_records(from: String) -> void:
	_return_to = from
	_hide_all()
	records.open()


## from: "pause"(일시정지에서) / "game"(P 키, 닫으면 바로 게임으로)
func open_growth(from: String) -> void:
	_return_to = from
	_pause_game()
	_hide_all()
	growth.open()
	Sfx.play("ui_open", -6.0)


func open_multi(from: String) -> void:
	_return_to = from
	_pause_game()
	_hide_all()
	multi.open()


func open_credits() -> void:
	_return_to = "title"
	_hide_all()
	credits.open()


func back() -> void:
	Sfx.play("ui_back", -6.0)
	_hide_all()
	match _return_to:
		"pause":
			pause.open()
		"game":
			close_all()
		_:
			title.open()


func open_map() -> void:
	_pause_game()
	_hide_all()
	map.open()
	Sfx.play("ui_open", -6.0)


func open_rest() -> void:
	_pause_game()
	_hide_all()
	rest.open()
	Sfx.play("ui_open", -6.0)


func open_summary(fledged: int) -> void:
	_pause_game()
	_hide_all()
	summary.open(fledged)
	Sfx.play("chime_big", -4.0)


func open_death(cause: String) -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hide_all()
	death.open(cause)
